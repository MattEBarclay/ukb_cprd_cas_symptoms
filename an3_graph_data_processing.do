* processing used for formatting graphs
* useful to have in one place for consistency

cap program drop graph_data_processing
program graph_data_processing
	syntax, country_spec(string) [formatrix]
	
	if "`country_spec'" == "yes" {
		/*foreach thing in rr1 rr2 rr3 {
			replace `thing' = 1/`thing'
			rename (`thing'_lb `thing'_ub) (temp_ub temp_lb)
			gen `thing'_lb = 1/temp_lb
			gen `thing'_ub = 1/temp_ub /* note deliberate flip */
			drop temp_lb temp_ub
		}*/
	}
	
	if "`country_spec'" == "no" {
		* already in UKB vs CPRD
		/*replace rr = 1/rr
		rename (rr_lb rr_ub) (temp_ub temp_lb)
		gen rr_lb = 1/temp_lb
		gen rr_ub = 1/temp_ub /* note deliberate flip */
		drop temp_lb temp_ub*/		
	}

	* exclude symptoms not considered
	drop if symptom == "test0"
	drop if symptom == "symptom_consults"

	* cancer ordering
	label define new_cancer	0 "All cancers" ///
							1 "Breast" /// 
							2 "Prostate" /// 
							3 "Colorectal" /// 
							4 "Lung" /// 
							5 "Melanoma" /// 
							6 "NHL" /// 
							7 "Bladder" /// 
							8 "Uterine" /// 
							9 "Kidney" /// 
						   10 "Upper GI" /// 
						   11 "Other" /// 
						   , replace
	encode cancer, gen(new_cancer) label(new_cancer)
	tab cancer new_cancer

	* outcome grouping, ordering
	label define outcome_group 1 "GP consultations" 2 "Any relevant symptom" 3 "'Alarm' symptoms" 4 "'Non-alarm' symptoms" 5 "Blood tests", replace

	gen outcome_group = .
	replace outcome_group = 1 if inlist(symptom, "consults", "symptom_consults")
	replace outcome_group = 2 if inlist(symptom, "any_symptom", "mul_symptom" /*, "ns", "ss", "bt" */ )
	replace outcome_group = 3 if inlist(symptom, "ss")
	replace outcome_group = 3 if inlist(symptom, "jaundice", "breast_lump", "dysphagia", "haemoptysis", "rectal_bleeding", "pm_bleed", "haematuria", "change_bowel", "abdominal_lump")
	replace outcome_group = 5 if inlist(symptom, "bt", "crp", "esr", "ferritin", "haematocritperc", "haemoglobinconc", "pv", "platelets", "albumin")
	replace outcome_group = 4 if missing(outcome_group)
	label values outcome_group outcome_group

	* ordering for symptoms on dotplot
	gen symptom_str = upper(substr(symptom,1,1))+(subinstr(substr(symptom,2,.), "_", " ", .))
	replace symptom_str = "Change in bowel habit" if symptom_str == "Change bowel"
	replace symptom_str = upper(symptom_str) if length(symptom_str) <= 3
	replace symptom_str = "PM bleeding" if symptom_str == "Pm bleed"
	replace symptom_str = "Nausea / vomiting" if symptom_str == "Stomach disorders"

	replace symptom_str = "Total consults" if symptom_str == "Consults"
	replace symptom_str = "Median consult" if symptom_str == "Median consult"
	replace symptom_str = "First symptom consult" if symptom_str == "Symptom0"

	replace symptom_str = "Multiple symptoms" if symptom_str == "Mul symptom"

	replace symptom_str = "Haematocrit %" if symptom_str == "Haematocritperc"
	replace symptom_str = "Haemoglobin" if symptom_str == "Haemoglobinconc"

	replace symptom_str = "Any 'non-alarm' symptom" if symptom_str == "NS"
	replace symptom_str = "Any 'alarm' symptom" if symptom_str == "SS"
	replace symptom_str = "Any blood test" if symptom_str == "BT"

	#delimit ;
	label define scode	 1 "Total consults"
						 
						 3 "Any symptom"
						 4 "Multiple symptoms"
						 
						 6 "Any 'alarm' symptom"
						 7 "Abdominal lump"
						 8 "Change in bowel habit"
						 9 "Breast lump"
						10 "Dysphagia"
						11 "Haematuria"
						12 "Haemoptysis"
						13 "Jaundice"
						14 "PM bleeding"
						15 "Rectal bleeding"
						
						17 "Any 'non-alarm' symptom"
						18 "Abdominal bloating"
						19 "Abdominal pain"
						20 "Constipation"
						21 "Cough"
						22 "Diarrhoea"
						23 "Dyspepsia"
						24 "Dyspnoea"
						25 "Fatigue"
						26 "Night sweats"
						27 "Pelvic pain"
						28 "Nausea / vomiting"
						29 "Weight loss"
						 
						31 "Any blood test"
						32 "Albumin"
						33 "CRP"
						34 "ESR"
						35 "PV"
						36 "Ferritin"
						37 "Haematocrit %"
						38 "Haemoglobin"
						39 "Platelets"
						 , replace
		;
	#delimit cr

	encode symptom_str, gen(scode) label(scode)

	if "`formatrix'" == "" {
		#delimit ;
		label define scode	 1 "{bf:Total consults}"
							  
							 3 "{bf:Any relevant symptom}"
							 
							 6 "{bf:'Alarm' symptoms}"
								
							17 "{bf:'Non-alarm' symptoms}"
							
							31 "{bf:Any blood test}"
							, modify
			;
		#delimit cr
	}
	if "`formatrix'" != "" {
		#delimit ;
		label define scode	 1 "Total consults"
							  
							 3 "Any relevant symptom"
							 
							 6 "Alarm' symptoms"
								
							17 "'Non-alarm' symptoms"
							
							31 "Any blood test"
							, modify
			;
		#delimit cr
	}
	
	if "`country_spec'" == "yes" {
		* sorting for caterpillar plots
		sort rr1
		gen caterpillar = _n if !missing(rr1)

		* indicator for type of symptom/test
		gen byte type = 0
		replace type = 1 if inrange(scode, 16, 22)
		replace type = 2 if inrange(scode, 24, 31)

		label define type 0 "Non-specific" 1 "Specific" 2 "Blood test", replace
		label values type type

		* reshape to long format
		reshape long rr rr@_lb rr@_ub obs exp, i(cancer caterpillar symptom) j(ctry)
		label define ctry 1 "England UKB vs CPRD" 2 "Scotland UKB vs CPRD" 3 "Wales UKB vs CPRD", replace
		label values ctry ctry

		* identify extreme RRs
		gen byte minimal = rr < 0.001
		gen byte maximal = rr > 1/0.001

		* delete minimal/maximal comparisons
		*drop if (minimal) | (maximal)
	}
	
	if "`country_spec'" == "no" {
	
		* flag for signficant results
		gen byte flag = (rr > 1 & rr_lb > 1) | (rr < 1 & rr_ub < 1)

		* sorting for caterpillar plots
		sort rr
		gen caterpillar = _n if !missing(rr)
	
	}
	
end