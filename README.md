# Neural Localization of Temporal Structure in Music: A Voxel-Wise fMRI Analysis

This repository contains the complete data processing pipeline, statistical analysis scripts, generated figures, and second-level group results for the fMRI study evaluating neural sensitivity to hierarchical temporal structure in music.

## Project Overview
The study investigates how the human brain processes global temporal structure versus local acoustic primitives in music. Using a mass-univariate voxel-wise fMRI approach in SPM12, BOLD signal responses were evaluated across 12 healthy participants (\\(N = 12\\)) under three auditory conditions:
1. **Original Music:** Intact violin solos by J. S. Bach and E. Krenek.
2. **Scrambled Music:** 240 ms temporal quilts preserving local acoustic features while disrupting global metric continuity.
3. **Synthetic Noise:** Spectrotemporally matched stationary noise anchors.

---

## Directory Structure

```text
for_upload/
├── code/
│   ├── analysis/
│   │   ├── preprocessing_code.m            # Main SPM12 spatial preprocessing pipeline
│   │   ├── fast_normalize_fix.m            # Targeted re-normalization & FAST autocorrelation re-run
│   │   ├── run_first_level_analysis_newfast.m  # Subject-level GLM specification & estimation
│   │   ├── run_second_level_analysis_newfast.m # Group-level one-sample t-tests
│   │   └── log files/                      # Cluster job execution log files
│   └── figure_code/
│       ├── plot_boxplot_contrast1.m        # First-level contrast weight boxplots (Contrast 01)
│       ├── plot_boxplot_contrast2.m        # First-level contrast weight boxplots (Contrast 02)
│       ├── plot_scatter_contrast1.m        # Individual participant scatterplots
│       ├── plot_scatter_contrast2.m        # Individual participant scatterplots
│       ├── plot_heatmap_motion_parameters.m# Task-correlated head motion diagnostic heatmap
│       └── test_powerplot.m               # Sensitivity & post-hoc power curve analysis
├── figures/
│   ├── MATLAB/                             # Diagnostic plots, boxplots, power curves, motion heatmap
│   ├── MRIcroGL/                           # Rendered statistical activation overlays on anatomical MNI
│   └── SPM/                                # Official SPM glass brain output sheets (PDF)
├── first_level_data/                        # Individual subject SPM output (beta, con, spmT maps)
├── preprocessed_data/                       # Preprocessed functional (swa*) and structural (y_*) volumes
├── second_level_data/                       # Group-level statistical models & thresholded maps
│   ├── contrast_01_music_vs_scrambled/
│   ├── contrast_02_music_vs_noise/
│   └── contrast_03_scrambled_vs_noise/
├── Preregistration BA.pdf                   # Official study preregistration document
└── README.md                                # Repository documentation

