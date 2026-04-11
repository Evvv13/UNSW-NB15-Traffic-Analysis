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
  "VIM", "rstatix", "scales", "car"
))
```

### 3. Run the Analysis

Set your working directory to the project root, then run:

```r
setwd("path/to/UNSW-NB15-Traffic-Analysis")
source("scripts/analysis_main.R")
```

The script will:
- Clean and export the dataset to `data/processed/UNSW_cleaned.csv`
- Save all EDA plots to `plots/`
- Print model evaluation results (confusion matrix, AUC) to the console

---

## 📊 Results Overview

| Step | Method | Key Outcome |
|---|---|---|
| Cleaning | IQR outlier removal + median/mean imputation | Structured, analysis-ready dataset |
| EDA | Violin plots, bar charts | Clear load differences between Normal and Attack traffic |
| Inferential | Welch ANOVA + Wilcoxon effect size | Statistically significant difference in source load |
| Modelling | Logistic Regression (2 models) | Model 2 (with inter-packet timing) achieves higher AUC |

---

## 🔬 Dataset Citation

Moustafa, N., & Slay, J. (2015). UNSW-NB15: A comprehensive data set for network intrusion detection systems. *2015 Military Communications and Information Systems Conference (MilCIS)*. IEEE.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
