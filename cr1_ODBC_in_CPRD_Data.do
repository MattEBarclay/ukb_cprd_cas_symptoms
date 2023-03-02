/* Loads in the various SQL extracts for processing in Stata */
cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison"
clear

* For choosing cancer to keep
set seed 1144


/******************************************************************************/
/* Create frames to store data in convenient memory */
frame change default

cap frame drop cancers
frame create cancers

cap frame drop clinical
frame create clinical

cap frame drop clinical_tests
frame create clinical_tests


/******************************************************************************/
/* Load in cancer cohort data */
frame change cancers
odbc load, exec("select * from 18_299_Lyratzopoulos.lookup_core_cancersite") clear dsn(matt)

desc 
list in 1/5

* count total patients in this period
gen diag_flag = 0
replace diag_flag = 1 if diagnosisdate >= date("01-01-2006", "DMY") & diagnosisdate <  date("01-01-2016", "DMY") 
tab diag_flag

keep if diag_flag

bys e_patid: gen one = _n == 1
total one if diag_flag

drop diag_flag

* exclude diagnoses not in continuous follow-up
gen byte fup_excl = 0

replace fup_excl = 1 if diagnosisdate < crd + 366 /* 1 full years of follow-up */
replace fup_excl = 1 if diagnosisdate < uts + 366 /* symptom period is UTS */
replace fup_excl = 1 if diagnosisdate > tod /* while registered with a practice */
replace fup_excl = 1 if diagnosisdate > lcd /* while practice has reported data */

tab fup_excl

drop if fup_excl
total one

* identify and keep first diagnosis
gen random_number = runiform()
sort e_patid random_number
by e_patid: keep if _n == 1

count

* age at first diagnosis - keep 30 to 75
count if inrange(age, 30, 74.99999999)
keep if inrange(age, 30, 74.99999999)

gen byte valid = 0 if sex == 1 & (cancer_site_desc == "Breast" | cancer_site_desc == "Breast (in-situ)")

tab valid

drop valid 

drop random_number




/******************************************************************************/
/* Load in gp clinical data */
frame change clinical
odbc load, exec("select * from gp_clinical_consultations") clear dsn(matt)

keep if eventdate >= diagnosisdate-365.25
keep if eventdate <= diagnosisdate

desc 
list in 1/5

* multiple consultations for same symptom on same day
* = drop
duplicates report
duplicates drop

compress
save ../../Data/Matt/ACED2_Data/clinical, replace

odbc load, exec("select * from gp_count_consultations") clear dsn(matt)
keep if eventdate >= diagnosisdate-365.25
keep if eventdate <= diagnosisdate
gen type = "Contact"
gen event_type = "Contact"
append using ../../Data/Matt/ACED2_Data/clinical
save ../../Data/Matt/ACED2_Data/clinical, replace


/******************************************************************************/
/* Load in tests data and append clinical data */
frame change clinical_tests
odbc load, exec("select * from gp_tests") clear dsn(matt)

keep if eventdate >= diagnosisdate-365.25
keep if eventdate <= diagnosisdate

desc 
list in 1/5

* multiple records for same test on same day
* = drop
duplicates report
duplicates drop

compress
append using ../../Data/Matt/ACED2_Data/clinical

* Reshape to wide format, counting number of tests
replace event_type = lower(subinstr(subinstr(event_type, "-", "", .))," ", "_", .) 
replace event_type = "pm_bleed" if event_type == "postmenopausal_bleeding"
replace event_type = "change_bowel" if event_type == "change_in_bowel_habit"

gen count = 1

collapse (sum) count (min) cons0 = eventdate (p50) median_consult = eventdate, by(e_patid type event_type) fast
list in 1/5

qui levelsof event_type, local(levels)
qui foreach event in `levels' {
	gen count_`event' = count if event_type == "`event'"
	replace count_`event' = 0 if event_type != "`event'"
}
gen count_symptom = count if type == "Symptom"

drop count
list in 1/5

* Identify first symptom, test consultation
* Identify median 'any contact' date
gen symptom0 = cons0 if type == "Symptom"
gen test0 = cons0 if type == "Test"
replace median_consult = . if type != "Contact" 
format symptom0 test0 median_consult %tdCY-N-D

collapse (sum) count* (min) symptom0 test0 (p50) median_consult, by(e_patid) fast
list in 1/5

label var test0 "First blood test in year before diagnosis"
label var symptom0 "First symptom in year before diagnosis"
label var median_consult "Date of 'median' consult in year before diagnosis"

* Now have count of each type of symptom / test and count of total symptoms


/******************************************************************************/
/* Switch back to cancer data */
frame change cancers

frlink 1:1 e_patid, frame(clinical_tests) gen(ct_link)
frget count* symptom0 test0 median_consult, from(ct_link)

foreach var of varlist count* {
	replace `var' = 0 if missing(ct_link)
}

drop ct_link

* Look at cancer site etc
label define new_cancer	 0 "All" /// /* for use later */
						 1 "Breast" ///
						 2 "Prostate" ///
						 3 "Colorectal" ///
						 4 "Lung" ///
						 5 "Melanoma" ///
						 6 "NHL" ///
						 7 "Kidney" ///
						 8 "Upper GI" ///
						 9 "Bladder" ///
						10 "Uterine" ///
						99 "Other" ///
						, replace
						
gen byte new_cancer = .
replace new_cancer =  1 if inlist(cancer_site_desc, "Breast", "Breast (in-situ)")
replace new_cancer =  2 if inlist(cancer_site_desc, "Prostate")
replace new_cancer =  3 if inlist(cancer_site_desc, "Colon", "Rectum")
replace new_cancer =  4 if inlist(cancer_site_desc, "Lung", "Mesothelioma")
replace new_cancer =  5 if inlist(cancer_site_desc, "Melanoma")
replace new_cancer =  6 if inlist(cancer_site_desc, "Non-hodgkin lymphoma")
replace new_cancer =  7 if inlist(cancer_site_desc, "Kidney")
replace new_cancer =  8 if inlist(cancer_site_desc, "Stomach", "Oesophagus")
replace new_cancer =  9 if inlist(cancer_site_desc, "Bladder", "Bladder (in-situ)")
replace new_cancer = 10 if inlist(cancer_site_desc, "Uterus")

tab new_cancer cancer_site_desc

replace new_cancer = 99 if missing(new_cancer)
assert !missing(new_cancer)

label values new_cancer new_cancer
tab new_cancer
order new_cancer

* discard male breast cancer
drop if sex == 1 & new_cancer == 1

* discard missing IMD
drop if missing(imd2015_10)
assert !missing(age)
assert !missing(sex)

* format imd
gen imd1 = inlist(imd2015_10, 1,  2)
gen imd2 = inlist(imd2015_10, 3,  4)
gen imd3 = inlist(imd2015_10, 5,  6)
gen imd4 = inlist(imd2015_10, 7,  8)
gen imd5 = inlist(imd2015_10, 9, 10)
drop imd2015_10

* ten-year age group
gen age10 = floor(age/10)*10

order e_patid age age10 sex imd? diagnosisdate new_cancer deathdate

compress
save ../../Data/Matt/ACED2_Data/cancers_symptoms_tests.dta, replace


/******************************************************************************/
/* Back to default frame */
frame change default

cap frame drop cancers
cap frame drop clinical
cap frame drop clinical_tests


/******************************************************************************/
/* Calculate weights */
/*
* Calculate patient counts in CPRD
tempfile cprd_counts

use ../../Data/Matt/ACED2_Data/cancers_symptoms_tests.dta, clear

keep e_patid age10 sex imd? new_cancer

gen byte imd = .
replace imd = 1 if imd1
replace imd = 2 if imd2
replace imd = 3 if imd3
replace imd = 4 if imd4
replace imd = 5 if imd5
drop imd?

rename sex sex_n
gen sex = "Men" if sex_n == 1
replace sex = "Women" if sex_n == 2

gen byte count = 1

expand 2, gen(expanded)
replace new_cancer = 0 if expanded

collapse (sum) count, by(age10 sex imd new_cancer)
fillin age10 sex imd new_cancer
replace count = 0 if _fillin
drop _fillin

sort new_cancer sex age10 imd
order new_cancer sex age10 imd count

rename count cprd_count

save `cprd_counts'

* Pull in patient counts from UKB
use ../../Data/Matt/ACED2_Data/precancer_symptoms.dta, clear
keep if cprd_flag

gen ukb_count = 1
gen age = (date_cancer-date_birth)/365.24
rename adj_imd_group imd
gen age10 = floor(age/10)*10

rename sex sex_n
gen sex = "Men" if sex_n == 1
replace sex = "Women" if sex_n == 0
drop sex_n

collapse (sum) ukb_count, by(new_cancer age10 sex imd)

merge 1:1 new_cancer sex age10 imd using `cprd_counts', assert(2 3) 
replace ukb_count = 0 if _merge == 2
drop _merge


sort new_cancer sex age10 imd
order new_cancer sex age10 imd ukb_count cprd_count

* Hunt for 0s
gen problem = cprd_count == 0 & ukb_count != 0
tab problem

list if problem

* Merge imd2 with imd1 for 40-y men prostate
list if new_cancer == 2 & sex == "Men" & age10 == 40
replace imd = 1 if imd == 2 & new_cancer == 2 & sex == "Men" & age10 == 40

* Merge imd5 with imd4 for 40-y women kidney
list if new_cancer == 7 & sex == "Women" & age10 == 40
replace imd = 5 if imd == 4 & new_cancer == 7 & sex == "Women" & age10 == 40

collapse (sum) cprd_count ukb_count, by(new_cancer sex age10 imd)

* Hunt for 0s
gen problem = cprd_count == 0 & ukb_count != 0
assert problem == 0
drop problem

* PSW weight = ukb count / cprd count
gen psw = ukb_count/cprd_count
replace psw = 0 if ukb_count == 0

assert !missing(psw)

forval i = 1/5 {
	gen byte imd`i' = imd == `i'
}
drop imd

order new_cancer sex age10 imd? *count

drop if new_cancer == 0 // all - recreate from cancer-specific weights later

compress
save ../../Data/Matt/ACED2_Data/psw, replace
*/