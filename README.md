# ukb_cprd_cas_symptoms
Analysis code and codelists for comparison of pre-cancer symptoms and blood tests.

This in principle allows researchers with existing access to both UK Biobank and CPRD Gold to recreate the results reported in the paper "Phenotypes and rates of cancer-relevant symptoms and tests in the year before cancer diagnosis in UK Biobank and CPRD Gold". For data protection reasons, the underlying data cannot be shared here.

Codelists
- codelist_cancer.xlsx documents the ICD10-cancer assignments
- codelist_22symptom.dta documents the Readv2 and CTV3 symptom phenotypes for the symptoms examined in this analysis and UTI
- codelist_bloodtests.dta documents the Readv2 and CTV3 phenotypes used to identify fact of blood test

Files that work with CPRD data:
- create_comparison_cohort.sql contains sql scripts for creating the basic tables used in the analysis from CPRD Gold
- cr1_ODBC_in_CPRD_Data.do loads these tables into Stata and combines them into a flat analysis file

Files that work with UK Biobank data:
- cr2_load_UKB_data.do loads UKB data into Stata and combines it into a flat analysis file. This relies on previous data-processing using scripts that are not publsihed here.

Files that work with both CPRD and UK Biobank data
- cr3_cprd_ukb_datasets_matching_format.do loads both flat analysis files into memory and standardises structure and variable names
- an1_symptom_test_counts.do produces the descriptive counts shown in Table 2
- an2_symptom_test_direct_comparison.do produces the overall and cancer-site-specific model-based comparisons shown in Figure 2 and Figure 3 (and more extensively described in the appendix)
- an3_graph_data_processing.do just contains a program to do some of the cleaning-up of the model results for plotting
- an4_comparison_plots.do draws the overall and cancer-site-specific comparisons plots (e.g., Figure 2, appendix figures)
- an5_comparison_matrix.do outputs summaries of the comparisons for use in manual creation of the matrix of results shown in Figure 3
- an6_symptom_test_direct_comparison_country.do repeats the overall UKB vs CPRD comparisons separately for UKB participants from England, Wales and Scotland
- an7_comparison_plots_country.do draws the country-specific comparison plot (Figure 4)
