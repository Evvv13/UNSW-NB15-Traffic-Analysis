# UNSW-NB15 Network Traffic Analysis

A reproducible R-based pipeline for detecting network intrusions using the UNSW-NB15 dataset. Covers data cleaning, exploratory data analysis (EDA), inferential statistics, and logistic regression modelling with ROC evaluation.

---

## 📁 Repository Structure

```
UNSW-NB15-Traffic-Analysis/
├── data/
│   ├── raw/                  # Place the downloaded dataset here (see Usage)
│   └── processed/            # UNSW_cleaned.csv is generated here by the script
├── scripts/
│   └── analysis_main.R       # Full pipeline: cleaning → EDA → modelling
├── plots/
│   ├── distribution_plot.png # Traffic class balance chart
│   ├── sload_dload_violin.png# Source/destination load violin plots
│   └── roc_curve.png         # ROC curve for logistic regression model
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🚀 Usage

### 1. Data Acquisition

Due to file size limits, the raw dataset is **not included** in this repository.

1. Download the **UNSW-NB15** dataset from the official source:
   👉 [https://research.unsw.edu.au/projects/unsw-nb15-dataset](https://research.unsw.edu.au/projects/unsw-nb15-dataset)
2. Rename the file to `UNSW-NB15_uncleaned.csv` and place it inside `data/raw/`.

### 2. Install R Dependencies

Open R or RStudio and run:

```r
install.packages(c(
  "data.table", "tidyverse", "corrplot", "rpart", "rpart.plot",
  "caret", "pROC", "gridExtra", "e1071", "caTools",
  "VIM", "rstatix", "scales", "car", "doParallel"
))
```

### 3. Run the Analysis

Set your working directory to the project root, then run:

```r
setwd("path/to/UNSW-NB15-Traffic-Analysis")
source("scripts/analysis_main.R")
```

The script will:
- Clean and export the full dataset to `data/processed/UNSW_cleaned.csv`
- Save all EDA plots to `plots/`
- Print model summaries, confidence intervals, confusion matrix, and AUC to the console

---

## 📊 Results Overview

### Pipeline Summary

| Step | Method | Key Outcome |
|---|---|---|
| Cleaning | IQR outlier removal + median/mean imputation | Structured, analysis-ready dataset |
| EDA | Violin plots, bar charts | Clear load differences between Normal and Attack traffic |
| Inferential | Welch ANOVA + Wilcoxon effect size | Statistically significant difference in source load |
| Modelling | Logistic Regression (2 models) | Model 2 achieves 88.54% accuracy with Kappa 0.73 |

---

### Model Comparison

| Metric | Model 1 (ls + ld) | Model 2 (ls + ld + sinpkt + sbytes + dbytes + sttl) |
|---|---|---|
| AIC | 6690.3 | **5373.2** |
| Residual Deviance | 6684.3 | **5359.2** |
| Fisher Scoring Iterations | 5 | 7 |

Model 2 achieves a substantially lower AIC (-1317 points), confirming the additional features meaningfully improve model fit.

---

### Model 2 — Final Coefficients

All 6 predictors are statistically significant (p < 0.001):

| Predictor | Estimate | 95% CI | Effect on Attack Probability |
|---|---|---|---|
| Intercept | +5.933 | (5.469, 6.397) | Baseline |
| ls (log source load) | -0.189 | (-0.214, -0.164) | Higher load → less likely Attack |
| ld (log dest load) | -0.354 | (-0.381, -0.327) | Higher load → less likely Attack |
| sinpkt (source inter-packet time) | -0.833 | (-0.948, -0.718) | Faster packets → more likely Attack |
| sbytes (source bytes) | +2.501 | (1.690, 3.311) | More bytes → more likely Attack |
| dbytes (dest bytes) | +0.345 | (0.246, 0.444) | More bytes → more likely Attack |
| sttl (time to live) | +0.723 | (0.630, 0.816) | Higher TTL → more likely Attack |

---

### Model 2 — Confusion Matrix (Test Set)

```
              Actual Normal    Actual Attack
Predicted Normal     531              83
Predicted Attack     159            1338
```

| Metric | Value |
|---|---|
| **Accuracy** | **88.54%** |
| 95% CI | (87.10%, 89.86%) |
| Sensitivity | 76.96% |
| Specificity | 94.16% |
| Kappa | **0.7319** |
| Balanced Accuracy | 85.56% |
| Positive Pred Value | 86.48% |
| Negative Pred Value | 89.38% |

---

### Overfitting Check

| | Value |
|---|---|
| Train Accuracy | 86.56% |
| Test Accuracy | 86.68% |
| Gap | -0.0012 |

A near-zero negative gap confirms the model generalises well to unseen data with **no overfitting**.

---

### Model Evolution

| Configuration | Accuracy | Kappa |
|---|---|---|
| 10% sample, 4 features | 84.77% | — |
| 100% data, 4 features | 86.68% | 0.6716 |
| 100% data, 7 features (with dinpkt) | 86.02% | 0.6664 |
| **100% data, 6 features (dinpkt removed)** | **88.54%** | **0.7319** |

Removing the non-significant `dinpkt` predictor (p = 0.85) improved every metric across the board.

---

## 🔬 Dataset Citation

Moustafa, N., & Slay, J. (2015). UNSW-NB15: A comprehensive data set for network intrusion detection systems. *2015 Military Communications and Information Systems Conference (MilCIS)*. IEEE.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
