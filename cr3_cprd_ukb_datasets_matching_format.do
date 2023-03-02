cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison"


/******************************************************************************/
/* The detailed comparison with confidence intervals and everything */
describe using ../../Data/Matt/Aced2_Data/precancer_symptoms.dta

describe using ../../Data/Matt/Aced2_Data/cancers_symptoms_tests.dta


/******************************************************************************/
/* The detailed comparison with confidence intervals and everything */
local spline_knots -1 0 1
* NOTE age will be centred at 60 and scaled by a factor of 10
* so these are knots at 50 60 and 70


/******************************************************************************/
/* Get UKB data into format that matches CPRD data and save in well-named files*/
tempfile ukb cprd 

use ../../Data/Matt/Aced2_Data/precancer_symptoms.dta, clear

* Exclude withdrawals
merge 1:1 eid using w58356_20220222.dta
tab _merge
drop if _merge == 3
drop _merge

/*
merge 1:1 eid using w64351_20220222.dta
tab _merge
*/

* a ctry variable for use later
rename country ctry
replace ctry = 1 + ctry
label define ctry 1 "UKB England" 2 "UKB Scotland" 3 "UKB Wales", replace
label values ctry ctry

* CPRD now based on random sample
*keep if cprd_flag == 1

rename sex male

* age restriction
gen age = (date_cancer-date_birth)/365.24
keep if inrange(age, 30, 74.99999)

* date restriction
keep if date_cancer >= date("01-01-2006", "DMY") & date_cancer < date("01-01-2016", "DMY")

rename adj_imd_group imd

rename abdominal_bloat abdominal_bloating
rename (abdominal_bloating-pv) count_=

label define source 0 "CPRD" 1 "UKB", replace
gen byte source = 1
label values source source
rename consultations_1y count_consults

#delimit ;
egen count_symptom = rowtotal(
	count_abdominal_bloating
	count_abdominal_lump
	count_abdominal_pain
	count_breast_lump
	count_change_bowel
	count_constipation
	count_cough     
	count_diarrhoea 
	count_dyspepsia 
	count_dysphagia 
	count_dyspnoea  
	count_fatigue   
	count_haematuria               
	count_haemoptysis            
	count_jaundice  
	count_night_sweats            
	count_pelvic_pain
	count_pm_bleed  
	count_rectal_bleeding
	count_stomach_disorders
	count_weight_loss
	)
	;
#delimit cr

foreach var of varlist count_* {
	gen any_`var' = `var' >= 1
}

#delimit ;
egen multiple_symptoms1 = rowtotal(
	any_count_abdominal_bloating
	any_count_abdominal_lump
	any_count_abdominal_pain
	any_count_breast_lump
	any_count_change_bowel
	any_count_constipation
	any_count_cough     
	any_count_diarrhoea 
	any_count_dyspepsia 
	any_count_dysphagia 
	any_count_dyspnoea  
	any_count_fatigue   
	any_count_haematuria               
	any_count_haemoptysis            
	any_count_jaundice  
	any_count_night_sweats            
	any_count_pelvic_pain
	any_count_pm_bleed  
	any_count_rectal_bleeding
	any_count_stomach_disorders
	any_count_weight_loss
	)
	;
#delimit cr
	
gen multiple_symptoms = multiple_symptoms1 >= 2

drop any_* multiple_symptoms1

tab multiple_symptoms source, col

gen age_scale = (age-60)/10
mkspline age_spl = age_scale, cubic knots(`spline_knots')
drop age_scale

save ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_ukb.dta, replace


* Formatting of CPRD data to match the above
use ../../Data/Matt/Aced2_Data/cancers_symptoms_tests.dta

/*
use ../../Data/Matt/Aced2_Data/cancers_symptoms_tests_old_extract.dta, clear
*/


* age restriction
keep if inrange(age, 30, 74.99999)

* date restriction
keep if diagnosisdate >= date("01-01-2006", "DMY") & diagnosisdate < date("01-01-2016", "DMY")

gen byte male = sex == 1
drop sex

gen byte source = 0
label values source source

gen imd = 1 if imd1
forval i = 2/5 {
	replace imd = `i' if imd`i'
}
drop imd?
rename diagnosisdate date_cancer
rename deathdate date_death

drop site_icd10
drop cancer_site_desc
drop count_symptom

rename e_patid eid
drop age10
rename count_contact count_consults

#delimit ;
egen count_symptom = rowtotal(
	count_abdominal_bloating
	count_abdominal_lump
	count_abdominal_pain
	count_breast_lump
	count_change_bowel
	count_constipation
	count_cough     
	count_diarrhoea 
	count_dyspepsia 
	count_dysphagia 
	count_dyspnoea  
	count_fatigue   
	count_haematuria               
	count_haemoptysis            
	count_jaundice  
	count_night_sweats            
	count_pelvic_pain
	count_pm_bleed  
	count_rectal_bleeding
	count_stomach_disorders
	count_weight_loss
	)
	;
#delimit cr

foreach var of varlist count_* {
	gen any_`var' = `var' >= 1
}

#delimit ;
egen multiple_symptoms1 = rowtotal(
	any_count_abdominal_bloating
	any_count_abdominal_lump
	any_count_abdominal_pain
	any_count_breast_lump
	any_count_change_bowel
	any_count_constipation
	any_count_cough     
	any_count_diarrhoea 
	any_count_dyspepsia 
	any_count_dysphagia 
	any_count_dyspnoea  
	any_count_fatigue   
	any_count_haematuria               
	any_count_haemoptysis            
	any_count_jaundice  
	any_count_night_sweats            
	any_count_pelvic_pain
	any_count_pm_bleed  
	any_count_rectal_bleeding
	any_count_stomach_disorders
	any_count_weight_loss
	)
	;
#delimit cr

gen multiple_symptoms = multiple_symptoms1 >= 2

drop any_* multiple_symptoms1

tab multiple_symptoms source, col

gen age_scale = (age-60)/10
mkspline age_spl = age_scale, cubic knots(`spline_knots')
drop age_scale

compress
save ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_cprd.dta, replace
