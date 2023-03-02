/* Counts symptom occurences in CPRD data */

cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison" 
frame change default

local todaydate : display %tdCCYY-NN-DD = daily("`c(current_date)'", "DMY")


/******************************************************************************/
/* Program for modelling loop */
cap program drop modelling_loop
program define modelling_loop
	syntax , symptom_n(real)
	
	tempname working_ukb working_cprd
	
	* Outer loop, over cancers
	forval cancer = 1/12 {

		* Cancer labelling
		if `cancer' == 11 {
			local cancer 99
		}

		if `cancer' != 12 {
			frame data_cprd: local cancer_text : label new_cancer `cancer'
		}
		if `cancer' == 12 {
			local cancer_text "All cancers"
		}
		nois di as text _newline _col(10) "`cancer_text'" _cont
			
		* Inner loop, over symptoms
		forval symptom = 1/`symptom_n' {

			* Symptom labelling
			frame data_cprd: local symptom_text : label symptom `symptom'
			nois di _cont " ." _cont

			* Working data into tempframes
			if `cancer' != 12 {
				frame data_cprd: frame put if new_cancer == `cancer' & symptom == `symptom', into(`working_cprd')
				frame data_ukb : frame put if new_cancer == `cancer' & symptom == `symptom', into(`working_ukb')
			}
			else {
				frame data_cprd: frame put if                          symptom == `symptom', into(`working_cprd')
				frame data_ukb : frame put if                          symptom == `symptom', into(`working_ukb')
			}
			frame `working_cprd': cap gen byte cprd_flag = 1
			frame `working_ukb' : cap gen byte ukb_flag  = 1

			* Check at least ten events in both data sources
			* Or all cancers
			frame `working_cprd': count if any != 0
			local count0 = r(N)
			frame `working_ukb' : count if any != 0
			local count1 = r(N)
			
			* If at least ten events (or all cancer), then fit the models separately
			* in each data file
			if /*(*/ (`count0' > 10 & `count1' > 10) /*& !(`symptom' == 28 & `cancer' == 4))*/ | (`cancer' == 12) {

				* free estimation in CPRD
				if `cancer' != 12 {
					frame `working_cprd': poisson count_ c.age_spl1 c.age_spl2 i.imd i.male, vce(robust)
				}
				if `cancer' == 12 {
					frame `working_cprd': poisson count_ c.age_spl1 c.age_spl2 i.imd i.male i.new_cancer, vce(robust)
				}
				estimates save results/model_files/cprd_cancer`cancer'_symptom`symptom', replace
				
				frame `working_ukb' {
										
					estimates use results/model_files/cprd_cancer`cancer'_symptom`symptom'
					predict cprd_prediction, n
					
					summ cprd_prediction
					
					poisson count_ i.ukb_flag, exposure(cprd_prediction) vce(robust) noconstant
				}
				
				estimates save results/model_files/ukb_cancer`cancer'_symptom`symptom'_vsCRPD, replace
							
				* extract variance of 'average difference in CPRD vs UKB prediction'
				local mle = e(b)[1,"count_:1.ukb_flag"]
				local var = e(V)["count_:1.ukb_flag","count_:1.ukb_flag"]
				
				* extract CIs 
				local lb_n  = exp(`mle'-1.96*sqrt(`var'))
				local ub_n  = exp(`mle'+1.96*sqrt(`var'))
				local mle_n = exp(`mle')
				
				local lb_str  = strofreal(exp(`mle'-1.96*sqrt(`var')), "%03.2f")
				local ub_str  = strofreal(exp(`mle'+1.96*sqrt(`var')), "%03.2f")
				local mle_str = strofreal(exp(`mle'), "%03.2f")
				
				local ci  = "RR UKB vs CPRD: `mle_str' (95% CI `lb_str'-`ub_str')"
			
				* put the results in a useful frame
				frame model_res {
				
					set obs `=_N+1'
					replace cancer = "`cancer_text'" in `=_N'
					replace symptom = "`symptom_text'" in `=_N'
					replace ci_text = "`ci'" in `=_N'
					
					replace rr = `mle_n' in `=_N'
					replace rr_lb = `lb_n' in `=_N'
					replace rr_ub = `ub_n' in `=_N'
				}

			}
			else {
				// if not enough participants, just note
				frame model_res {
					set obs `=_N+1'
					replace cancer = "`cancer_text'" in `=_N'
					replace symptom = "`symptom_text'" in `=_N'
					replace ci_text = "<5 participants with symptom" in `=_N'
				}
			}
			
			* discard temp frames
			frame `working_cprd': clear
			frame drop `working_cprd'
			frame `working_ukb': clear
			frame drop `working_ukb'
		}
		* end of inner (symptom) loop
	}
	* end of outer (cancer) loop
end


/******************************************************************************/
/* Define specific/non-specific symptoms */
cap program drop assign_symptom_classes
program assign_symptom_classes
			
	#delimit ;
	egen count_ns = rowtotal(
		count_abdominal_bloat 
		count_abdominal_pain 
		count_constipation 
		count_cough 
		count_diarrhoea 
		count_dyspepsia 
		count_dyspnoea 
		count_fatigue 
		count_night_sweats
		count_pelvic_pain
		count_stomach_disorders
		count_weight_loss
		)
		;
		
	egen count_ss = rowtotal(
		count_jaundice
		count_breast_lump
		count_dysphagia
		count_haemoptysis
		count_rectal_bleed
		count_pm_bleed
		count_haematuria
		count_abdominal_lump
		count_change_bowel
		)
		;
		
	egen count_bt = rowtotal(
		count_crp
		count_esr
		count_ferritin
		count_haemato
		count_haemogl
		count_platelets
		count_pv
		)
		;
	#delimit cr
	
end


/******************************************************************************/
/* Individual symptoms and tests */
cap frame data_ukb: clear
cap frame drop data_ukb
frame create data_ukb

cap frame data_cprd: clear
cap frame drop data_cprd
frame create data_cprd

* set up results storage
cap frame drop model_res
frame create model_res
frame model_res {
	clear
	gen cancer  = ""
	gen symptom = ""
	gen ci_text = ""
	gen rr = .
	gen rr_lb = .
	gen rr_ub = .
}

* set up separate CPRD and UKB data files
frame data_cprd {
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_cprd.dta, clear
	
	bys source: summ age 

	drop count_symptom multiple_symptom
	drop count_consult

	reshape long count_, i(eid source) j(symptom_str) string

	encode symptom_str, gen(symptom)
	
	gen byte any = count_ >= 1
	table symptom, statistic(mean any)
	compress
}

frame data_ukb {
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_ukb.dta, clear
	
	bys source: summ age 

	drop count_symptom multiple_symptom
	drop count_consult

	reshape long count_, i(eid source) j(symptom_str) string

	encode symptom_str, gen(symptom)

	gen byte any = count_ >= 1
	table symptom, statistic(mean any)
	compress
}

* do the modelling
modelling_loop, symptom_n(29)

frame model_res {
	list if symptom == "consults", sepby(cancer)
	list if symptom == "abdo_pain", sepby(cancer)
	save results/direct_ukb_cprd_comparisons_symptoms_tests_`todaydate'.dta, replace
}

	
/******************************************************************************/
/* Number and timing of consultations */
cap frame data_ukb: clear
cap frame drop data_ukb
frame create data_ukb

cap frame data_cprd: clear
cap frame drop data_cprd
frame create data_cprd

* set up results storage
cap frame drop model_res
frame create model_res
frame model_res {
	clear
	gen cancer  = ""
	gen symptom = ""
	gen ci_text = ""
	gen rr = .
	gen rr_lb = .
	gen rr_ub = .
}

* set up separate CPRD and UKB data files
frame data_cprd {
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_cprd.dta, clear
	desc 

	bys source: summ age 

	keep eid male age imd date_cancer count_consults symptom0 test0 median_consult  new_cancer count_symptom source age_spl*
	rename count_symptom count_symptom_consults

	bys source: summ age 

	foreach thing in symptom0 test0 median_consult {
		replace `thing' = date_cancer-`thing'
	}
	rename (symptom0 test0 median_consult) count_=

	reshape long count_, i(eid source) j(symptom_str) string

	* drop irrelevant
	drop if symptom_str == "median_consult"
	drop if symptom_str == "symptom0"
	drop if symptom_str == "test0"
	
	encode symptom_str, gen(symptom)
	
	gen byte any = count_ >= 1 & !missing(count_)
	
	compress
	table symptom, statistic(mean any) statistic(mean count)
}

frame data_ukb {
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_ukb.dta, clear
	
	bys source: summ age 

	keep eid male age imd date_cancer count_consults symptom0 test0 median_consult  new_cancer count_symptom source age_spl*
	rename count_symptom count_symptom_consults

	bys source: summ age 

	foreach thing in symptom0 test0 median_consult {
		replace `thing' = date_cancer-`thing'
	}
	rename (symptom0 test0 median_consult) count_=

	reshape long count_, i(eid source) j(symptom_str) string

	* drop irrelevant
	drop if symptom_str == "median_consult"
	drop if symptom_str == "symptom0"
	drop if symptom_str == "test0"
	
	encode symptom_str, gen(symptom)
	
	gen byte any = count_ >= 1 & !missing(count_)
	
	compress
	table symptom, statistic(mean any) statistic(mean count)
}

* do the modelling
qui modelling_loop, symptom_n(2)

frame model_res {
	list if symptom == "consults", sepby(cancer)
	list if symptom == "abdo_pain", sepby(cancer)
	save results/direct_ukb_cprd_comparisons_consults_`todaydate'.dta, replace
}



/******************************************************************************/
/* Any / multiple symptoms */
cap frame data_ukb: clear
cap frame drop data_ukb
frame create data_ukb

cap frame data_cprd: clear
cap frame drop data_cprd
frame create data_cprd

* set up results storage
cap frame drop model_res
frame create model_res
frame model_res {
	clear
	gen cancer  = ""
	gen symptom = ""
	gen ci_text = ""
	gen rr = .
	gen rr_lb = .
	gen rr_ub = .
}

* set up separate CPRD and UKB data files
frame data_cprd {
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_cprd.dta, clear

	bys source: summ age 
	
	* assign symptoms to classes
	assign_symptom_classes	
	
	keep eid male age imd date_cancer new_cancer source age_spl* count_symptom multiple_symptoms count_ns count_ss count_bt
	rename count_symptom count_any_symptom
	rename multiple_symptoms count_mul_symptom
	
	reshape long count_, i(eid source) j(symptom_str) string

	encode symptom_str, gen(symptom)
	
	gen byte any = count_ >= 1 & !missing(count_)
	
	compress
	table symptom, statistic(mean any) statistic(mean count)
}

frame data_ukb {
	use ../../Data/Matt/Aced2_Data/ukb_cprd_direct_comparison_ukb.dta, clear

	bys source: summ age 
	
	* assign symptoms to classes
	assign_symptom_classes	
	
	keep eid male age imd date_cancer new_cancer source age_spl* count_symptom multiple_symptoms count_ns count_ss count_bt
	rename count_symptom count_any_symptom
	rename multiple_symptoms count_mul_symptom
	
	reshape long count_, i(eid source) j(symptom_str) string

	encode symptom_str, gen(symptom)
	
	gen byte any = count_ >= 1 & !missing(count_)
	
	compress
	table symptom, statistic(mean any) statistic(mean count)
}

* do the modelling
qui modelling_loop, symptom_n(5)

frame model_res {
	list if symptom == "consults", sepby(cancer)
	list if symptom == "abdo_pain", sepby(cancer)
	save results/direct_ukb_cprd_comparisons_summary_symptoms_`todaydate'.dta, replace
}


/******************************************************************************/
/* Clean up */
cap frame data_ukb: clear
cap frame drop data_ukb

cap frame data_cprd: clear
cap frame drop data_cprd

cap frame drop model_res
frame create model_res
