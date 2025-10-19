/**********************************************************************
  Project: Coastline, Cooperation & Preferences (CCP)
  Author:  Shashvathi S Hariharan
  Purpose: Generate key treatment/covariates; run balance + outcome models
  Notes:   Data not included (privacy). Replace "use <file>" with your path.
***********************************************************************/

version 18
clear all
set more off

*--------------------------------*
* 0) Load data
*--------------------------------*
* use "path/to/your_data.dta", clear

*--------------------------------*
* 1) Housekeeping
*--------------------------------*
* replace dist_coastline = strtrim(dist_coastline)

*--------------------------------*
* 2) Treatments & covariates
*--------------------------------*
gen byte treatment = (prime_fisheries_1 < .)

gen byte coastline = (dist_coastline == "Less than 5 kms away ")
label var coastline "Residence <5km from coastline"

gen byte rp   = (pref_risk_1 > 5)     // risk pref (high)
gen byte rp_h = (pref_risk_1 > 7)     // very high

gen byte tp   = (pref_trust_2 > 5)    // trust proxy
gen byte tp_h = inlist(pref_trust_2, 8, 9, 10)

gen byte loss_d        = (shock_loss == 1)
gen byte coast_fd      = (coastal_father == 1)
gen byte personal_compd= (personal_comp != "No ")
gen byte home_rurald   = (home_urban == 2)
gen byte home_livingd  = (home_living == 1)
gen byte shock_year    = inlist(shock_time, 1, 2)
gen byte generation_d  = (generations == "More than 3 generations of my family have resided here ")
gen byte self_employed_d = (occupation_pearner == 2)

label var treatment      "Treatment"
label var rp             "Risk pref (>5)"
label var tp             "Trust pref (>5)"
label var loss_d         "Experienced loss (shock)"
label var coast_fd       "Father born on coast"
label var personal_compd "Owns personal computer"
label var home_rurald    "Rural residence"
label var home_livingd   "Same home since birth"
label var shock_year     "Recent extreme weather (<= last year)"
label var generation_d   "3+ generations in same place"
label var self_employed_d "Self-employed earner"

*--------------------------------*
* 3) Outcomes: cooperation & norms
*--------------------------------*
summ pgg_contribution

corr pgg_contribution coastline

gen byte pgg_contri_high = (pgg_contribution > 50)
label var pgg_contri_high "High contribution (>50)"

*--------------------------------*
* 4) Main regressions (robust SEs)
*--------------------------------*
reg pgg_contribution treatment generation_d coastline tp rp age ///
    coast_fd loss_d personal_compd home_rurald, vce(robust)

reg pgg_contri_high treatment generation_d coastline tp rp age ///
    coast_fd loss_d personal_compd home_rurald, vce(robust)

*--------------------------------*
* 5) Norms outcomes
*--------------------------------*
foreach y in normative_judgement ne_cooperation ee_same_comm ee_diff_comm ///
            sanctions_binary invisible_sanction visible_sanction {
    reg `y' treatment, vce(robust)
    reg `y' treatment coastline tp rp age coast_fd loss_d generation_d ///
        self_employed_d personal_compd home_rurald home_livingd, vce(robust)
}

*--------------------------------*
* 6) Preference balance checks
*--------------------------------*
foreach x in pref_risk_1 pref_trust_5 pref_trust_2 pref_trust_3 pref_trust_4 ///
            pref_altruism present_bias_1_1 present_bias_2_1 present_bias_3_1 {
    reg `x' treatment, vce(robust)
}

*--------------------------------*
* 7) Psychological distance recodes + models
*--------------------------------*
gen byte pd_cc1d = inlist(psych_distance1_1,1,2)
gen byte pd_cc2d = inlist(psych_distance1_2,1,2)
gen byte pd_cc3d = inlist(psych_distance1_3,1,2)
gen byte pd_cc4d = inlist(psych_distance1_4,1,2)

foreach y in pd_cc1d pd_cc2d pd_cc3d pd_cc4d {
    reg `y' treatment, vce(robust)
    reg `y' treatment coastline tp rp age coast_fd loss_d personal_compd ///
        home_rurald home_livingd, vce(robust)
}

gen byte pd_cc5d = inlist(psych_distance2_1,1,2,3)
gen byte pd_cc6d = inlist(psych_distance3_1,1,2)

reg pd_cc5d treatment coastline tp rp age coast_fd loss_d personal_compd ///
    home_rurald home_livingd, vce(robust)
reg pd_cc6d treatment coastline tp rp age coast_fd loss_d personal_compd ///
    home_rurald home_livingd, vce(robust)

gen byte pd_cc7d  = inlist(psych_distance4_1,4,5)
gen byte pd_cc8d  = inlist(psych_distance4_2,4,5)
gen byte pd_cc9d  = inlist(psych_distance4_3,1,2)
gen byte pd_cc10d = inlist(psych_distance4_4,5)

foreach y in pd_cc7d pd_cc8d pd_cc9d pd_cc10d {
    reg `y' treatment, vce(robust)
}

gen byte pd_cc11d = inlist(psych_distance5_1,1,2)
gen byte pd_cc12d = inlist(psych_distance5_2,1,2)
gen byte pd_cc13d = inlist(psych_distance5_3,1,2)
gen byte pd_cc14d = inlist(psych_distance6_1,1,2)

foreach y in pd_cc11d pd_cc12d pd_cc13d pd_cc14d {
    reg `y' treatment, vce(robust)
}

*--------------------------------*
* 8) Example climate concern dummy
*--------------------------------*
gen byte gw_risk_persd = inlist(gwrisk_personally,3,4)
label var gw_risk_persd "Low personal concern (3-4)"

display "CCP analysis completed."
