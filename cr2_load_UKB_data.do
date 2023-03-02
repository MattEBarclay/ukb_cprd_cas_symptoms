/* Find date of first cancer diagnosis 
	Work out if in primary care data for two+ years before that date
		(first year weird)
	Keep first year before colorectal cancer diagnosis for use in clustering
	
	
	Only take "first cancers after 2006-01-01" that are after UKB entry date.
	
	
*/

/* This pulls in information from the biobank_dataloading higher-level folder */


/* Loads the relevant cohort and year of symptoms before cancer diagnosis */
cd "S:\FPHS_ECHO_UKB\Matt Barclay\biobank_analysis\analysis4_ukb_cprd_comparison"


/******************************************************************************/
/* Create analysis frames */
frame change default

cap frame drop first_cas
frame create   first_cas

cap frame drop process_registrations
frame create   process_registrations

cap frame drop baseline_data
frame create   baseline_data

cap frame drop symptom_data
frame create   symptom_data

cap frame drop symptom_data_flag
frame create   symptom_data_flag

cap frame drop bloodtest_data
frame create   bloodtest_data

foreach thing in tpp rv2 {
	cap frame drop baseline_data_`thing'
	cap frame drop process_registrations_`thing' 
	cap frame drop symptom_data_`thing'
	cap frame drop bloodtest_data_`thing'
}


/******************************************************************************/
/* Load in cancers and pull out "first cancers" */
frame change first_cas
use ../../biobank_dataloading/data/ukb_cancers, clear

* Discard cancers from before 2006
keep if date_cancer >= date("2006-01-01", "YMD")
keep if date_cancer <= date("2015-12-31", "YMD")

* Discard complete duplicates
duplicates drop

* keep first cancer
set seed 1348
gen random_ordering = runiform() // for reproducibility
sort eid date_cancer random_ordering

preserve
tempfile first_date
by eid: keep if _n == 1
keep eid date_cancer
count
save `first_date'
restore

count
merge m:1 eid date_cancer using `first_date', assert(1 3) keep(3) nogenerate

* after discarding 'not firsts'
count
duplicates tag eid, gen(tag)
*br if tag

sort eid date_cancer random_ordering
by eid: keep if _n == 1

* after discarding 'randomly chosen cancers from that first date'
count
drop random_ordering


* generate new cancer site category
decode cancer_site, gen(c_str)

label define new_cancer  0 "All" /// /* for use later */
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
replace new_cancer =  1 if inlist(c_str, "Breast", "Breast (in-situ)") /* but not in-situ? */
replace new_cancer =  2 if inlist(c_str, "Prostate") 
replace new_cancer =  3 if inlist(c_str, "Colon", "Rectum")
replace new_cancer =  4 if inlist(c_str, "Lung", "Mesothelioma")
replace new_cancer =  5 if inlist(c_str, "Melanoma")
replace new_cancer =  6 if inlist(c_str, "Non-hodgkin lymphoma")
replace new_cancer =  7 if inlist(c_str, "Kidney")
replace new_cancer =  8 if inlist(c_str, "Stomach", "Oesophagus")
replace new_cancer =  9 if inlist(c_str, "Bladder", "Bladder (in-situ)")
replace new_cancer = 10 if inlist(c_str, "Uterus")
replace new_cancer = 99 if missing(new_cancer) /* Only cancers so all here */
assert !missing(new_cancer)

label values new_cancer new_cancer
tab new_cancer

count


/******************************************************************************/
/* Process registration data */
frame change process_registrations

use ../../biobank_dataloading/data/gp_registrations, clear

/* Frames for TPP and non-TPP data */
frame put if data_provider == 3, into(process_registrations_tpp)
frame put if data_provider != 3, into(process_registrations_rv2)

foreach thing in process_registrations process_registrations_tpp process_registrations_rv2 {
	
	frame change `thing'
	
	/* Don't care about data provider */
	drop data_provider
	drop gp_spell /* about to reproduce this */

	/* less than 90 days between registrations == continuous */
	sort eid date_reg
	local allowable_gap = 90
	by eid: gen discont = (date_deduct[_n-1]-date_reg[_n]+`allowable_gap') < 0
	cap assert missing(discont) | discont == 0

	gen gp_spell = 0
	by eid: replace gp_spell = cond(_n==1,0,gp_spell[_n-1]+discont[_n])

	* squash so get start and end of continuous gp registration spells
	collapse (min) date_reg (max) date_deduct, by(eid gp_spell)

	* if date_reg == previous date_deduct, add one day
	sort eid date_reg
	by eid: replace date_deduct = date_reg[_n+1]-1 if date_deduct[_n]>=date_deduct[_n+1]
	by eid: replace gp_spell = _n - 1

	assert !missing(date_reg)
	assert !missing(date_deduct)

	label var date_reg "Date of GP registration"
	label var date_deduct "Date of GP de-registration"
	label var gp_spell "Distinct spell of continuous GP registration"
	
	nois count
	
}

desc


/******************************************************************************/
/* Merge from cancers to GP spells */
foreach frame in process_registrations process_registrations_tpp process_registrations_rv2 {

	frame change `frame'
	frlink m:1 eid, frame(first_cas)

	* discard patients without cancer
	drop if missing(first_cas)

	* pull in date of cancer, and keep rows where cancer occurred in that continuous
	* gp spell
	frget date_cancer new_cancer c_str, from(first_cas)
	keep if inrange(date_cancer, date_reg, date_deduct)

	* check no duplicate EIDs
	duplicates report eid
	duplicates tag eid, gen(tag)
	assert tag == 0
	drop tag

	* drop cases where start of follow-up less than 2 years before cancer
	*drop if date_reg + 365*2 >= date_cancer

	* UPDATE drop cases where start of follow-up less than *1* years before cancer
	gen byte todrop = date_reg + 365   >= date_cancer
	tab todrop
	drop if todrop
	drop todrop
	nois count
}


/******************************************************************************/
/* Load in baseline information on IMD, age, sex, smoking, BMI */
frame change baseline_data
use ../../biobank_dataloading/data/baseline_no_cancers.dta, clear

/* Frames for TPP and non-TPP data */
frame put _all, into(baseline_data_tpp)
frame put _all, into(baseline_data_rv2)

foreach thing in all tpp rv2 {
	
	if "`thing'" == "all" {
		local sfx ""
	}
	if "`thing'" != "all" {
		local sfx "_`thing'"
	}
	
	frame change baseline_data`sfx'
	
	* keep relevant information
	keep eid sex date_entry date_birth date_death height weight ethnic_background bmi weight ///
		adj_imd_group assessment smoking_status 

	* identify country
	gen byte country = .
	replace country = 0
	replace country = 1 if inlist(assessment_centre, 11005, 11004) // scotland
	replace country = 2 if inlist(assessment_centre, 11003, 11022, 11023) // wales

	label define country 0 "England" 1 "Scotland" 2 "Wales", replace
	label values country country

	* cut down to relevant variables again
	keep eid sex date_entry date_birth date_death height weight ethnic_background bmi weight ///
		adj_imd_group country smoking_status
		
	* link with registrations and cancer data, and get rid of those with no
	* cancer / no GP data at cancer
	frlink 1:1 eid, frame(process_registrations`sfx')
	drop if missing(process_registrations`sfx')

	* pull in relevant data from registrations file
	frget date_cancer new_cancer c_str, from(process_registrations`sfx')
	
}


/******************************************************************************/
/* Load in symptom consultation information */
frame change symptom_data

use ../../biobank_dataloading/data/gp_clinical_symptom_22symptom.dta, clear

drop if symptom == 22 /* UTI */

/* Frames for TPP and non-TPP data */
frame put if data_provider == 3, into(symptom_data_tpp)
frame put if data_provider != 3, into(symptom_data_rv2)

foreach thing in all tpp rv2 {
	
	if "`thing'" == "all" {
		local main_frame "symptom_data"
		local registered "process_registrations"
	}
	if "`thing'" != "all" {
		local main_frame "symptom_data_`thing'"
		local registered "process_registrations_`thing'"
	}
	
	frame change `main_frame'
	
	* linked to processed registration data and keep the matches
	* i.e. patients with cancer
	frlink m:1 eid, frame(`registered')
	keep if !missing(`registered')

	* pull in relevant cancer date
	frget date_cancer, from(`registered')
	gen left_censor = date_cancer-365
	keep if inrange(event_date, left_censor, date_cancer)
	compress
	count

	* reshape into one row per participant
	keep eid event_date symptom
	sort eid event_date
	decode symptom, gen(symptom_str)
	replace symptom_str = subinstr(lower(symptom_str), " ", "_", .)
	replace symptom_str = "change_bowel" if symptom_str == "change_in_bowel_habit"
	replace symptom_str = "pm_bleed" if symptom_str == "post-menopausal_bleeding"
	replace symptom_str = "abdominal_bloat" if symptom_str == "abdominal_bloating"
	tab symptom_str

	* generate indicator vars
	qui levelsof symptom_str, local(levels)
	foreach var in `levels' {
		gen byte `var' = symptom_str == "`var'"
	}

	* count how many in year before diagnosis
	qui levelsof symptom_str, local(levels)
	collapse (sum) `levels' (min) symptom0 = event_date, by(eid) fast

}


/******************************************************************************/
/* Want to identify patients who _ever_ report a relevant symptom_data
	to approximate the CPRD inclusion criteria
 */
frame change symptom_data_flag

use ../../biobank_dataloading/data/gp_clinical_symptom_22symptom.dta, clear

drop if symptom == 22 /* UTI */

* linked to processed registration data and keep the matches
* i.e. patients with cancer
frlink m:1 eid, frame(process_registrations)
keep if !missing(process_registrations)

* Only keep the first 15 symptoms
drop if symptom > 15

* Only keep symptoms in 2007-2016
keep if inrange(year(event_date), 2007, 2016)

* these are all the patients with any symptoms
keep eid
sort eid
by eid: keep if _n == 1

count


/******************************************************************************/
/* Load in bloodtest consultation information */
frame change bloodtest_data 

use ../../biobank_dataloading/data/gp_clinical_biomarker_biomarkers.dta, clear

/* Frames for TPP and non-TPP data */
frame put if data_provider == 3, into(bloodtest_data_tpp)
frame put if data_provider != 3, into(bloodtest_data_rv2)

foreach thing in all tpp rv2 {
	
	if "`thing'" == "all" {
		local main_frame "bloodtest_data"
		local registered "process_registrations"
	}
	if "`thing'" != "all" {
		local main_frame "bloodtest_data_`thing'"
		local registered "process_registrations_`thing'"
	}
	
	frame change `main_frame'
		
	* linked to processed registration data and keep the matches
	* i.e. patients with cancer
	frlink m:1 eid, frame(`registered')
	keep if !missing(`registered')

	* pull in relevant cancer date
	frget date_cancer, from(`registered')
	gen left_censor = date_cancer-365
	keep if inrange(event_date, left_censor, date_cancer)
	compress
	count

	* reshape into one row per participant
	keep eid event_date biomarker
	sort eid event_date
	replace biomarker = subinstr(lower(biomarker), " ", "_", .)
	tab biomarker

	* generate indicator vars
	qui levelsof biomarker, local(levels)
	foreach var in `levels' {
		gen byte `var' = biomarker == "`var'"
	}

	* count how many in year before diagnosis
	qui levelsof biomarker, local(levels)
	collapse (sum) `levels' (min) test0 = event_date, by(eid) fast
	
}


/******************************************************************************/
/* Get baseline data and pull in indicator data from symptoms */
qui foreach thing in all tpp rv2 {
	
	if "`thing'" == "all" {
		local sfx ""
	}
	if "`thing'" != "all" {
		local sfx "_`thing'"
	}
	
	frame change baseline_data`sfx'
	nois count
	frlink 1:1 eid, frame(symptom_data`sfx')
	frlink 1:1 eid, frame(bloodtest_data`sfx')
	count 
	count if !missing(symptom_data`sfx')
	count if !missing(bloodtest_data`sfx')

	frget abdominal_bloat abdominal_lump abdominal_pain  breast_lump ///
		change_bowel constipation cough diarrhoea dyspepsia dysphagia dyspnoea ///
		fatigue ///
		haematuria haemoptysis jaundice /// 
		night_sweats pelvic_pain pm_bleed rectal_bleeding /// 
		stomach_disorders weight_loss ///
		symptom0 /// 
		,	from(symptom_data`sfx')
		
	frget albumin crp esr ferritin haematocritperc haemoglobinconc platelets pv /// 
		test0 ///
		,	from(bloodtest_data`sfx')
		
	desc
	keep eid sex date_entry date_birth date_death height weight bmi ethnic_background ///
		smoking_status adj_imd_group country c_str new_cancer date_cancer ///
		abdominal_bloat abdominal_pain abdominal_lump breast_lump ///
		change_bowel constipation cough diarrhoea dyspepsia dysphagia dyspnoea /// 
		fatigue ///
		haematuria haemoptysis jaundice /// 
		night_sweats pelvic_pain pm_bleed rectal_bleeding /// 
		stomach_disorders weight_loss ///
		albumin crp esr ferritin haematocritperc haemoglobinconc platelets pv ///
		symptom0 test0

	order eid sex date_entry date_birth date_death height weight bmi ethnic_background ///
		smoking_status adj_imd_group country c_str new_cancer date_cancer ///
		abdominal_bloat abdominal_lump abdominal_pain  breast_lump ///
		change_bowel constipation cough diarrhoea dyspepsia dysphagia dyspnoea ///
		fatigue ///
		haematuria haemoptysis jaundice /// 
		night_sweats pelvic_pain pm_bleed rectal_bleeding /// 
		stomach_disorders weight_loss ///
		albumin crp esr ferritin haematocritperc haemoglobinconc platelets pv ///
		symptom0 test0

	* missing means didn't happen (or wasn't recorded)
	* check this line if included symptoms changes
	foreach var of varlist abdominal_bloat-weight_loss albumin-pv {
		replace `var' = 0 if missing(`var')
	}
	
	
	* exclude age <30 or >75 at diagnosis
	gen temp_age = (date_cancer-date_birth)/365.25
	nois drop if temp_age < 30 | temp_age >= 74.999999
	drop temp_age
		
	* exclude male breast cancer (due to tiny numbers)
	nois drop if sex == 1 & new_cancer == 1 /* Breast */
		
	* exclude unknown IMD (there should not be any but... around 2%)
	* this points to data processing problems at UKB tbh
	nois drop if adj_imd_group == .
		
	compress
	label data "Symptoms, bloodtests and baseline, first cas"	

	/* Approximate CPRD cohort */
	* Keep if cancer between 2006 and 2015 & symptom between 2007 and 2016

	frlink m:1 eid, frame(symptom_data_flag)

	gen byte cprd_flag = inrange(year(date_cancer), 2006, 2015) & !missing(symptom_data_flag)
	label var cprd_flag "Matches CPRD inclusion criteria"
	drop symptom_data_flag

	* Add in consultation counts
	merge 1:1 eid date_cancer using data/gp_consult_count
	replace consultations_1y = 0 if _merge == 1
	drop if _merge == 2
	drop _merge
		
	save data/all_precancer_symptoms`sfx'.dta, replace
		
	* discard if cancer was before date of UKB entry
	* this is the "alt" thing
	nois drop if date_cancer < date_entry
	
	save data/precancer_symptoms`sfx'.dta, replace

}


/******************************************************************************/
/* Clean up */
frame change default
frame drop baseline_data 
frame drop first_cas 
frame drop process_registrations 
frame drop symptom_data
frame drop symptom_data_flag
frame drop bloodtest_data

foreach thing in tpp rv2 {
	frame drop baseline_data_`thing'
	frame drop process_registrations_`thing' 
	frame drop symptom_data_`thing'
	frame drop bloodtest_data_`thing'
}


use data/precancer_symptoms.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria

use data/precancer_symptoms_tpp.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria

use data/precancer_symptoms_rv2.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria

use data/all_precancer_symptoms.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria

use data/all_precancer_symptoms_tpp.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria

use data/all_precancer_symptoms_rv2.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria


use data/precancer_symptoms.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria consultation

use data/all_precancer_symptoms.dta, replace
count 
summ fatigue abdominal_pain breast_lump haematuria consultation


