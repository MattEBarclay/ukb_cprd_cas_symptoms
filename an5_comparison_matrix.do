/*
	Idea here is:
		Draw a matrix of CPRD-UKB comparisons
*/

cd "S:\ECHO_IHI_CPRD\Matt\ACED2_SymptomIncidenceComparison"

/* REMEMBER TO SPECIFY THE CORRECT RESULTS SET */

local results_touse	"2023-01-17"
local todaydate : display %tdCCYY-NN-DD = daily("`c(current_date)'", "DMY")

do an6_graph_data_processing.do

/******************************************************************************/
/* Data setup and processing */

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

graph_data_processing, country_spec(no) formatrix

drop flag
gen byte flag = .
replace flag =  2 if rr_lb > 2 				& !missing(rr_lb)
replace flag =  1 if rr_lb > 1 & rr_lb <= 2 & !missing(rr_lb)
replace flag =  0 if rr_lb < 1 & rr_ub > 1 	& !missing(rr_lb) & !missing(rr_ub)
replace flag = -1 if rr_ub < 1 				& !missing(rr_ub)
replace flag = -2 if rr_ub < 0.5 			& !missing(rr_ub)
replace flag = 9 if missing(rr)

label define flag 2 "++" 1 "+" 0 "" -1 "-" -2 "--" 9 "n/a", replace
label values flag flag

tab flag

save `graph_data'


/******************************************************************************/
/* Output a big excel sheet of all the results */
use `graph_data', clear

order new_cancer outcome_group scode rr rr_lb rr_ub
keep  new_cancer outcome_group scode rr rr_lb rr_ub

gen comment = ""
replace comment = "Suppressed, small numbers" if rr == .

summ rr
summ rr_lb
summ rr_ub

format rr rr_lb rr_ub %02.1f
list in 1/10
list if rr_ub > 10 & !missing(rr_ub)

tostring rr_lb rr_ub, gen(str_rr_lb str_rr_ub) format(%03.2f) force

gen rr_ci = "(" + str_rr_lb + ", " + str_rr_ub + ")"

keep  new_cancer outcome_group scode rr rr_ci comment
order new_cancer outcome_group scode rr rr_ci comment

sort new_cancer outcome_group scode

label var new_cancer "Cancer site"
label var outcome_group "Feature type"
label var scode "Feature"
label var rr "Rate ratio, CPRD vs UK Biobank"
label var rr_ci "(95% CI)"
label var comment "Comment"

tostring rr, replace format(%03.2f) force
replace rr_ci = "" if missing(rr) | rr == "."
replace rr    = "" if missing(rr) | rr == "."

replace rr = comment if missing(rr) 
drop comment

export excel using results/all_comparisons_table_`todaydate'.xlsx, sheet(raw) sheetreplace firstrow(varl)


/******************************************************************************/
/* Export comparison matrix to Excel */
use `graph_data', clear

cap frame working_matrix: clear
cap frame drop working_matrix

frame put new_cancer outcome_group scode flag, into(working_matrix)
frame working_matrix {
    reshape wide flag, i(outcome_group scode) j(new_cancer)
	desc
	foreach thing of varlist flag* {
	    replace `thing' = 9 if missing(`thing')
	}
}

qui levelsof new_cancer, local(cancers)
foreach site in `cancers' {
	local cas_name : label (new_cancer) `site'
	frame working_matrix: label var flag`site' "`cas_name'"
}

* order by CPRD incidence counts
frame working_matrix: order outcome_group scode flag0 flag4 flag3 flag1 flag8 flag2 flag9 flag6 flag7 flag10 flag5 flag11
frame working_matrix: desc
frame working_matrix: list
frame working_matrix: export excel using results/comparison_matrix_`todaydate'.xlsx, sheet(raw) sheetreplace firstrow(varl)
