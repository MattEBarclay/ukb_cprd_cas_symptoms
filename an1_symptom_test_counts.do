/* Counts symptom occurences in CPRD data */

cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison" 
set trace off

local todaydate : display %tdCCYY-NN-DD = daily("`c(current_date)'", "DMY")


/******************************************************************************/
/* Program for counting presence/absence of a symptom for use in table
	production
*/

cap program drop symptom_counts
program define symptom_counts
	syntax, dataset(string) [weight(varname)]
	
	gen total = 1
	
	tempvar weight2
	
	if "`weight'" != "" {
		gen `weight2' = `weight'
	}
	else {
		gen `weight2' = 1
	}
	
	rename count_consults total_consults
	* Count of multiple distinct symptoms
	foreach var of varlist count_* {
		gen any_`var' = `var' >= 1
	}

	* make sure no tests
	cap drop any_count_pv
	cap drop any_count_crp
	cap drop any_count_haemoglobinconc
	cap drop any_count_platelets
	cap drop any_count_haematocritperc
	cap drop any_count_albumin
	cap drop any_count_ferritin
	cap drop any_count_esr
	cap drop any_count_consults
	
	egen multiple_symptoms1 = rowtotal(any_count_abdominal_blo-any_count_weight_l)
	gen count_mul_symptom = multiple_symptoms1 >= 2

	drop any_* multiple_symptoms1

	rename count_symptom count_any_symptom
	
	* Cancers
	gen byte count_anycancer  = !missing(real_cancer) 
	gen byte count_breast     = real_cancer ==  1
	gen byte count_prostate   = real_cancer ==  2
	gen byte count_colorectal = real_cancer ==  3
	gen byte count_lung       = real_cancer ==  4
	gen byte count_melanoma   = real_cancer ==  5
	gen byte count_nhl        = real_cancer ==  6
	gen byte count_kidney     = real_cancer ==  7
	gen byte count_uppergi    = real_cancer ==  8
	gen byte count_bladder    = real_cancer ==  9
	gen byte count_uterine    = real_cancer == 10
	gen byte count_other      = real_cancer == 99
	
	* 'Alarm', 'Non-alarm', and 'Blood tests'
	egen count_alarm     = rowtotal( ///
								count_abdominal_lump ///
								count_breast_lump ///
								count_change_bowel ///
								count_dysphagia ///
								count_haematuria ///
								count_haemoptysis ///
								count_jaundice ///
								count_pm_bleed ///
								count_rectal_bleeding ///
							)
								
	egen count_nonalarm  = rowtotal( ///
								count_abdominal_bloating ///
								count_abdominal_pain ///
								count_constipation /// 
								count_cough ///
								count_diarrhoea ///
								count_dyspepsia /// 
								count_dyspnoea /// 
								count_fatigue ///
								count_night_sweats /// 
								count_pelvic_pain ///
								count_stomach_disorders ///
								count_weight_loss /// 
							)
							
	* check - any symptom = sum of alarm and nonalarm symptoms
	assert count_any_symptom == count_alarm + count_nonalarm
	
	egen count_bloodtest = rowtotal( /// 
								count_haemoglobinconc /// 
								count_platelets /// 
								count_haematocritperc /// 
								count_albumin /// 
								count_ferritin /// 
								count_esr  /// 
								count_crp  /// 
								count_pv /// 
							)
	
	egen count_fbc = rowtotal( /// 
								count_haemoglobinconc /// 
								count_platelets /// 
								count_haematocritperc /// 
							)
	
	egen count_apr = rowtotal( /// 
								count_albumin /// 
								count_ferritin /// 
							)
							
	egen count_im = rowtotal( /// 
								count_esr  /// 
								count_crp  /// 
								count_pv /// 
							)
	
	* check - any blood test = sum of each type of blood test
	assert count_bloodtest == count_fbc + count_apr + count_im

	
	* format symptom, test counts
	foreach var of varlist count* {
		local strname = subinstr("`var'", "count_", "", .)
	
		replace `var' = 1 if `var' > 1
		gen sum_`strname' = `var'
		rename `var' mean_`strname'
	}
	
	rename total_consults consults
		
	* time before diagnosis
	cap rename date_cancer diagnosisdate
	replace median_consult = diagnosisdate-median_consult
	replace symptom0 = diagnosisdate-symptom0
	replace test0 = diagnosisdate-test0
	
	foreach thing in median_consult symptom0 test0 {
		assert `thing' >= 0 | missing(`thing')
	}
	
	collapse (sum) sum_total = total /// 
		(mean) mean_age = age (sd) sd_age = age (p25) q1_age = age (p75) q3_age = age ///
		(mean) mean_male					= male 				(sum) sum_male = male /// 
		(mean) mean_imd1 = imd1 (sum) sum_imd1 = imd1 /// 
		(mean) mean_imd2 = imd2 (sum) sum_imd2 = imd2 /// 
		(mean) mean_imd3 = imd3 (sum) sum_imd3 = imd3 /// 
		(mean) mean_imd4 = imd4 (sum) sum_imd4 = imd4 /// 
		(mean) mean_imd5 = imd5 (sum) sum_imd5 = imd5 /// 
		(mean) mean_* (sum) sum_* /// 
		(mean) mean_consults = consults 		(sd) sd_consults = consults 		(p25) q1_consults = consults 		(p75) q3_consults = consults ///
		(mean) mean_med_cons = median_consult 	(sd) sd_med_cons = median_consult 	(p25) q1_med_cons = median_consult 	(p75) q3_med_cons = median_consult ///
		(mean) mean_symptom0 = symptom0			(sd) sd_symptom0 = symptom0 		(p25) q1_symptom0 = symptom0		(p75) q3_symptom0 = symptom0 ///
		(mean) mean_test0    = test0 			(sd) sd_test0    = test0 			(p25) q1_test0    = test0 			(p75) q3_test0    = test0 ///
		[aw=`weight2']
		
	gen dataset = "`dataset'"
	order dataset
	qui reshape long mean_ sum_ sd_ q1_ q3_, i(dataset) j(variable) string
	
	gen byte ordering = .
	replace ordering =  1 if variable == "total"
	replace ordering =  2 if variable == "age"
	replace ordering =  3 if variable == "male"
	replace ordering =  4 if variable == "imd1"
	replace ordering =  5 if variable == "imd2"
	replace ordering =  6 if variable == "imd3"
	replace ordering =  7 if variable == "imd4"
	replace ordering =  8 if variable == "imd5"
	
	replace ordering =  9   if variable == "anycancer"
	replace ordering =  9.1 if variable == "breast"
	replace ordering =  9.2 if variable == "prostate"
	replace ordering =  9.3 if variable == "colorectal"
	replace ordering =  9.4 if variable == "lung"
	replace ordering =  9.5 if variable == "melanoma"
	replace ordering =  9.6 if variable == "nhl"
	replace ordering =  9.7 if variable == "kidney"
	replace ordering =  9.8 if variable == "uppergi"
	replace ordering =  9.9 if variable == "bladder"
	replace ordering = 10.0 if variable == "uterine"
	replace ordering = 10.1 if variable == "other"
	
	replace ordering = 11   if variable == "consults"
	replace ordering = 11.1 if variable == "med_cons"
	replace ordering = 11.2 if variable == "symptom0"
	replace ordering = 11.3 if variable == "test0"
	
	replace ordering = 12 if variable == "any_symptom"
	replace ordering = 13 if variable == "mul_symptom"
	
	replace ordering = 14 if variable == "alarm"
	replace ordering = 15 if variable == "abdominal_lump"
	replace ordering = 16 if variable == "breast_lump"
	replace ordering = 17 if variable == "change_bowel"
	replace ordering = 18 if variable == "dysphagia"
	replace ordering = 19 if variable == "haematuria"
	replace ordering = 20 if variable == "haemoptysis"
	replace ordering = 21 if variable == "jaundice"
	replace ordering = 22 if variable == "pm_bleed"
	replace ordering = 23 if variable == "rectal_bleeding"
	
	replace ordering = 24 if variable == "nonalarm"
	replace ordering = 25 if variable == "abdominal_bloating" 
	replace ordering = 26 if variable == "abdominal_pain"
	replace ordering = 27 if variable == "constipation"
	replace ordering = 28 if variable == "cough"
	replace ordering = 29 if variable == "diarrhoea"
	replace ordering = 30 if variable == "dyspepsia"
	replace ordering = 31 if variable == "dyspnoea"
	replace ordering = 32 if variable == "fatigue"
	replace ordering = 33 if variable == "night_sweats"
	replace ordering = 34 if variable == "pelvic_pain"
	replace ordering = 35 if variable == "stomach_disorders"
	replace ordering = 36 if variable == "weight_loss"
	
	replace ordering = 37 if variable == "bloodtest"
	replace ordering = 38 if variable == "fbc"
	replace ordering = 39 if variable == "haemoglobinconc"
	replace ordering = 40 if variable == "platelets"
	replace ordering = 41 if variable == "haematocritperc"
	replace ordering = 42 if variable == "apr"
	replace ordering = 43 if variable == "albumin"
	replace ordering = 44 if variable == "ferritin"
	replace ordering = 45 if variable == "im"
	replace ordering = 46 if variable == "esr"
	replace ordering = 47 if variable == "crp"
	replace ordering = 48 if variable == "pv"

	rename (*_) (*)
	order dataset ordering variable sum mean sd q1 q3
	format mean sd q1 q3 %5.3f
	format sum %9.0fc
	
	sort ordering
	drop dataset
	
	rename (sum mean sd q1 q3) `dataset'_=

end
		
	
/******************************************************************************/
/* Produce descriptive statistics
*/
tempfile cprd ukb

use ../../Data/Matt/ACED2_Data/cancers_symptoms_tests.dta, clear
levelsof new_cancer, local(levels)

qui foreach site in 0 `levels' {
	
	/**************************************************************************/
	/* UKB matching cprd */
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_ukb.dta, clear
	
	local text : label (new_cancer) `site'
	
	forval i = 1/5 {
		gen byte imd`i' = imd == `i'
	}
	
	order new_cancer eid age male imd? count_symptom
	keep  new_cancer eid age male imd? count_* median_consult symptom0 test0 date_cancer
	
	* discard irrelevant sites
	gen real_cancer = new_cancer
	if "`site'" == "0" {
		replace new_cancer = 0
	}
	keep if new_cancer == `site'
	
	symptom_counts, dataset(ukb)
	
	save `ukb', replace
	
	/**************************************************************************/
	/* CPRD */
	/* Actually, don't weight */
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_cprd.dta, clear
	
	forval i = 1/5 {
		gen byte imd`i' = imd == `i'
	}
	
	* discard irrelevant sites
	gen real_cancer = new_cancer
	if "`site'" == "0" {
		replace new_cancer = 0
	}
	keep if new_cancer == `site'

	symptom_counts, dataset(cprd) 
	
	save `cprd', replace
	
	/* Merge and look */
	use `ukb'
	merge 1:1 ordering variable using `cprd', assert(3) nogenerate
	
	list
		
	export excel using results/ukb_cprd_symptom_frequencies_`todaydate'.xlsx, firstrow(var) sheetreplace sheet("`text'")
}
	

