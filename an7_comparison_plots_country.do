cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison"

/* REMEMBER TO SPECIFY THE CORRECT RESULTS SET */
local results_touse	"2023-01-17"
local todaydate : display %tdCCYY-NN-DD = daily("`c(current_date)'", "DMY")

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
use results/direct_ctry_ukb_cprd_comparisons_summary_symptoms_`results_touse', clear
append using results/direct_ctry_ukb_cprd_comparisons_consults_`results_touse'
append using results/direct_ctry_ukb_cprd_comparisons_symptoms_tests_`results_touse'

graph_data_processing, country_spec(yes)

label define ctry 1 "UKB - English centres" 2 "UKB - Scottish centres" 3 "UKB - Welsh centres", replace

save `graph_data'


/******************************************************************************/
/* Summary results table*/
use `graph_data', clear
desc
keep if new_cancer == 0

foreach thing in rr rr_lb rr_ub {
	* suppress small observed
	replace `thing' = . if obs < 5
	
	* suppress small expected
	replace `thing' = . if exp < 5
}

keep  cancer outcome_group scode ctry rr rr_lb rr_ub
order cancer outcome_group scode ctry rr rr_lb rr_ub
sort  cancer outcome_group scode ctry

decode scode, gen(scode2)
replace scode2 = subinstr(scode2, "{bf:", "", .)
replace scode2 = subinstr(scode2, "}", "", .)
order cancer outcome_group scode scode2 ctry rr rr_lb rr_ub

tostring rr_lb rr_ub, gen(str_rr_lb str_rr_ub) format(%03.2f) force

gen rr_ci = "(" + str_rr_lb + ", " + str_rr_ub + ")"

tostring rr, replace format(%03.2f) force
replace rr_ci = "" if missing(rr) | rr == "."
replace rr    = "" if missing(rr) | rr == "."

keep cancer outcome_group scode2 ctry rr rr_ci
list in 1/10
label var cancer "Cancer site"
label var ctry "Country"
label var outcome_group "Feature type"
label var scode "Feature"
label var rr "Rate ratio, CPRD vs UK Biobank"
label var rr_ci "(95% CI)"

replace rr = "Suppressed, small numbers" if rr == ""

export excel using results/all_ctry_comparisons_table_`todaydate'.xlsx, sheet(raw) sheetreplace firstrow(varl)



/******************************************************************************/
/* Caterpillar plots by cancer site */
use `graph_data', clear

foreach site in /*`cancers'*/ 0 {
	
	use `graph_data', clear
	
	foreach thing in rr rr_lb rr_ub {
		* suppress small observed
		replace `thing' = . if obs < 5
		
		* suppress small expected
		replace `thing' = . if exp < 5
	}
	
	local plotname : label new_cancer `site'
	
	keep if new_cancer == `site' & !missing(rr)
	
	egen min_scode = min(scode), by(outcome_group)
	gen nmin_scode = scode != min_scode
	sort ctry outcome_group nmin_scode rr
	by ctry: gen caterpillar2 = _n+outcome_group
	
	gen sort_order = ctry != 1 /* Not England, so England goes first */
	sort scode sort_order
	by scode: replace caterpillar2 = caterpillar2[1]
	drop sort_order
	sort ctry outcome_group caterpillar2
	
	qui summ caterpillar2
	local y_min = r(min)-2
	local y_max = r(max)+2
	
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
			(scatter caterpillar2 rr_ub 		if outcome_group == 1, msymb(none) mlabel(scode) mlabp(3) mlabc(gs0)	mlabsize(tiny) )
			(scatter caterpillar2 rr_ub 		if outcome_group == 2, msymb(none) mlabel(scode) mlabp(3) mlabc(green)	mlabsize(tiny) )
			(scatter caterpillar2 rr_ub			if outcome_group == 3, msymb(none) mlabel(scode) mlabp(3) mlabc(blue)	mlabsize(tiny) )
			(scatter caterpillar2 rr_ub 		if outcome_group == 4, msymb(none) mlabel(scode) mlabp(3) mlabc(purple)	mlabsize(tiny) )
			(scatter caterpillar2 rr_ub			if outcome_group == 5, msymb(none) mlabel(scode) mlabp(3) mlabc(red)	mlabsize(tiny) )
			,	by(
					ctry
					, 	cols(3)
						title("", pos(11))
						b1title("`xtitle'", ring(2) )
						legend(off)
						note("")
						graphregion(margin(r=10))
				)
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
				subtitle(, fcolor(gs0) color(gs16)) 
				xtitle("`xtitle'")
				ysc(r(`y_min' `y_max') reverse)
				text(`y_max' `=1/16' "{bf:{&larr} More common in UK Biobank }", place(e) size(vsmall) )
				text(`y_min' 16		 "{bf:More common in CPRD {&rarr}}", place(w) size(vsmall) )
				xsc(log r(`=1/16' 16))
				xlabel(
					0.125 	`"`=ustrunescape("\u215b")'"'
					0.25 	"`=uchar(188)'"
					0.5 	"`=uchar(189)'" 
					1 
					2 
					4 
					8
					, 	angle(h) grid labsize(small)
				)
				xline(1, lcol(gs0) lstyle(refline))
				ylabel(none)
				ytitle("")
		;
	#delimit cr
	graph export plots/caterpillar_by_ctry_`todaydate'.png, width(1000) replace
		
}

