cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison"

/* REMEMBER TO SPECIFY THE CORRECT RESULTS SET */

local results_touse	"2023-01-17"
local todaydate : display %tdCCYY-NN-DD = daily("`c(current_date)'", "DMY")

/* A re-written version to work better */

do an6_graph_data_processing.do

/******************************************************************************/
/* Data setup and processing */
/* Every other section is _just_ plots */

* directories
cap mkdir plots 
cap mkdir plots/symptom_cats
cap mkdir plots/cancer_cats

* graph scheme
set scheme s1color

* data
tempfile graph_data
use results/direct_ukb_cprd_comparisons_summary_symptoms_`results_touse', clear
append using results/direct_ukb_cprd_comparisons_consults_`results_touse'
append using results/direct_ukb_cprd_comparisons_symptoms_tests_`results_touse'

graph_data_processing, country_spec(no)

save `graph_data'


/******************************************************************************/
/* Option set for dotplots of all/all sig results */
#delimit ;
local dot_opts 	xsc(log r(0.125 4) ) 
				ysc(reverse)
				ylabel(1 3(1)4 6(1)15 17(1)29 31(1)39, valuelabel angle(h) labsize(vsmall) tl(0) grid) 
				xline(1) 
				xlabel(
					0.125 	`"`=ustrunescape("\u215b")'"'
					0.25 	"`=uchar(188)'"
					0.5 	"`=uchar(189)'" 
					1 
					2 
					4 
					
					, 	angle(h) nogrid
				)
				xtitle("Rate ratio") 
				ytitle("Outcome") 
				title("") 
				legend(
					order(
						1 "Bladder"
						2 "Breast"
						3 "Colorectal"
						4 "Kidney"
						5 "Lung"
						6 "Melanoma"
						7 "NHL"
						8 "Prostate"
						9 "Upper GI"
						10 "Uterine"
						11 "Other"
						12 "All cancers"
					)
					pos(3)
					cols(1)
					size(vsmall)
				)
				t1title("{bf:{&larr} Less common in UK Biobank}", ring(1) pos(11) place(west) justification(left) size(1.8) )
				t2title("{bf:More common in UK Biobank{&rarr}}", ring(1) pos(1) place(east) justification(right) size(1.8) )
	;
#delimit cr

/******************************************************************************/
/* Lets start putting a document with graphs together */
putdocx clear
putdocx begin
			
				
/******************************************************************************/
/* Dotplot, all results */
use `graph_data', clear

#delimit ;
twoway 	(scatter scode rr if cancer == "Bladder"	, msymb(oh) mcol(red)) 
		(scatter scode rr if cancer == "Breast"		, msymb(o)  mcol(red)) 
		(scatter scode rr if cancer == "Colorectal"	, msymb(oh) mcol(blue)) 
		(scatter scode rr if cancer == "Kidney"		, msymb(o)  mcol(blue)) 
		(scatter scode rr if cancer == "Lung"		, msymb(oh) mcol(gs8)) 
		(scatter scode rr if cancer == "Melanoma"	, msymb(o)  mcol(gs8)) 
		(scatter scode rr if cancer == "NHL"		, msymb(oh) mcol(purple)) 
		(scatter scode rr if cancer == "Prostate"	, msymb(o)  mcol(purple)) 
		(scatter scode rr if cancer == "Upper GI"	, msymb(oh) mcol(green)) 
		(scatter scode rr if cancer == "Uterine"	, msymb(o)  mcol(green)) 
		(scatter scode rr if cancer == "Other"		, msymb(oh) mcol(gs0)) 
		(scatter scode rr if cancer == "All cancers", msymb(d)  mcol(gs0) msize(*1.1)) 
		, 	`dot_opts'
			note("Ages 30-75. Adjusted for age, sex, imd", span) 
			name(dot, replace)
		;
#delimit cr
graph export plots/Overall_DotPlot.png, width(1000) replace

putdocx paragraph
putdocx text ("Appx Figure 1.1. Dotplot of all comparisons. Ratio of recording in UKB vs CPRD for all cancers and 11 individual sites (incl. other).")
putdocx paragraph
putdocx image "plots/Overall_DotPlot.png", width(15.92cm) height(11.57cm) linebreak(2)



/******************************************************************************/
/* Dotplot - significant results only (ci does not cross 1) */

use `graph_data', clear
#delimit ;
twoway 	(scatter scode rr if flag & cancer == "Bladder"		, msymb(oh) mcol(red)) 
		(scatter scode rr if flag & cancer == "Breast"		, msymb(o)  mcol(red)) 
		(scatter scode rr if flag & cancer == "Colorectal"	, msymb(oh) mcol(blue)) 
		(scatter scode rr if flag & cancer == "Kidney"		, msymb(o)  mcol(blue)) 
		(scatter scode rr if flag & cancer == "Lung"		, msymb(oh) mcol(gs8)) 
		(scatter scode rr if flag & cancer == "Melanoma"	, msymb(o)  mcol(gs8)) 
		(scatter scode rr if flag & cancer == "NHL"			, msymb(oh) mcol(purple)) 
		(scatter scode rr if flag & cancer == "Prostate"	, msymb(o)  mcol(purple)) 
		(scatter scode rr if flag & cancer == "Upper GI"	, msymb(oh) mcol(green)) 
		(scatter scode rr if flag & cancer == "Uterine"		, msymb(o)  mcol(green)) 
		(scatter scode rr if flag & cancer == "Other"		, msymb(oh) mcol(gs0)) 
		(scatter scode rr if flag & cancer == "All cancers"	, msymb(dh)  mcol(gs0) msize(*1.1)) 
		, 	`dot_opts'
			note("Ages 30-75. Adjusted for age, sex, imd. Non-significant differences suppressed.", span) 
			name(dot_sig, replace)
		;
#delimit cr
graph export plots/Overall_DotPlot_SigOnly.png, width(1000) replace

putdocx pagebreak
putdocx paragraph
putdocx text ("Appx Figure 1.2. Dotplot of comparisons where CIs do not cross 1. Ratio of recording in UKB vs CPRD for all cancers and 11 individual sites (incl. other).")
putdocx paragraph
putdocx image "plots/Overall_DotPlot_SigOnly.png", width(15.92cm) height(11.57cm) linebreak(2)



/******************************************************************************/
/* Option set for ALL caterpillar plots */
#delimit ;
local cat_opts	xsc(log r(`=1/16' 16))
				xlabel(
					0.125 	`"`=ustrunescape("\u215b")'"'
					0.25 	"`=uchar(188)'"
					0.5 	"`=uchar(189)'" 
					1 
					2 
					4 
					8
				   
					, 	angle(h) grid
				)
				xline(1, lcol(gs0) lstyle(refline))
				ylabel(none)
				ytitle("")
	;
#delimit cr


/******************************************************************************/
/* Caterpillar plots */

/**************************/
/* Version 1, all results */
use `graph_data', clear

drop if missing(rr)

summ caterpillar
local y_min = r(min)
local y_max = r(max)

#delimit ;
twoway 	(scatter caterpillar rr 			if outcome_group == 1, msymb(+) 	mcol(gs0%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 1, horizontal 	lcol(gs0%50) )
		(scatter caterpillar rr				if outcome_group == 2, msymb(+) 	mcol(green%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 2, horizontal 	lcol(green%50) )
		(scatter caterpillar rr			 	if outcome_group == 3, msymb(+) 	mcol(blue%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 3, horizontal 	lcol(blue%50) )
		(scatter caterpillar rr				if outcome_group == 4, msymb(+) 	mcol(purple%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 4, horizontal 	lcol(purple%50) )
		(scatter caterpillar rr			 	if outcome_group == 5, msymb(+) 	mcol(red%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 5, horizontal 	lcol(red%50) )
		,	`cat_opts'
			legend(
				order(
					1 "Consultations"
					3 "Any relevant symptom"
					5 "{char 39}Alarm' symptoms"
					7 "{char 39}Non-alarm' symptoms"
					9 "Any blood test"
				)
				pos(9)
				ring(0)
				cols(1)
			)
			ysc(r(`y_min' `y_max') reverse)
			text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
			text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
			xtitle("Rate ratio, adjusted for age, sex and IMD fifth")
			name(caterpillar, replace)
	;
#delimit cr
graph export plots/overall_caterpillar.png, width(1000) replace

putdocx pagebreak
putdocx paragraph
putdocx text ("Appx Figure 1.3. Caterpillar plot of all UKB-CPRD comparisons.")
putdocx paragraph
putdocx image "plots/overall_caterpillar.png", width(15.92cm) height(11.57cm) linebreak(2)


/****************************************/
/* Version 2A, 'high-level' results only, split by type */
use `graph_data', clear

drop if missing(rr)

keep if inlist(symptom, "bt", "ns", "ss", "symptom0", "mul_symptom", "any_symptom", "consults", "median_consult")
decode scode, gen(marker_label)
replace marker_label = subinstr(marker_label, "{bf:", "", .)
replace marker_label = subinstr(marker_label, "}", "", .)

sort outcome_group scode rr
by outcome_group scode: gen byte ml = _n == 1
by outcome_group scode: gen byte order = _n == 1
replace order = sum(order)
replace caterpillar = _n+order

summ caterpillar
local y_min = r(min)
local y_max = r(max)

#delimit ;
twoway 	(rspike rr_lb rr_ub caterpillar if cancer == "Bladder"		, horizontal lcol(red%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Breast"		, horizontal lcol(red%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Colorectal"	, horizontal lcol(blue%50%50)	) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Kidney"		, horizontal lcol(blue%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Lung"			, horizontal lcol(gs8%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Melanoma"		, horizontal lcol(gs8%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "NHL"			, horizontal lcol(purple%50)	) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Prostate"		, horizontal lcol(purple%50)	) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Upper GI"		, horizontal lcol(green%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Uterine"		, horizontal lcol(green%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "Other"		, horizontal lcol(gs0%50)		) 
		(rspike rr_lb rr_ub caterpillar if cancer == "All cancers"	, horizontal lcol(gs0%50) 		) 
		/**/
		(scatter caterpillar rr if cancer == "Bladder"		, msymb(oh) mcol(red)) 
		(scatter caterpillar rr if cancer == "Breast"		, msymb(o)  mcol(red)) 
		(scatter caterpillar rr if cancer == "Colorectal"	, msymb(oh) mcol(blue)) 
		(scatter caterpillar rr if cancer == "Kidney"		, msymb(o)  mcol(blue)) 
		(scatter caterpillar rr if cancer == "Lung"			, msymb(oh) mcol(gs8)) 
		(scatter caterpillar rr if cancer == "Melanoma"		, msymb(o)  mcol(gs8)) 
		(scatter caterpillar rr if cancer == "NHL"			, msymb(oh) mcol(purple)) 
		(scatter caterpillar rr if cancer == "Prostate"		, msymb(o)  mcol(purple)) 
		(scatter caterpillar rr if cancer == "Upper GI"		, msymb(oh) mcol(green)) 
		(scatter caterpillar rr if cancer == "Uterine"		, msymb(o)  mcol(green)) 
		(scatter caterpillar rr if cancer == "Other"		, msymb(oh) mcol(gs0)) 
		(scatter caterpillar rr if cancer == "All cancers"	, msymb(dh) mcol(gs0) msize(*1.1)) 
		/**/
		(scatter caterpillar rr_ub 			if ml == 1		, msymb(none) 	mlab(marker_label) mlabp(3) mlabc(gs0)    mlabs(vsmall) )
		,	`cat_opts'
			legend(
				order(
					13 "Bladder"
					14 "Breast"
					15 "Colorectal"
					16 "Kidney"
					17 "Lung"
					18 "Melanoma"
					19 "NHL"
					20 "Prostate"
					21 "Upper GI"
					22 "Uterine"
					23 "Other"
					24 "All cancers"
				)
				pos(11)
				cols(1)
				size(vsmall)
				ring(0)
			)
			ysc(r(`y_min' `y_max') reverse)
			text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
			text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
			xtitle("Rate ratio, adjusted for age, sex and IMD fifth")
			name(caterpillar, replace)
	;
#delimit cr

graph export plots/overall_summary_caterpillar_alt.png, width(1000) replace

putdocx pagebreak
putdocx paragraph
putdocx text ("Appx Figure 1.4. Caterpillar plot of all summary-level UKB-CPRD comparisons.")
putdocx paragraph
putdocx image "plots/overall_summary_caterpillar_alt.png", width(15.92cm) height(11.57cm) linebreak(2)


/***************************************/
/* Version 3, 'low-level' results only */
use `graph_data', clear

drop if missing(rr)

keep if !inlist(symptom, "bt", "ns", "ss", "symptom0", "mul_symptom", "any_symptom", "consults", "median_consult")
decode scode, gen(marker_label)
replace marker_label = subinstr(marker_label, "{bf:", "", .)
replace marker_label = subinstr(marker_label, "}", "", .)

sort outcome_group rr
by outcome_group: gen byte ml = _n == 1
by outcome_group: gen byte order = _n == 1
replace order = sum(order)
replace caterpillar = _n+order

summ caterpillar
local y_min = r(min)
local y_max = r(max)

#delimit ;
twoway 	(scatter caterpillar rr 			if outcome_group == 1, msymb(+) 	mcol(gs0%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 1, horizontal 	lcol(gs0%50) )
		(scatter caterpillar rr				if outcome_group == 2, msymb(+) 	mcol(green%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 2, horizontal 	lcol(green%50) )
		(scatter caterpillar rr			 	if outcome_group == 3, msymb(+) 	mcol(blue%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 3, horizontal 	lcol(blue%50) )
		(scatter caterpillar rr				if outcome_group == 4, msymb(+) 	mcol(purple%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 4, horizontal 	lcol(purple%50) )
		(scatter caterpillar rr			 	if outcome_group == 5, msymb(+) 	mcol(red%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 5, horizontal 	lcol(red%50) )
		,	`cat_opts'
			legend(
				order(
					5 "{char 39}Alarm' symptoms"
					7 "{char 39}Non-alarm' symptoms"
					9 "Blood tests"
				)
				pos(1)
				ring(1)
				cols(3)
			)
			ysc(r(`y_min' `y_max') reverse)
			text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
			text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
			xtitle("Rate ratio, adjusted for age, sex and IMD fifth")
			name(caterpillar, replace)
	;
#delimit cr
graph export plots/overall_individual_caterpillar.png, width(1000) replace


#delimit ;
twoway 	(scatter caterpillar rr 			if outcome_group == 3, msymb(+) 	mcol(blue%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 3, horizontal 	lcol(blue%50) )
		(scatter caterpillar rr 			if outcome_group == 4, msymb(+) 	mcol(purple%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 4, horizontal 	lcol(purple%50) )
		(scatter caterpillar rr 			if outcome_group == 5, msymb(+) 	mcol(red%50) ) 
		(rspike  rr_lb rr_ub caterpillar	if outcome_group == 5, horizontal 	lcol(red%50) )
		/**/
		(scatter caterpillar rr_ub 			if outcome_group == 3	& ml == 1, msymb(none) 	mlab(outcome_group) mlabp(3) mlabc(blue)   mlabs(vsmall) )
		(scatter caterpillar rr_ub 			if outcome_group == 4	& ml == 1, msymb(none) 	mlab(outcome_group) mlabp(3) mlabc(purple) mlabs(vsmall) ) 
		(scatter caterpillar rr_ub 			if outcome_group == 5	& ml == 1, msymb(none) 	mlab(outcome_group) mlabp(3) mlabc(red)    mlabs(vsmall) )
		,	`cat_opts'
			legend(
				off
			)
			ysc(r(`y_min' `y_max') reverse)
			text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
			text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
			xtitle("Rate ratio, adjusted for age, sex and IMD fifth")
			name(caterpillar, replace)
	;
#delimit cr

graph export plots/overall_individual_caterpillar_alt.png, width(1000) replace

putdocx pagebreak
putdocx paragraph
putdocx text ("Appx Figure 1.5. Caterpillar plot of all individual UKB-CPRD comparisons.")
putdocx paragraph
putdocx image "plots/overall_individual_caterpillar_alt.png", width(15.92cm) height(11.57cm) linebreak(2)


/******************************************************************************/
/* Caterpillar plots by symptom/test */
local figure_group = 1

forval outcome_group = 1/5 {
	local ++figure_group
	
	use `graph_data', clear

	qui levelsof scode if outcome_group == `outcome_group', local(symptoms_tests)
	
	local figure_n = 0
	
	foreach event in `symptoms_tests' {
		local ++figure_n
		
		use `graph_data', clear

		local symptom_str : label scode `event'
		local plotname = subinstr("`symptom_str'", " "   , "_", .)
		local plotname = subinstr("`plotname'"   , "{bf:", "" , .)
		local plotname = subinstr("`plotname'"   , "}"   , "" , .)
		local plotname = subinstr("`plotname'"   , "'"   , "" , .)
		local plotname = subinstr("`plotname'"   ,"_/_"  , "_", .)
		local plotname = lower("`plotname'")
		
		keep if scode == `event' & !missing(rr)
		sort rr
		gen caterpillar2 = _n
			
		qui summ caterpillar2
		local y_min = r(min)-1
		local y_max = r(max)+1
		
		* everything is a rate ratio now
		local xtitle = "Rate ratio, adjusted for age, sex and IMD fifth"
		
		if  inlist("`symptom_str'", "First symptom consult", "Median consult") {
			#delimit ;
			twoway 	(scatter caterpillar2 rr 			, msymb(+) 		mcol(gs0) ) 
					(rspike  rr_lb rr_ub caterpillar2	, horizontal 	lcol(gs0) )
					(scatter caterpillar2 rr_ub, msymb(none) mlabel(cancer) mlabp(3) mlabc(gs0))
					,	`cat_opts'
						legend(off)
						title("", pos(11))
						xtitle("`xtitle'")
						ysc(r(`y_min' `y_max') reverse)
						text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
						text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
						/*name(symptom_`plotname', replace)*/
				;
			#delimit cr
		}
		if !inlist("`symptom_str'", "First symptom consult", "Median consult") {
			#delimit ;
			twoway 	(scatter caterpillar2 rr 			, msymb(+) 		mcol(gs0) ) 
					(rspike  rr_lb rr_ub caterpillar2	, horizontal 	lcol(gs0) )
					(scatter caterpillar2 rr_ub, msymb(none) mlabel(cancer) mlabp(3) mlabc(gs0))
					,	`cat_opts'
						legend(off)
						title("", pos(11))
						xtitle("`xtitle'")
						ysc(r(`y_min' `y_max') reverse)
						text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
						text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
						/*name(symptom_`plotname', replace)*/
				;
			#delimit cr
		}
		graph export plots/symptom_cats/caterpillar_`outcome_group'_`event'_`plotname'.png, width(1000) replace
		
				
		putdocx pagebreak
		putdocx paragraph
		putdocx text ("Appx Figure `figure_group'.`figure_n'. `symptom_str' UKB vs CPRD comparisons by cancer site.")
		putdocx paragraph
		putdocx image "plots/symptom_cats/caterpillar_`outcome_group'_`event'_`plotname'.png", width(15.92cm) height(11.57cm) linebreak(2)
		
	}

}


/******************************************************************************/
/* Caterpillar plots by cancer site */
use `graph_data', clear

qui levelsof new_cancer, local(cancers)

local ++figure_group
local figure_n 0

set trace off
set tracedepth 1

foreach site in `cancers' {
	local ++figure_n
	
	use `graph_data', clear
	
	local plotname : label new_cancer `site'
	
	keep if new_cancer == `site' & !missing(rr)
	
	count
	
	egen min_scode = min(scode), by(outcome_group)
	gen nmin_scode = scode != min_scode
	sort outcome_group nmin_scode rr
	gen caterpillar2 = _n+outcome_group
	
	qui summ caterpillar2
	local y_min = r(min)-1
	local y_max = r(max)+1
	
	if `site' == 0 {
		local xtitle "Rate ratio, adjusted for cancer site, age, sex and IMD fifth"
	}
	if `site' != 0 {
		local xtitle "Rate ratio, adjusted for age, sex and IMD fifth"
	}
	
	
	#delimit ;
	twoway 	(scatter caterpillar2 rr 			if outcome_group == 1, msymb(+) 	mcol(gs0%50) ) 
			(rspike  rr_lb rr_ub caterpillar2	if outcome_group == 1, horizontal 	lcol(gs0%50) )
			(scatter caterpillar2 rr			if outcome_group == 2, msymb(+) 	mcol(green%50) ) 
			(rspike  rr_lb rr_ub caterpillar2	if outcome_group == 2, horizontal 	lcol(green%50) )
			(scatter caterpillar2 rr		 	if outcome_group == 3, msymb(+) 	mcol(blue%50) ) 
			(rspike  rr_lb rr_ub caterpillar2	if outcome_group == 3, horizontal 	lcol(blue%50) )
			(scatter caterpillar2 rr			if outcome_group == 4, msymb(+) 	mcol(purple%50) ) 
			(rspike  rr_lb rr_ub caterpillar2	if outcome_group == 4, horizontal 	lcol(purple%50) )
			(scatter caterpillar2 rr		 	if outcome_group == 5, msymb(+) 	mcol(red%50) ) 
			(rspike  rr_lb rr_ub caterpillar2	if outcome_group == 5, horizontal 	lcol(red%50) )
			(scatter caterpillar2 rr_ub 		if outcome_group == 1, msymb(none) mlabel(scode) mlabp(3) mlabc(gs0)	mlabsize(vsmall) )
			(scatter caterpillar2 rr_ub 		if outcome_group == 2, msymb(none) mlabel(scode) mlabp(3) mlabc(green)	mlabsize(vsmall) )
			(scatter caterpillar2 rr_ub			if outcome_group == 3, msymb(none) mlabel(scode) mlabp(3) mlabc(blue)	mlabsize(vsmall) )
			(scatter caterpillar2 rr_ub 		if outcome_group == 4, msymb(none) mlabel(scode) mlabp(3) mlabc(purple)	mlabsize(vsmall) )
			(scatter caterpillar2 rr_ub			if outcome_group == 5, msymb(none) mlabel(scode) mlabp(3) mlabc(red)	mlabsize(vsmall) )
			,	`cat_opts'
				legend(
					order(
						1 "Consultations"
						3 "Any relevant symptom"
						5 "{char 39}Alarm' symptoms"
						7 "{char 39}Non-alarm' symptoms"
						9 "Blood tests"
					)
					pos(1)
					ring(1)
					cols(3)
					size(vsmall)
					region(lstyle(none))
				)
				title("", pos(11) ring(1))
				xtitle("`xtitle'")
				ysc(r(`y_min' `y_max') reverse)					
				text(`y_max' `=1/16' "{bf:{&larr} Less common in UK Biobank }", place(e) size(1.8) )
				text(`y_min' 16		 "{bf:More common in UK Biobank {&rarr}}" , place(w) size(1.8) )
				/*name(symptom_`plotname', replace)*/
		;
	#delimit cr
	graph export plots/cancer_cats/caterpillar_`site'.png, width(1000) replace
	
	putdocx pagebreak
	putdocx paragraph
	putdocx text ("Appx Figure `figure_group'.`figure_n'. UKB vs CPRD comparisons for `plotname'")
	putdocx paragraph
	putdocx image "plots/cancer_cats/caterpillar_`site'.png", width(15.92cm) height(11.57cm) linebreak(2)

}

putdocx save results/All_Results_Plots_`todaydate'.docx, replace


