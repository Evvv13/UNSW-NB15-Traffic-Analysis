################################################################################
# Project: UNSW-NB15 Network Intrusion Detection Analysis
# Script:  Data Cleaning, EDA, and Predictive Modeling
# Dataset: UNSW-NB15 (https://research.unsw.edu.au/projects/unsw-nb15-dataset)
################################################################################

# 1. LOAD LIBRARIES ------------------------------------------------------------
library(data.table)
library(tidyverse)
library(corrplot)
library(rpart)
library(rpart.plot)
library(caret)
library(pROC)
library(gridExtra)
library(e1071)
library(caTools)
library(VIM)
library(rstatix)
library(scales)
library(car)
library(doParallel)

# --- Parallel processing setup ---
cores <- detectCores() - 1  # leave 1 core free for the OS
registerDoParallel(cores)
cat("Parallel processing enabled:", cores, "cores in use\n")


# 2. DATA IMPORT & INITIAL INSPECTION ------------------------------------------
cat("\n[1/6] Loading data...\n")
input_path <- "data/raw/UNSW-NB15_uncleaned.csv"
unsw <- fread(input_path)

str(unsw)
# FIX: anyDuplicated() is much faster than sum(duplicated()) on large data
cat("Duplicate rows found:", anyDuplicated(unsw), "\n")


# 3. HELPER FUNCTIONS FOR CLEANING ---------------------------------------------

# Generic column cleaner: removes trailing noise characters and enforces types
clean_column <- function(col_data, col_name) {
  tryCatch({
    clean_data <- as.character(col_data)
    clean_data <- gsub("[?_-]+$", "", clean_data)
    
    numeric_cols <- c("dur", "sbytes", "dbytes", "sttl", "dttl", "sloss",
                      "dloss", "sload", "dload", "spkts", "dpkts", "label", "ct_srv_dst")
    
    if (col_name %in% numeric_cols) clean_data <- as.numeric(clean_data)
    
    clean_data[clean_data == "" | clean_data == "NA"] <- NA
    return(clean_data)
  }, error = function(e) {
    warning(paste("Error cleaning column", col_name, ":", e$message))
    return(col_data)
  })
}

# Imputation handler: supports mean, median, and categorical (mode-as-Unknown)
handle_missing <- function(col_data, type = "mean") {
  if (type == "cat")    return(as.factor(ifelse(is.na(col_data), "Unknown", col_data)))
  if (type == "mean")   return(as.numeric(ifelse(is.na(col_data), mean(col_data, na.rm = TRUE), col_data)))
  if (type == "median") return(as.numeric(ifelse(is.na(col_data), median(col_data, na.rm = TRUE), col_data)))
}


# 4. DATA CLEANING -------------------------------------------------------------
cat("\n[2/6] Cleaning data...\n")

# --- Numeric columns ---
numeric_columns <- c("dur", "sbytes", "dbytes", "sttl", "dttl", "sloss",
                     "dloss", "sload", "dload", "spkts", "dpkts", "ct_srv_dst")

for (col in numeric_columns) {
  if (col %in% names(unsw)) {
    unsw[[col]] <- clean_column(unsw[[col]], col)
    if (col == "dur") {
      unsw[[col]] <- handle_missing(unsw[[col]], "mean")
    } else if (col %in% c("sload", "dload")) {
      unsw[[col]] <- handle_missing(unsw[[col]], "median")
    } else {
      unsw[[col]] <- as.integer(handle_missing(unsw[[col]], "median"))
    }
  }
}

# --- Categorical columns ---
categorical_columns <- c("proto", "service", "state")
for (col in categorical_columns) {
  if (col %in% names(unsw)) {
    unsw[[col]] <- clean_column(unsw[[col]], col)
    unsw[[col]] <- handle_missing(unsw[[col]], "cat")
  }
}

# --- Target variable ---
unsw$attack_cat <- as.factor(
  ifelse(is.na(unsw$attack_cat) | unsw$attack_cat == "Normal", "Normal", unsw$attack_cat)
)
unsw$label <- as.numeric(
  ifelse(is.na(unsw$label), ifelse(unsw$attack_cat == "Normal", 0, 1), unsw$label)
)
unsw$is_attack <- factor(ifelse(unsw$label == 1, "Attack", "Normal"), levels = c("Normal", "Attack"))


# 5. OUTLIER REMOVAL -----------------------------------------------------------
cat("\n[3/6] Removing outliers...\n")

normal_data  <- subset(unsw, label == 0)
attack_data  <- subset(unsw, label == 1)

Q1      <- quantile(normal_data$dur, 0.25)
Q3      <- quantile(normal_data$dur, 0.75)
IQR_val <- Q3 - Q1

normal_clean <- subset(normal_data, dur > (Q1 - 1.5 * IQR_val) & dur < (Q3 + 1.5 * IQR_val))
unsw <- rbind(normal_clean, attack_data)

rm(normal_data, attack_data, normal_clean)
gc()

# FIX: Use fwrite() instead of write.csv() -- 5-10x faster for large files
fwrite(unsw, "data/processed/UNSW_cleaned.csv")
cat("Cleaned dataset saved to data/processed/UNSW_cleaned.csv\n")

# Use full cleaned dataset -- no sampling needed
cat("Using full dataset:", nrow(unsw), "rows\n")
gc()


# 6. EXPLORATORY DATA ANALYSIS (EDA) ------------------------------------------
cat("\n[4/6] Running EDA...\n")

# Summary statistics
eda_summary <- unsw %>%
  group_by(is_attack) %>%
  summarise(
    Count        = n(),
    Mean_Sload   = mean(sload, na.rm = TRUE),
    Median_Sload = median(sload, na.rm = TRUE),
    Skew_Sload   = skewness(sload, na.rm = TRUE)
  )
print(eda_summary)

# Plot: Traffic class distribution
p_class <- ggplot(unsw, aes(x = is_attack, fill = is_attack)) +
  geom_bar() +
  scale_fill_manual(values = c("Normal" = "#4CAF50", "Attack" = "#F44336")) +
  theme_minimal(base_size = 13) +
  labs(title = "Distribution of Traffic Classes",
       x = "Traffic Type", y = "Count", fill = "Class")

ggsave("plots/distribution_plot.png", p_class, width = 8, height = 6, dpi = 150)
cat("Saved: plots/distribution_plot.png\n")

# Plot: Sload and Dload violin comparison (log scale)
p_sload <- ggplot(unsw, aes(x = is_attack, y = sload, fill = is_attack)) +
  geom_violin(trim = FALSE) +
  scale_y_log10() +
  scale_fill_manual(values = c("Normal" = "#4CAF50", "Attack" = "#F44336")) +
  theme_minimal(base_size = 13) +
  labs(title = "Source Load (Sload)", x = NULL, y = "Sload (log scale)", fill = "Class")

p_dload <- ggplot(unsw, aes(x = is_attack, y = dload, fill = is_attack)) +
  geom_violin(trim = FALSE) +
  scale_y_log10() +
  scale_fill_manual(values = c("Normal" = "#4CAF50", "Attack" = "#F44336")) +
  theme_minimal(base_size = 13) +
  labs(title = "Destination Load (Dload)", x = NULL, y = "Dload (log scale)", fill = "Class")

p_combined <- arrangeGrob(p_sload, p_dload, ncol = 2)
ggsave("plots/sload_dload_violin.png", p_combined, width = 12, height = 6, dpi = 150)
cat("Saved: plots/sload_dload_violin.png\n")


# 7. INFERENTIAL STATISTICS ----------------------------------------------------
cat("\n[5/6] Running inferential statistics...\n")

# Log-transform load features to reduce skew
unsw <- unsw %>% mutate(ls = log1p(sload), ld = log1p(dload))

cat("--- Welch ANOVA: log(Sload) by Attack Status ---\n")
print(unsw %>% welch_anova_test(ls ~ is_attack))

# FIX: wilcox_effsize is very slow on large data -- use a 5000-row subsample
cat("--- Wilcoxon Effect Size: Sload (subsampled to 5000 rows) ---\n")
set.seed(42)
unsw_sub <- unsw[sample(nrow(unsw), min(5000, nrow(unsw))), ]
print(unsw_sub %>% wilcox_effsize(sload ~ is_attack))
rm(unsw_sub)
gc()


# 8. PREDICTIVE MODELING: LOGISTIC REGRESSION ----------------------------------
cat("\n[6/6] Fitting logistic regression models...\n")

# Guard: confirm all required columns exist before modelling
required_cols <- c("is_attack", "ls", "ld", "sinpkt", "sbytes", "dbytes", "sttl")
missing_cols  <- setdiff(required_cols, names(unsw))
if (length(missing_cols) > 0) stop(paste("Missing columns:", paste(missing_cols, collapse = ", ")))

# Prepare model dataset
# sinpkt is stored as character in the raw CSV -- convert to double before scaling
# dinpkt was dropped: non-significant across all runs (p = 0.85, CI crosses zero)
df_model <- unsw %>%
  select(is_attack, ls, ld, sinpkt, sbytes, dbytes, sttl) %>%
  mutate(
    sinpkt = as.vector(scale(as.double(sinpkt))),
    sbytes = as.vector(scale(as.double(sbytes))),
    dbytes = as.vector(scale(as.double(dbytes))),
    sttl   = as.vector(scale(as.double(sttl)))
  ) %>%
  drop_na()

# FIX: Use base sample() instead of sample.split() -- much faster
set.seed(123)
n         <- nrow(df_model)
train_idx <- sample(seq_len(n), size = floor(0.8 * n))
train_set <- df_model[train_idx, ]
test_set  <- df_model[-train_idx, ]

# Model 1: Load features only (baseline)
cat("Fitting Model 1 (ls + ld)...\n")
m1 <- glm(is_attack ~ ls + ld,
          data    = train_set,
          family  = binomial,
          control = glm.control(maxit = 50, epsilon = 1e-6))

# Model 2: Load + packet timing + byte volume + TTL
# FIX: glm.control() caps iterations and sets convergence tolerance
# prevents glm from running indefinitely on large or noisy data
cat("Fitting Model 2 (ls + ld + sinpkt + sbytes + dbytes + sttl)...\n")
m2 <- glm(is_attack ~ ls + ld + sinpkt + sbytes + dbytes + sttl,
          data    = train_set,
          family  = binomial,
          control = glm.control(maxit = 50, epsilon = 1e-6))

# Model summaries
cat("\n--- Model 1 Summary ---\n")
print(summary(m1))

cat("\n--- Model 2 Summary ---\n")
print(summary(m2))

# FIX: confint.default() uses normal approximation -- much faster than confint()
# confint() runs likelihood profiling which is very slow on large models
cat("\n--- Confidence Intervals: Model 1 (confint.default) ---\n")
print(confint.default(m1))

cat("\n--- Confidence Intervals: Model 2 (confint.default) ---\n")
print(confint.default(m2))

# Evaluate Model 2
pred_prob  <- predict(m2, newdata = test_set, type = "response")
pred_class <- factor(ifelse(pred_prob > 0.5, "Attack", "Normal"), levels = c("Normal", "Attack"))

cat("\n--- Confusion Matrix (Model 2) ---\n")
print(confusionMatrix(pred_class, test_set$is_attack))

# Train vs test accuracy check -- confirm no overfitting
train_pred  <- predict(m2, newdata = train_set, type = "response")
train_class <- factor(ifelse(train_pred > 0.5, "Attack", "Normal"), levels = c("Normal", "Attack"))
train_acc   <- mean(train_class == train_set$is_attack)
test_acc    <- mean(pred_class  == test_set$is_attack)

cat("\n--- Overfitting Check ---\n")
cat("Train accuracy:", round(train_acc, 4), "\n")
cat("Test accuracy: ", round(test_acc,  4), "\n")
cat("Gap:           ", round(train_acc - test_acc, 4), "\n")

# ROC Curve
roc_score <- roc(test_set$is_attack, pred_prob)

png("plots/roc_curve.png", width = 800, height = 600, res = 150)
plot(roc_score,
     main = paste("ROC Curve - AUC:", round(auc(roc_score), 4)),
     col  = "#1565C0", lwd = 2)
dev.off()
cat("Saved: plots/roc_curve.png\n")

# Shutdown parallel cluster cleanly
stopImplicitCluster()
cat("\nDone! All outputs saved.\n")