/**********************************************************************
  Project : Coastline, Cooperation & Preferences (CCP)
  Author  : Shashvathi S. Hariharan
  Purpose : Construct vars, run balance + main specs, norms/psych distance,
            robustness, and visuals. Data not included.
  Notes   : Replace the `use` line with your path. Results dirs optional.
***********************************************************************/

version 18
clear all
set more off
set seed 20251022

*----------------------------*
* 0) Setup (paths, logging)
*----------------------------*
local OUT "results"
local FIG "visuals"
cap mkdir "`OUT'"
cap mkdir "`FIG'"
cap log close
log using "`OUT'/ccp_analysis.smcl", replace

*----------------------------*
* 1) Load + hygiene
*----------------------------*
* use "path/to/your_data.dta", clear

* inspect raw coastline field
cap noisily tab dist_coastline, missing

* trim strings safely
capture confirm string variable dist_coastline
if !_rc {
    replace dist_coastline = strtrim(itrim(dist_coastline))
}

* quick missingness snapshot on key vars
misstable summarize ///
    pgg_contribution prime_fisheries_1 dist_coastline pref_risk_1 pref_trust_2 age ///
    shock_loss coastal_father personal_comp home_urban home_living shock_time ///
    generations occupation_pearner

* basic sanity (non-fatal)
capture assert inrange(pgg_contribution,0,100) if !missing(pgg_contribution)
capture assert inrange(age,15,100) if !missing(age)

*-----------------------------------------*
* 2) Treatment + covariates (clean build)
*-----------------------------------------*
gen byte treat = (prime_fisheries_1 < .)
label var treat "Treatment (prime shown)"

* Coastline categories (3 bins) + binary (<=5km)
gen byte coastline = .
replace coastline = 0 if !missing(dist_coastline) & strpos(dist_coastline,"Less than 5")
replace coastline = 1 if !missing(dist_coastline) & strpos(dist_coastline,"5-20")
replace coastline = 2 if !missing(dist_coastline) & strpos(dist_coastline,"More than 20")
label define coastlbl 0 "Less than 5 kms" 1 "5–20 kms" 2 "More than 20 kms"
label values coastline coastlbl
label var coastline "Distance from coastline (categorical)"
gen byte coast5 = (coastline==0) if !missing(coastline)
label var coast5 "Residence <5km from coastline (binary)"

* prefs / demographics / experience (guard for missing)
gen byte rp    = (pref_risk_1  > 5) if !missing(pref_risk_1)
gen byte rp_h  = (pref_risk_1  > 7) if !missing(pref_risk_1)
gen byte tp    = (pref_trust_2 > 5) if !missing(pref_trust_2)
gen byte tp_h  = inlist(pref_trust_2,8,9,10) if !missing(pref_trust_2)

gen byte loss_d         = (shock_loss==1)             if !missing(shock_loss)
gen byte coast_fd       = (coastal_father==1)         if !missing(coastal_father)
gen byte personal_compd = (personal_comp!="No")       if !missing(personal_comp)
gen byte home_rurald    = (home_urban==2)             if !missing(home_urban)
gen byte home_livingd   = (home_living==1)            if !missing(home_living)
gen byte shock_year     = inlist(shock_time,1,2)      if !missing(shock_time)
gen byte generation_d   = (generations=="More than 3 generations of my family have resided here") ///
                         if !missing(generations)
gen byte self_employed_d= (occupation_pearner==2)     if !missing(occupation_pearner)

label var rp               "Risk pref (>5)"
label var tp               "Trust pref (>5)"
label var loss_d           "Experienced climate-related loss"
label var coast_fd         "Father born on coast"
label var personal_compd   "Owns personal computer"
label var home_rurald      "Rural residence"
label var home_livingd     "Same home since birth"
label var shock_year       "Extreme weather in last year"
label var generation_d     "3+ generations in same place"
label var self_employed_d  "Self-employed earner"

* outcomes
summ pgg_contribution, detail
gen byte pgg_contri_high = (pgg_contribution>50) if !missing(pgg_contribution)
label var pgg_contri_high "High contribution (>50)"

* quick corr (sanity)
capture noisily corr pgg_contribution coast5

*-----------------------------------------*
* 3) Randomization doc + balance
*-----------------------------------------*
tab prime_fisheries_1, missing
tab treat, missing

tabstat age rp tp coast5 generation_d loss_d coast_fd self_employed_d home_rurald, ///
    by(treat) stat(mean sd n)

foreach v in age rp tp coast5 generation_d loss_d coast_fd self_employed_d home_rurald {
    quietly reg `v' treat, vce(robust)
    di as res "Balance: `v' on treat  |  b=" %6.3f _b[treat] "  p=" %6.3f _p[treat]
}

*-----------------------------------------*
* 4) Main specs (robust) + heterogeneity
*-----------------------------------------*
* (A) continuous outcome
reg pgg_contribution treat generation_d coast5 tp rp age ///
    coast_fd loss_d personal_compd home_rurald, vce(robust)

* (B) heterogeneity: treatment x coast5
reg pgg_contribution i.treat##i.coast5 c.tp c.rp c.age ///
    i.generation_d i.coast_fd i.loss_d i.personal_compd i.home_rurald, vce(robust)
margins coast5, dydx(treat)
marginsplot, title("Treatment effect on cooperation by coastal proximity (<5km)") ///
    name(mp1, replace)
* graph export "`FIG'/margins_treat_by_coast5.png", width(1600) replace

* (C) binary outcome: LPM vs logit + AMEs
reg   pgg_contri_high i.treat##i.coast5 c.tp c.rp c.age ///
      i.generation_d i.coast_fd i.loss_d i.personal_compd i.home_rurald, vce(robust)
logit pgg_contri_high i.treat##i.coast5 c.tp c.rp c.age ///
      i.generation_d i.coast_fd i.loss_d i.personal_compd i.home_rurald, vce(robust)
margins, dydx(treat) at(coast5=(0 1))
marginsplot, title("AME of treatment on High Contribution (>50)") name(mp2, replace)
* graph export "`FIG'/margins_treat_highcontrib.png", width(1600) replace

*-----------------------------------------*
* 5) Norms outcomes (loop) + Bonferroni
*-----------------------------------------*
local norms normative_judgement ne_cooperation ee_same_comm ee_diff_comm ///
            sanctions_binary invisible_sanction visible_sanction

* drop missing vars from the list, gracefully
local keepnorms ""
foreach y of local norms {
    capture confirm variable `y'
    if !_rc local keepnorms "`keepnorms' `y'"
    else di as txt "Note: `y' not found; skipping."
}

tempname H
postfile H str24 outcome float b se p using "`OUT'/norms_results.dta", replace
foreach y of local keepnorms {
    quietly reg `y' i.treat c.tp c.rp c.age i.coast5 i.generation_d i.coast_fd i.loss_d ///
        i.self_employed_d i.personal_compd i.home_rurald i.home_livingd, vce(robust)
    matrix T = r(table)
    post H ("`y'") (T[1,1]) (T[2,1]) (T[4,1])   // treat: coef, se, p
}
postclose H
capture noisily {
    use "`OUT'/norms_results.dta", clear
    gen p_bonf = min(p*_N,1)
    order outcome b se p p_bonf
    export delimited using "`OUT'/norms_results.csv", replace
}

*-----------------------------------------*
* 6) Psychological distance (build + run)
*-----------------------------------------*
* build dummies only if source items exist
forvalues i = 1/4 {
    capture confirm variable psych_distance1_`i'
    if !_rc gen byte pd_cc`i'd = inlist(psych_distance1_`i',1,2) if !missing(psych_distance1_`i')
}
capture confirm variable psych_distance2_1
if !_rc gen byte pd_cc5d = inlist(psych_distance2_1,1,2,3) if !missing(psych_distance2_1)

capture confirm variable psych_distance3_1
if !_rc gen byte pd_cc6d = inlist(psych_distance3_1,1,2) if !missing(psych_distance3_1)

forvalues i = 1/4 {
    capture confirm variable psych_distance4_`i'
    if !_rc {
        local j = `i' + 6
        if inlist(`i',1,2) gen byte pd_cc`j'd = inlist(psych_distance4_`i',4,5) if !missing(psych_distance4_`i')
        if `i'==3      gen byte pd_cc`j'd = inlist(psych_distance4_`i',1,2) if !missing(psych_distance4_`i')
        if `i'==4      gen byte pd_cc`j'd = inlist(psych_distance4_`i',5)   if !missing(psych_distance4_`i')
    }
}
forvalues i = 1/3 {
    capture confirm variable psych_distance5_`i'
    if !_rc {
        local j = `i' + 10
        gen byte pd_cc`j'd = inlist(psych_distance5_`i',1,2) if !missing(psych_distance5_`i')
    }
}
capture confirm variable psych_distance6_1
if !_rc gen byte pd_cc14d = inlist(psych_distance6_1,1,2) if !missing(psych_distance6_1)

* run models compactly
tempname P
postfile P str12 outcome float b se p using "`OUT'/pdist_results.dta", replace
forvalues k = 1/14 {
    capture confirm variable pd_cc`k'd
    if !_rc {
        quietly reg pd_cc`k'd treat, vce(robust)
        quietly reg pd_cc`k'd treat coast5 tp rp age coast_fd loss_d ///
            personal_compd home_rurald home_livingd, vce(robust)
        matrix T = r(table)
        post P ("pd_cc`k'd") (T[1,1]) (T[2,1]) (T[4,1])
    }
}
postclose P
capture noisily export delimited using "`OUT'/pdist_results.csv", replace

*-----------------------------------------*
* 7) Climate concern (optional)
*-----------------------------------------*
capture confirm variable gwrisk_personally
if !_rc {
    gen byte gw_risk_persd = inlist(gwrisk_personally,3,4) if !missing(gwrisk_personally)
    label var gw_risk_persd "Low personal concern (3–4)"
}

*-----------------------------------------*
* 8) Robustness (placebo + thresholds)
*-----------------------------------------*
* placebo outcome that shouldn't move with treat
reg coast_fd i.treat i.coast5 c.tp c.rp c.age i.generation_d i.loss_d, vce(robust)

* alternate cutoffs for "high contribution"
foreach thr in 40 60 70 {
    gen byte high_`thr' = (pgg_contribution>`thr') if !missing(pgg_contribution)
    logit high_`thr' i.treat##i.coast5 c.tp c.rp c.age ///
         i.generation_d i.coast_fd i.loss_d i.personal_compd i.home_rurald, vce(robust)
    margins, dydx(treat) at(coast5=(0 1))
}

*-----------------------------------------*
* 9) Quick visuals (portable)
*-----------------------------------------*
twoway (kdensity pgg_contribution if treat==0) ///
       (kdensity pgg_contribution if treat==1), ///
       legend(order(1 "Control" 2 "Treatment")) ///
       title("Distribution of cooperation by treatment")
* graph export "`FIG'/kde_pgg_by_treat.png", width(1600) replace

graph box pgg_contribution, over(coast5) ///
    title("Cooperation by coastal proximity (<5km)")
* graph export "`FIG'/box_pgg_by_coast5.png", width(1600) replace

*-----------------------------------------*
* 10) Wrap
*-----------------------------------------*
di as txt "CCP analysis completed. Results in `OUT', figures in `FIG'."
log close
