/*******************************************************************************
 Project: Coastal Climate Perceptions, Cooperation and Preferences
 Author:  [Your Name]
 Purpose: Analysis of coastal proximity, climate perceptions and cooperative behavior
 Created: [Date]
 Notes:   Cleaned and professionalized code for pre-doc application
*******************************************************************************/

version 18
clear all
set more off

*==============================================================================*
* 0. SETUP AND DATA LOADING
*==============================================================================*

* Set working directory and load data
cd "/Users/aayushagarwal/Documents/Stata/1_geopref"
import excel "cleaned_06062024_non_pii.xlsx", sheet("Sheet1") firstrow clear

*==============================================================================*
* 1. VARIABLE CONSTRUCTION
*==============================================================================*

** 1.1 Treatment Variable **
generate treatment = (prime_fisheries_1 != .)
label var treatment "Fisheries prime treatment"

** 1.2 Key Covariates **

* Coastal proximity
generate coastline = (dist_coastline == "Less than 5 kms away ")
label var coastline "Lives <5km from coastline"

* Risk preferences (binary indicators)
generate rp = (pref_risk_1 > 5) if !missing(pref_risk_1)
generate rp_high = (pref_risk_1 > 7) if !missing(pref_risk_1)
label var rp "High risk preference"
label var rp_high "Very high risk preference"

* Trust preferences  
generate tp = (pref_trust_2 > 5) if !missing(pref_trust_2)
generate tp_high = inlist(pref_trust_2, 8, 9, 10) if !missing(pref_trust_2)
label var tp "High trust preference"
label var tp_high "Very high trust preference"

* Climate shock experiences
generate loss_experience = (shock_loss == 1) if !missing(shock_loss)
generate recent_shock = inlist(shock_time, 1, 2) if !missing(shock_time)
label var loss_experience "Experienced asset/life loss from weather"
label var recent_shock "Weather shock in past year"

* Family coastal background
generate father_coastal = (coastal_father == 1) if !missing(coastal_father)
generate mother_coastal = (coastal_mother == 1) if !missing(coastal_mother)
generate grandfather_coastal = (coastal_life_gf == 1) if !missing(coastal_life_gf)
label var father_coastal "Father born in coastal area"
label var mother_coastal "Mother born in coastal area"
label var grandfather_coastal "Grandfather lived near coast"

* Occupational variables
generate occ_weather_impact = (Other_pe == 3 | Other_pe == 4) if !missing(Other_pe)
generate fisheries_occupation = (occup_agri_fish_pe == "2") if !missing(occup_agri_fish_pe)
label var occ_weather_impact "Occupation weather-sensitive"
label var fisheries_occupation "Primary earner in fisheries"

* Demographic controls
generate female = (gender == "Female ") if !missing(gender)
generate rural = (home_urban == 2) if !missing(home_urban)
generate computer_access = (personal_comp != "No ") if !missing(personal_comp)
generate multi_generation = (generations == "More than 3 generations of my family have resided here ") if !missing(generations)
generate self_employed = (occupation_pearner == 2) if !missing(occupation_pearner)
generate low_income = (hh_income == 1) if !missing(hh_income)
generate malayalam = (language == 3) if !missing(language)
generate osc_member = (osc_memberx == 1) if !missing(osc_memberx)

label var female "Female"
label var rural "Rural residence" 
label var computer_access "Computer access"
label var multi_generation "Multi-generational residence"
label var self_employed "Self-employed"
label var low_income "Low income (<5 lakhs)"
label var malayalam "Survey in Malayalam"
label var osc_member "OSC member"

*==============================================================================*
* 2. OUTCOME VARIABLES
*==============================================================================*

** 2.1 Cooperation Outcomes **
generate high_contributor = (pgg_contribution > 50) if !missing(pgg_contribution)
generate max_contributor = (pgg_contribution == 100) if !missing(pgg_contribution)
label var high_contributor "PGG contribution > 50"
label var max_contributor "PGG contribution = 100"

** 2.2 Social Norms Outcomes **
* (Variables already in dataset: normative_judgement, ne_cooperation, etc.)

** 2.3 Psychological Distance Variables **
local psych_vars psych_distance1_1 psych_distance1_2 psych_distance1_3 psych_distance1_4

foreach i in 1 2 3 4 {
    capture confirm variable psych_distance1_`i'
    if _rc == 0 {
        generate pd_local_`i' = inlist(psych_distance1_`i', 1, 2) if !missing(psych_distance1_`i')
        label var pd_local_`i' "Psych distance dimension `i'"
    }
}

*==============================================================================*
* 3. DESCRIPTIVE STATISTICS AND BALANCE CHECKS
*==============================================================================*

** 3.1 Treatment Assignment **
tab treatment
tab treatment, su(pgg_contribution)

** 3.2 Balance Tests **
local balance_vars age female rp tp coastline father_coastal loss_experience ///
                  rural computer_access multi_generation self_employed low_income

foreach var of local balance_vars {
    di "Balance test: `var'"
    reg `var' treatment, vce(robust)
}

*==============================================================================*
* 4. MAIN REGRESSION ANALYSES
*==============================================================================*

** 4.1 Primary Cooperation Results **

* Baseline specification
regress pgg_contribution treatment multi_generation coastline tp rp age ///
    father_coastal loss_experience computer_access rural, vce(robust)

* Extended controls
regress pgg_contribution treatment multi_generation coastline tp rp age ///
    father_coastal loss_experience computer_access rural female recent_shock ///
    mother_coastal grandfather_coastal occ_weather_impact fisheries_occupation ///
    malayalam low_income osc_member, vce(robust)

* Binary outcomes
regress high_contributor treatment multi_generation coastline tp rp age ///
    father_coastal loss_experience computer_access rural, vce(robust)

regress max_contributor treatment multi_generation coastline tp rp age ///
    father_coastal loss_experience computer_access rural, vce(robust)

** 4.2 Treatment Heterogeneity by Coastal Proximity **
regress pgg_contribution i.treatment##i.coastline multi_generation tp rp age ///
    father_coastal loss_experience computer_access rural, vce(robust)

margins coastline, dydx(treatment)
marginsplot, title("Treatment Effect by Coastal Proximity") ///
    ytitle("Average Treatment Effect") xtitle("Coastal Residence")

** 4.3 Social Norms Outcomes **
local norms_outcomes normative_judgement ne_cooperation ee_same_comm ee_diff_comm ///
                     sanctions_binary invisible_sanction visible_sanction

foreach outcome of local norms_outcomes {
    capture confirm variable `outcome'
    if _rc == 0 {
        di "Estimating: `outcome'"
        regress `outcome' treatment coastline tp rp age female father_coastal ///
            loss_experience multi_generation self_employed computer_access rural, vce(robust)
    }
}

** 4.4 Psychological Distance Outcomes **
forvalues i = 1/4 {
    capture confirm variable pd_local_`i'
    if _rc == 0 {
        di "Psychological Distance Dimension `i'"
        regress pd_local_`i' treatment coastline tp rp age father_coastal ///
            loss_experience computer_access rural, vce(robust)
    }
}

*==============================================================================*
* 5. ROBUSTNESS CHECKS
*==============================================================================*

** 5.1 Alternative Specifications **
foreach threshold in 40 60 70 {
    generate high_contributor_`threshold' = (pgg_contribution > `threshold') if !missing(pgg_contribution)
    regress high_contributor_`threshold' treatment multi_generation coastline tp rp age ///
        father_coastal loss_experience computer_access rural, vce(robust)
}

** 5.2 Placebo Tests **
regress father_coastal treatment coastline tp rp age multi_generation loss_experience, vce(robust)

*==============================================================================*
* 6. ADDITIONAL ANALYSES
*==============================================================================*

** 6.1 Climate Risk Perceptions **
capture confirm variable gwrisk_personally
if _rc == 0 {
    generate low_personal_concern = inlist(gwrisk_personally, 3, 4) if !missing(gwrisk_personally)
    regress low_personal_concern treatment coastline tp rp age female father_coastal ///
        loss_experience computer_access rural, vce(robust)
}

** 6.2 Life Preferences **
capture confirm variable pref_marriage
if _rc == 0 {
    generate plan_marriage = (pref_marriage == 1) if !missing(pref_marriage)
    generate plan_children = (pref_children == 1) if !missing(pref_children)
    
    regress plan_marriage treatment, vce(robust)
    regress plan_children treatment, vce(robust)
}

*==============================================================================*
* 7. OUTPUT AND VISUALIZATION
*==============================================================================*

** 7.1 Key Relationships **
corr pgg_contribution coastline

** 7.2 Distribution Plots **
twoway (kdensity pgg_contribution if treatment == 0) ///
       (kdensity pgg_contribution if treatment == 1), ///
       legend(order(1 "Control" 2 "Treatment")) ///
       title("PGG Contributions by Treatment") ///
       xtitle("PGG Contribution") ytitle("Density")

graph box pgg_contribution, over(coastline) ///
    title("PGG Contributions by Coastal Proximity") ///
    ytitle("PGG Contribution")

*==============================================================================*
* 8. SESSION COMPLETION
*==============================================================================*

display "Analysis completed: `c(current_date)' at `c(current_time)'"
describe treatment coastline pgg_contribution high_contributor
summarize treatment coastline pgg_contribution high_contributor
