# UNSW-NB15 Network Traffic Analysis

A reproducible R-based pipeline for detecting network intrusions using the UNSW-NB15 dataset. Covers data cleaning, exploratory data analysis (EDA), inferential statistics, and logistic regression modelling with ROC evaluation.

---

## 📁 Repository Structure

```
UNSW-NB15-Traffic-Analysis/
├── data/
│   ├── raw/                   # Place the downloaded dataset here (see Usage)
│   └── processed/             # UNSW_cleaned.csv is generated here by the script
├── scripts/
│   └── analysis_main.R        # Full pipeline: cleaning -> EDA -> modelling
├── plots/
│   ├── distribution_plot.png  # Traffic class balance chart
│   ├── sload_dload_violin.png # Source/destination load violin plots
│   └── roc_curve.png          # ROC curve for logistic regression model
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
- Print model summaries, confidence intervals, and confusion matrix to the console
- Run an automatic overfitting check (train vs test accuracy gap)

---

## 📊 Results

### Dataset Summary (after cleaning)

| Class | Count | Mean Sload | Median Sload |
|---|---|---|---|
| Normal | 42,061 | 24,321,135 | 502,901 |
| Attack | 95,412 | 94,932,248 | 50,666,664 |
| **Total** | **137,473** | | |

---

### Model Comparison

| Metric | Model 1 (ls + ld) | Model 2 (ls + ld + sinpkt + sbytes + dbytes + sttl) |
|---|---|---|
| Training rows | 86,079 | 86,079 |
| AIC | 68,396 | **53,702** |
| Residual Deviance | 68,390 | **53,688** |
| Fisher Scoring Iterations | 5 | 7 |

Model 2 achieves an AIC reduction of **14,694 points**, confirming the additional features meaningfully improve model fit.

---

### Model 2 — Final Coefficients

All 6 predictors statistically significant (p < 0.001):

| Predictor | Estimate | 95% CI | Interpretation |
|---|---|---|---|
| Intercept | +6.023 | (5.879, 6.167) | Baseline log-odds |
| ls (log source load) | -0.187 | (-0.195, -0.179) | Higher load → less likely Attack |
| ld (log dest load) | -0.368 | (-0.376, -0.360) | Higher load → less likely Attack |
| sinpkt (source inter-packet time) | -1.031 | (-1.081, -0.981) | Faster packets → more likely Attack |
| sbytes (source bytes) | +2.600 | (2.327, 2.873) | More source bytes → more likely Attack |
| dbytes (dest bytes) | +0.413 | (0.374, 0.451) | More dest bytes → more likely Attack |
| sttl (time to live) | +0.663 | (0.634, 0.691) | Higher TTL → more likely Attack |

Note: `dinpkt` was removed — non-significant across all runs (p = 0.85, CI crosses zero).

---

### Model 2 — Confusion Matrix (Test Set: 21,521 rows)

```
              Actual Normal    Actual Attack
Predicted Normal    4,859          1,037
Predicted Attack    1,673         13,952
```

| Metric | Value |
|---|---|
| **Accuracy** | **87.41%** |
| 95% CI | (86.96%, 87.85%) |
| Sensitivity | 74.39% |
| Specificity | 93.08% |
| **Kappa** | **0.6937** |
| Balanced Accuracy | 83.73% |
| Positive Pred Value | 82.41% |
| Negative Pred Value | 89.29% |

---

### Overfitting Check

| | Value |
|---|---|
| Train Accuracy | 87.57% |
| Test Accuracy | 87.41% |
| **Gap** | **+0.0016** |

A gap of 0.0016 (0.16%) confirms the model generalises well to unseen data with **no overfitting**.

---

### Wilcoxon Effect Size (Sload)

| Comparison | Effect Size | Magnitude |
|---|---|---|
| Normal vs Attack | 0.233 | Small |

Despite being statistically small, the Welch ANOVA confirms the difference is highly significant (p = 0, F = 15,127) due to the large sample size.

---

### Model Evolution

| Configuration | Sample Size | Rows | Accuracy | Kappa |
|---|---|---|---|---|
| 4 features (ls, ld, sinpkt, dinpkt) | 10% | ~13,700 | 84.77% | — |
| 4 features (ls, ld, sinpkt, dinpkt) | 100% | 137,473 | 86.68% | 0.6716 |
| 7 features (+ sbytes, dbytes, sttl, dinpkt) | 100% | 137,473 | 86.02% | 0.6664 |
| **6 features — dinpkt dropped** | **100%** | **137,473** | **87.41%** | **0.6937** |

---

## 🔬 Dataset Citation

Moustafa, N., & Slay, J. (2015). UNSW-NB15: A comprehensive data set for network intrusion detection systems. *2015 Military Communications and Information Systems Conference (MilCIS)*. IEEE.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
