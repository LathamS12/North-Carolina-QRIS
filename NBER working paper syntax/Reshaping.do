/************************************************************
* Author: Scott Latham
* Purpose: Reshaping and generating variables for NC QRIS
*
* Date created: 	5/4/2015
* Last modified:	8/2/2017
*************************************************************/		

	clear
	clear matrix
	clear mata
	
	set maxvar 32000
	
	pause on 
	use "${path}\Generated datasets\Full dataset long", clear		

	rename * *_ //To allow for adding a suffix
	rename (id_ county_) (id county) 
	
	order id year county zip p_pov p_black p_hisp med_income
	loc vars "fname-cprog_score"
	loc vars_reshaped ""
	
	// Reshape the data wide to the center level
	***********************************************
	
		//Save variable labels before reshaping
			foreach x of varlist `vars'	{	
				forvalues i =2007/2014		{
					loc L_`x'`i': variable label `x'
					loc vars_reshaped "`vars_reshaped' `x'" //add to list of reshaped variables				
					
				}
			} //close x loop

		reshape wide `vars', i(id) j(year)

		//Re-apply variable labels post reshape
			foreach x in `vars_reshaped'	{
				forvalues i = 2007/2014	{		
					label var `x'`i' "`L_`x'`i'' in year `i'"
				}
			}
		
		rename *_ *
	
		//Save a copy of FCCH variables for Justin
			preserve
				keep id FCC*
				saveold "${path}\Generated datasets\For Justin", replace version(13)
			restore
	
	// Collapsing variables that are constant across years (e.g. county, facility name, age range)
	**********************************************************************************************
	
		//Family care vs. center care
			egen family_care = rowmean(family_care*) 
			drop family_care_*
		
		//Public v. private
			egen public = rowmean(public*)
			replace public = . if public !=1 & public!=0
			label var public "Local public school or Head Start
				drop public_*
				
				
		//Strings
			foreach x in fname agerange	{	
				gen `x' = ""
				forvalues i = 2007/2014	{
					replace `x' = `x'_`i' if `x' == ""
				}
			}
			
		//Ints
			foreach x in ftype	{	
				gen `x' = .
				forvalues i = 2007/2014	{
					replace `x' = `x'_`i' if `x' == .
				}
			}
		
		label var fname "Facility name"
		label var ftype "Facility type"
		label var agerange "Age range"

		drop fname_* agerange_*
	
	
	//Location, other nearby providers
	*********************************
		egen lon = rowmin(X_*)
		egen lat = rowmin(Y_*)
		
		drop X_* Y_*
			
		//For now, drop family care centers
			drop if family_care ==1
		
		//Using Haversine formula to calculate "great circle" distances
			loc N = _N
			loc earth_radius = 3960
			loc P = _pi / 180 //Used multiple times to calculate distance

			gen LAT_P = (90-lat) * `P' //This value is constant for each center
			
			forvalues i = 1/`N'	{
			
				loc LAT_`i'_P   = (90-lat[`i']) * `P' 		//Constant across centers, can save as local rather than variable
				gen delta_LON`i'_P = (lon[`i']-lon) * `P' 	//Difference between longitude of focal center and reference center 
				
				gen distance`i' = `earth_radius' * acos( cos(`LAT_`i'_P') * cos(LAT_P) + sin(`LAT_`i'_P') * sin(LAT_P) * cos(delta_LON`i'_P) )
			
				drop delta_LON`i'_P
			}
			
			save "$path\Generated datasets\temp", replace
			use  "$path\Generated datasets\temp", clear
			
			loc N = _N
			forvalues z = 2007/2014	{
			
				gen u10_`z' = 0
				gen u5_`z' = 0
				gen u2_5_`z' = 0
				
				label var u10_`z'  "Number of providers <10 miles away"
				label var u5_`z'   "Number of providers <5 miles away"
				label var u2_5_`z' "Number of providers <2.5 miles away"
				
				gen HQ_u10_`z' = 0
				gen HQ_u5_`z' = 0
				gen HQ_u2_5_`z' = 0	
				
				label var HQ_u10_`z'  "Number of 4/5 star providers <10 miles away"
				label var HQ_u5_`z'   "Number of 4/5 star providers <5 miles away"
				label var HQ_u2_5_`z' "Number of 4/5 star providers <2.5 miles away"
				
				gen cap5_`z' = 0
				gen HQ_cap5_`z' = 0
				
				label var cap5_`z' "Number of center based slots within 5 miles"
				label var HQ_cap5_`z' "Number of slots at 4/5 star centers within 5 miles"
				
				
				forvalues i = 1/`N'	{
					replace u10_`z' = u10_`z' + 1 		if distance`i' < 10  & 	`i' != _n	&	enroll_`z'[`i'] !=.
					replace u5_`z' = u5_`z' + 1 		if distance`i' < 5   & 	`i' != _n	&	enroll_`z'[`i'] !=.
					replace u2_5_`z' = u2_5_`z' + 1 	if distance`i' < 2.5 & 	`i' != _n	&	enroll_`z'[`i'] !=.
					
					replace HQ_u10_`z' = HQ_u10_`z' + 1 	if distance`i' < 10  &  `i' != _n	&	enroll_`z'[`i'] !=. & (stars_`z'[`i'] == 4 | stars_`z'[`i'] == 5)
					replace HQ_u5_`z' = HQ_u5_`z' + 1 		if distance`i' < 5  &  `i' != _n	&	enroll_`z'[`i'] !=. & (stars_`z'[`i'] == 4 | stars_`z'[`i'] == 5)
					replace HQ_u2_5_`z' = HQ_u2_5_`z' + 1 	if distance`i' < 2.5  &  `i' != _n	&	enroll_`z'[`i'] !=. & (stars_`z'[`i'] == 4 | stars_`z'[`i'] == 5)
					
					replace cap5_`z' = cap5_`z' + capacity_`z'[`i']			if distance`i' < 5  & 	`i' != _n	&	enroll_`z'[`i'] !=.
					replace HQ_cap5_`z' = HQ_cap5_`z' + capacity_`z'[`i']	if distance`i' < 5  & 	`i' != _n	&	enroll_`z'[`i'] !=. & (stars_`z'[`i'] == 4 | stars_`z'[`i'] == 5)
				}
				
				recode u10_`z' u5_`z' u2_5_`z' HQ_u10_`z' HQ_u5_`z' HQ_u2_5_`z' cap5_`z' HQ_cap5_`z' (* = .) if enroll_`z' ==.
				
				
			}
		
			drop distance*
		
			save "$path\Generated datasets\temp2", replace
			use  "$path\Generated datasets\temp2", clear
			
		//Great circle formula written out w/o substitutions
		//distance = earth_radius * acos( cos( ( 90 - lat1 ) * ( pi / 180 ) ) * cos( ( 90 - lat2 ) * ( pi / 180 ) ) +  
		//sin( ( 90 - lat1 ) * ( pi / 180 ) ) * sin( ( 90 - lat2 ) * ( pi / 180 ) ) * cos( ( lon1 - lon2 ) * ( pi / 180 ) ) )
	
	
	//"First" and "last" variables
	*********************************
		gen first_year =.
		gen first_ers =.
		gen first_visit = .
		gen first_ERSmonth = .
		
		label var first_year "First year in data"
		label var first_ers "First year with ERS rating"
		
		forvalues i = 2014(-1)2007	{
			replace first_year = `i' if enroll_`i' !=. //Enrollment variable is non-missing for all observed settings		
			replace first_ers = `i' if avgERS_`i' !=.
			
			replace first_visit = ERSyear_`i' if ERSyear_`i' !=.
			replace first_ERSmonth = ERSmonth_`i' if ERSmonth_`i' !=.
			
		} //close i loop
		
		gen last_year =.
		gen last_ers = .
		gen last_visit = .
		
		label var last_year "Last year in data"
		label var last_ers "Last year with ERS rating"
		
		forvalues i = 2007/2014	{
		
			replace last_year = `i' if enroll_`i' !=.	//Counting non-missing observations (enrollment is never missing)		
			replace last_ers = `i' if avgERS_`i' !=.			
			replace last_visit = ERSyear_`i' if ERSyear_`i' !=.

		} //close i loop
		
		gen num_years = (last_year+1)-first_year
		label var num_years "Number of years in the dataset"
		
		gen num_ers_yrs = (last_ers+1)-first_ers
		label var num_ers_yrs "Number of years of ERS ratings"
		replace num_ers_yrs = 0 if num_ers_yrs ==.
		
		
		forvalues i = 2007/2014	{
			
			//Attrition
				gen closed_`i' = enroll_`i' == . //Counting non-missing observations
				gen noERS_`i' = avgERS_`i' ==.
		
				label var closed_`i' "Facility was not in operation in `i'"
				label var noERS_`i'  "Facility did not have an active ERS rating in `i'"
		
				gen enroll_attr_`i' = enroll_`i'
				replace enroll_attr_`i' = 0 if closed_`i' ==1 & first_year <=`i'
				label var enroll_attr_`i' "Enrollment in `i' (attrition counts as 0)"
				
		} // close i loop

	
	// Defining the sample
	*************************************
	
	//First year we see an ERS rating, 2007-2009	
		gen ERS_yr_07_09 = .
		replace ERS_yr_07_09 = 2007 if avgERS_2007 !=.
		replace ERS_yr_07_09 = 2008 if avgERS_2008 !=. & ERS_yr_07_09 ==.
		replace ERS_yr_07_09 = 2009 if avgERS_2009 !=. & ERS_yr_07_09 ==.
		replace ERS_yr_07_09 = . if family_care !=0
		label var ERS_yr_07_09 "First year w/ERS rating, 2007-2009"
		
	//First year we see an ERS rating, 2009-2011
		gen ERS_yr_09_11 = .
		replace ERS_yr_09_11 = 2009 if avgERS_2009 !=.
		replace ERS_yr_09_11 = 2010 if avgERS_2010 !=. & ERS_yr_09_11 ==.
		replace ERS_yr_09_11 = 2011 if avgERS_2011 !=. & ERS_yr_09_11 ==.
		replace ERS_yr_09_11 = . if family_care !=0
		label var ERS_yr_09_11 "First year w/ERS rating, 2009-2011"
		
	//First year we see an ERS rating, 2010-2012
		gen ERS_yr_10_12 = .
		replace ERS_yr_10_12 = 2010 if avgERS_2010 !=.
		replace ERS_yr_10_12 = 2011 if avgERS_2011 !=. & ERS_yr_10_12 ==.
		replace ERS_yr_10_12 = 2012 if avgERS_2012 !=. & ERS_yr_10_12 ==.
		replace ERS_yr_10_12 = . if family_care !=0
		label var ERS_yr_10_12 "First year w/ERS rating, 2010-2012"
					
	
	//Using assumptions to generate initial year
		gen ERS_yr_1st = .
		gen ERS_yr_2nd = .
		gen first_ERS_change = .
			
		forvalues i = 2008/2014	{			
			loc last = `i' -1
				
			// If this year and last are both non-missing, but are different
			replace first_ERS_change = `i' if (avgERS_`i' !=. & avgERS_`last' !=.) & (avgERS_`i' != avgERS_`last') & first_ERS_change ==.
			
		} //closes i loop
		
		replace ERS_yr_1st = first_ers if first_ers != 2007	//Use first year if it's not 2007
		replace ERS_yr_1st = 2007 if first_ers ==2007 & first_ERS_change >= 2010 //Use 2007 if 2007-2009 scores are the same
		replace ERS_yr_1st = first_ERS_change if first_ers ==2007 & first_ERS_change <2010 //Use first changed score if 2007-2009 are not identical

		replace ERS_yr_1st = 2007 if first_visit ==2007 & avgERS_2007 !=. //Use visit dates in 2007 where we have them
		replace ERS_yr_1st = 2007 if first_visit ==2006 & avgERS_2007 !=.
			
		replace ERS_yr_1st = . if family_care ==1	//Set family care centers to missing
		replace ERS_yr_1st = . if ERS_yr_1st >=2010	//Set to missing if first year is after 2009
	
			//Note. Six observations are now 2007 rather than 2009 with pattern of ERS in 2007 & 2009 but not 2008
	
		replace ERS_yr_2nd = first_ERS_change if first_ERS_change <2012
		
		
		save "$path\Generated datasets\temp", replace
		use  "$path\Generated datasets\temp", clear
			
			
	//Variables that are assigned based on "initial rating" year
	**************************************************************	
	
		//Generate t+1 - t+5 years 
			forvalues i = 1/5	{
				gen ctr1_plus`i' = ERS_yr_1st + `i'
				
				gen ctr2_plus`i' = ERS_yr_07_09 + `i'
				
				gen ctr3_plus`i' = ERS_yr_09_11 + `i'
				replace ctr3_plus`i' = . if ERS_yr_09_11 + `i' > 2014
				
				gen ctr4_plus`i' = ERS_yr_10_12 + `i'
				replace ctr4_plus`i' = . if ERS_yr_10_12 + `i' > 2014
				
				gen ctr5_plus`i' = ERS_yr_2nd + `i'
				replace ctr5_plus`i' = . if ERS_yr_2nd + `i' > 2014
			}
			
		cap program drop assign_yr
		program assign_yr
			args var varlab baseyr
			
				foreach x in ctr1 	{
					//ctr2 ctr3 ctr4 ctr5
					if "`x'" == "ctr1"		{
						loc initial = "ERS_yr_1st" //Set this as the variable that determines the initial rating
						loc initlab "in baseline year"
					}
					if "`x'" == "ctr2" 	{
						loc initial = "ERS_yr_07_09" //Set this as the variable that determines the initial rating
						loc initlab "in 1st year w/ERS, 2007-2011"
					}		
					if "`x'" == "ctr3"	{
						loc initial = "ERS_yr_09_11"
						loc initlab "in 1st year w/ERS, 2009-2011"
					}
					if "`x'" == "ctr4"	{
						loc initial = "ERS_yr_10_12"
						loc initlab "in 1st year w/ERS, 2010-2012"
					}
					if "`x'" == "ctr5"	{
						loc initial = "ERS_yr_2nd"
						loc initlab "in 1st year of 2nd observed ERS"
					}
					
					//Variables that we have beginning in 2007
					*******************************************
					if `baseyr' == 2007	{
					
						gen `x'_`var'_0 = .  //New "initial year" variable
						label var `x'_`var'_0 "`varlab' `initlab'"
					
						forvalues i = 2007/2014	{
							replace `x'_`var'_0 = `var'_`i' 	 if `initial' == `i'
						}
					
						//Generate T+1 - T+5 outcomes
							forvalues z = 1/5	{			
							
								gen `x'_`var'_`z' = .
							
								forvalues i = 2007/2014	{
									replace `x'_`var'_`z' = `var'_`i'  if `x'_plus`z' == `i' & `x'_`var'_0 !=.
									label var `x'_`var'_`z' "`varlab' in T + `z'"
								} //close i loop
								
							} //close z loop					
					
					} //close if baseyr	
					
					//Variables that we have beginning in 2009
					*******************************************
					if `baseyr' == 2009	{
					
						if "`x'" != "ctr3" & "`x'" != "ctr4"	{
						
							forvalues z = 2/5	{			
							
								gen `x'_`var'_`z' = .
							
								forvalues i = 2007/2014	{
									replace `x'_`var'_`z' = `var'_`i'  if `x'_plus`z' == `i' & `initial' !=.
									label var `x'_`var'_`z' "`varlab' in T + `z'"
								} //close i loop			
							} //close z loop
						} // close "if x"
						
						if "`x'" == "ctr3" | "`x'" == "ctr4" {
						
							gen `x'_`var'_0 = .  //New "initial year" variable
							label var `x'_`var'_0 "`varlab' `initlab'"
						
							forvalues i = 2007/2014	{
								replace `x'_`var'_0 = `var'_`i' 	 if `initial' == `i'
							}
						
							//Generate T+1 - T+5 outcomes
								forvalues z = 1/5	{			
								
									gen `x'_`var'_`z' = .
								
									forvalues i = 2007/2014	{
										replace `x'_`var'_`z' = `var'_`i'  if `x'_plus`z' == `i' & `x'_`var'_0 !=.
										label var `x'_`var'_`z' "`varlab' in T + `z'"
									} //close i loop
									
								} //close z loop			
						
						} //close if x
					} //close if baseyr 
				} //close x loop
			
		end //ends program assign_yr

		
		//Vars starting in '07
		assign_yr 	stars		"Star rating"		2007
		assign_yr	three_star	"3+ star rating"	2007
		assign_yr	four_star	"4+ star rating"	2007
		assign_yr	five_star	"5 star rating"		2007
		
		assign_yr 	avgERS 		"Average ERS rating"	 2007
		assign_yr 	lowERS 		"Lowest ERS rating"		 2007
		assign_yr	numERS		"Number of ERS ratings"	 2007
		assign_yr	numERS_type "Types of ERS ratings"	 2007
		assign_yr	oneERS		"One ERS rating"		 2007
		assign_yr	multiERS	"At least 2 ERS ratings" 2007
		
		assign_yr	capacity	"Capacity"						2007
		assign_yr	enroll		"Enrollment"					2007
		assign_yr	enroll_attr "Enrollment, incl. attrition"	2007
		assign_yr	lnenroll	"ln(enrollment)"				2007
		assign_yr	prop_full	"Prop. capacity filled"			2007	
		
		assign_yr	closed		"Center closed"					2007
		assign_yr	noERS		"Closed or open w/no ERS score"	2007
		assign_yr	noERS_open	"Open with no ERS score"		2007
		
		assign_yr	ftype		"Facility type"				2007
		assign_yr 	ind			"Independent center"		2007
		assign_yr	lps			"Local public school"		2007
		assign_yr	rel			"Religious sponsored"		2007
		assign_yr	hs			"Head Start"				2007
		assign_yr	oth			"Other center based care"   2007	
		
		assign_yr	u10			"# of providers < 10mi"		2007
		assign_yr	u5			"# of providers < 5mi"		2007
		assign_yr	u2_5		"# of providers < 2.5mi"	2007
		
		assign_yr	HQ_u10		"# of HQ providers < 10mi"	2007
		assign_yr	HQ_u5		"# of HQ providers < 5mi"	2007
		assign_yr	HQ_u2_5		"# of HQ providers < 2.5mi"	2007
		
		assign_yr	cap5		"# of slots < 5 mi"		2007
		assign_yr	HQ_cap5		"# of HQ slots <5 mi"	2007
		
		assign_yr 	above_4_5	"Above 4.5 threshold"	2007
		assign_yr	below_4_5	"Below 4.5 threshold"	2007
		assign_yr	above_4_75	"Above 4.75 threshold"	2007
		assign_yr 	FCCERS1 	"FCCERS1"				2007
		assign_yr	anyFCCERS	"Any FCCERS rating"		2007
		
		
		foreach rating in ECERS ITERS SACERS	{ //ERS scores
			assign_yr	any`rating'	"Any `rating' rating"	2007

			forvalues i = 1/5	{	
				assign_yr 	`rating'`i'	"`rating' `i'"	2007
			}
		}
		
		//Vars starting in '09
		assign_yr	tot_pts		"Total QRIS points" 			2009	
		assign_yr	edu_score	"Education score"				2009
		assign_yr	edu_admin	"Administrator education score"	2009
		assign_yr	edu_lt		"Lead teacher education score"	2009
		assign_yr	edu_tch		"Teacher education score"		2009
		assign_yr	edu_gl		"Group leader score"			2009
		assign_yr	edu_pc		"Program coordinator score"		2009
		assign_yr	qual_point	"Earned a quality point"		2009
			
		assign_yr	pgm_score	"Program score"						2009
		assign_yr	pgm_allstd	"All standards met"					2009
		assign_yr	pgm_minreq	"Minimum licensing requirements"	2009
		assign_yr	pgm_ratio	"Meets ratio requirements"			2009
		assign_yr	pgm_redrt	"Meets reduced ratio reqs"			2009
		assign_yr	pgm_space	"Meets space reqs"					2009

		assign_yr	pgm_qp1		"Dev. appropriate curriculum"				2009
		assign_yr	pgm_qp2		"Reduced group sizes"						2009
		assign_yr	pgm_qp3		"Reduced child staff ratio"					2009
		assign_yr	pgm_qp4a	"Enhanced operational policies"				2009	
		assign_yr	pgm_qp4b	"Offers staff benefits package"				2009
		assign_yr	pgm_qp4c	"Set up to facilitate parent involvement"	2009
		assign_yr	pgm_qp5		"Admin has completed business training"		2009
		
		assign_yr	edu_qp1		"75% of I/T teachers have certificate"		2009
		assign_yr	edu_qp2		"75% of teachers have AAS or higher"		2009
		assign_yr	edu_qp3		"75% of lead teachers have BA/BS or higher"	2009
		assign_yr	edu_qp4		"All lead teachers have AAS or higher"		2009
		assign_yr	edu_qp5		"75% of group leaders have NCSACCC" 		2009
		assign_yr	edu_qp6		"All tchrs/lts have 20 hrs extra training"	2009
		assign_yr	edu_qp7		"75% of tchrs/lts have min 10 yrs EC exp"	2009
		assign_yr	edu_qp8		"All tchrs/lts have min 5 yrs EC exp"		2009
		assign_yr	edu_qp9		"Combined turnover is <=20%"				2009

	
	//Variables that need to be created after assigning based on treatment year
		label values ctr1_ftype* ftype //Assign ftype value labels
		
		gen ctr1_first_change = .
		gen ctr1_first_rerate = .
		loc ERS "ctr1_avgERS"
		
		forvalues i = 1/5	{
			loc last = `i'-1
			replace ctr1_first_change = 	`i' if (`ERS'_`i' != `ERS'_`last')  & ctr1_first_change ==.
			replace ctr1_first_rerate = 	`i' if (`ERS'_`i' != `ERS'_`last') & (`ERS'_`i' !=.)  & ctr1_first_rerate ==.
		}
		
		forvalues i = 0/5		{
			gen ctr1_early_rerate_`i' = ctr1_first_rerate <3
			replace ctr1_early_rerate_`i' = . if ctr1_first_rerate ==.
			label var ctr1_early_rerate_`i' "ERS rating changed less than 3 years after initial"
			
			gen ctr1_ontime_rerate_`i' = ctr1_first_rerate ==3
			replace ctr1_ontime_rerate_`i' = . if ctr1_first_rerate ==.
			label var ctr1_ontime_rerate_`i' "ERS rating changed exactly 3 years after initial"
			
			gen ctr1_late_rerate_`i' = ctr1_first_rerate >3 & ctr1_first_rerate <.
			replace ctr1_late_rerate_`i' = . if ctr1_first_rerate ==.
			label var ctr1_late_rerate_`i' "ERS rating changed 4 or more years after initial"
		}
		
		gen ctr1_rerated_0 = 0 if ctr1_capacity_0 !=.
		
		forvalues i = 1/5	{
			loc prev = `i'-1
			
			gen ctr1_rerated_`i' = ctr1_rerated_`prev' 
			replace ctr1_rerated_`i' = 1 if ctr1_first_rerate==`i' 
			replace ctr1_rerated_`i' = . if ctr1_three_star_`i' ==. //Setting to missing if center was closed
		}
		
	//Imputed outcomes that carry forward the baseline ERS rating for centers who had no ERS in T+5
	
		gen ctr1_avgERS_imputed_5 = ctr1_avgERS_5
		replace ctr1_avgERS_imputed_5 = ctr1_avgERS_0 if ctr1_noERS_open_5 ==1
		
		//Just recopying these values so I don't have to rewrite the analysis code
		forvalues i = 0/4	{
			gen ctr1_avgERS_imputed_`i' = ctr1_avgERS_imputed_5
		}
		
	************************************************
	* Construct variables for the RD analysis
	************************************************

		* Center care variables
		***********************
		 
			 cap program drop ctrlab
			 program define ctrlab
				args num cut type fvnam
				
					loc fv "`type'_`fvnam'_0"
					
					gen `type'_fv_`num' = `fv'-`cut'  //Centered forcing variables
					label var `type'_fv_`num' "ERS rating (centered at `cut')"
		
					gen `type'_cut_`num' = `type'_fv_`num' <0
					replace `type'_cut_`num' =. if `type'_fv_`num' ==.
					label var `type'_cut_`num' "ERS rating was < `cut'"
					
					gen `type'_int_`num' = `type'_cut_`num' * `type'_fv_`num'
					replace `type'_int_`num' =. if `type'_fv_`num' ==.
					label var `type'_int_`num' "`type'_cut_`num' * `type'_fv_`num'"
						
					gen `type'_fv_sq_`num' = `type'_fv_`num' * `type'_fv_`num'
					label var `type'_fv_sq_`num' "`type'_fv_`num' squared"
				
					gen `type'_int_sq_`num' = `type'_cut_`num' * `type'_fv_sq_`num'
					label var `type'_int_sq_`num' "`type'_cut_`num' * `type'_fv_sq_`num'"
				
			end //ends program ctrlab
				
			ctrlab 2 4.5 	ctr1 avgERS //FV1
			ctrlab 3 4.75	ctr1 avgERS
			ctrlab 4 5		ctr1 avgERS

			/*
			ctrlab 2 4.5 	ctr2 avgERS //FV2
			ctrlab 3 4.75	ctr2 avgERS
			ctrlab 4 5		ctr2 avgERS

			ctrlab 2 4.5 	ctr3 avgERS //FV3
			ctrlab 3 4.75	ctr3 avgERS
			ctrlab 4 5		ctr3 avgERS
			
			ctrlab 2 4.5 	ctr4 avgERS //FV4
			ctrlab 3 4.75	ctr4 avgERS
			ctrlab 4 5		ctr4 avgERS
			
			ctrlab 2 4.5 	ctr5 avgERS //FV5
			ctrlab 3 4.75	ctr5 avgERS
			ctrlab 4 5		ctr5 avgERS
			*/
		
		//Define different analytic samples
		***************************************
		
		foreach x in ctr1 	{
			//ctr2 ctr3 ctr4 ctr5
			
			if "`x'" == "ctr1" 		loc initvar = "ERS_yr_1st"
			//if "`x'" == "ctr2" 	loc initvar = "ERS_yr_07_09"
			//if "`x'" == "ctr3" 	loc initvar = "ERS_yr_09_11"
			//if "`x'" == "ctr4" 	loc initvar = "ERS_yr_10_12"
			//if "`x'" == "ctr5" 	loc initvar = "ERS_yr_2nd"
			
			gen `x'_samp1 = `initvar' < .  //All centers w/ERS
			replace `x'_samp1 = . if family_care ==1
			label var `x'_samp1 "All centers w/ERS ratings"

			//Low vs. high enrollment
				sum `x'_enroll_0, detail
				
				gen `x'_hi_enroll = `x'_enroll_0 >= r(p50)
				replace `x'_hi_enroll = . if `x'_enroll_0 ==.
				label var `x'_hi_enroll "Enrollment was >= median in year T"
				
				gen `x'_lo_enroll = `x'_enroll_0 < r(p50)
				replace `x'_lo_enroll = . if `x'_enroll_0 ==.
				label var `x'_lo_enroll "Enrollment was < median in year T"
				
			//By auspice
				gen `x'_public = `x'_lps_0 ==1 | `x'_hs_0 ==1
				replace `x'_public = . if `x'_lps_0 ==. //if lps is missing, so is hs
				label var `x'_public "LPS/Head Start in year T"
				
				gen `x'_othcent = `x'_public ==0
				replace `x'_othcent = . if `x'_public ==.
				label var `x'_othcent "Other center (not LPS/HS) in year T"

			//Low vs. high competition
				sum `x'_u5_0, detail		
					gen `x'_lowcomp = `x'_u5_0 < r(p50)
					replace `x'_lowcomp = . if `x'_u5_0 ==.
					label var `x'_lowcomp "Below median # of centers within 5 miles"
					
					gen `x'_hicomp = `x'_u5_0 >= r(p50)
					replace `x'_hicomp = . if `x'_u5_0 ==.
					label var `x'_hicomp "Above median # of centers within 5 miles"
				
				sum `x'_HQ_u5_0, detail	
					gen `x'_lowQcomp = `x'_HQ_u5_0 < r(p50)
					replace `x'_lowQcomp = . if `x'_HQ_u5_0 ==.
					
					gen `x'_hiQcomp = `x'_HQ_u5_0 >= r(p50)
					replace `x'_hiQcomp = . if `x'_HQ_u5_0 ==.
					
				sum `x'_cap5_0, detail		
					gen `x'_lowcap = `x'_cap5_0 < r(p50)
					replace `x'_lowcap = . if `x'_cap5_0 ==.
					label var `x'_lowcap "Below median # of slots within 5 miles"
					
					gen `x'_hicap = `x'_cap5_0 >= r(p50)
					replace `x'_hicap = . if `x'_cap5_0 ==.
					label var `x'_hicap "Above median # of slots within 5 miles"
					
			//No ERS in T+5 vs. had ERS in T+5
				gen `x'_hadrating = `x'_noERS_open_5 ==0
				replace `x'_hadrating = . if `x'_noERS_open_5==.
				label var `x'_hadrating "Open, had ERS rating in T+5"
				
				gen `x'_norating = `x'_noERS_open_5 ==1
				replace `x'_norating = . if `x'_noERS_open_5==.
				label var `x'_norating "Open, no ERS rating in T+5"
				
			} //close x loop
	
			capture program drop samp_split
			program samp_split
				args splitvar newvar varlab
			
				sum `splitvar', detail
				gen samp_`newvar' = `splitvar' > r(p50)
				replace samp_`newvar' =. if `splitvar' ==.
				label var samp_`newvar' "`varlab'"
				
			end //Ends program samp_split
			
			samp_split 	p_black 	hi_black 	"Above median % black (zip code)"
			samp_split	med_income	hi_inc		"Above median income (zip code)"
			samp_split	u5_2007		hi_comp07	"Above median competition (2007)"
			samp_split	u5_2009		hi_comp09	"Above median competition (2009)"

			
	//Order variables
	
		order _all, sequential
		
		order id fname county zip p_pov p_black p_hisp med_income ftype agerange first_year last_year first_ers last_ers  ///
			 ERSvisitdate* ERSyear* ERS_yr* ctr1_fv* ctr1_cut* ctr1_int* 
					

save "${path}\Generated datasets\Full dataset wide", replace

saveold "${path}\Generated datasets\Full dataset wide (v13)", replace version(13)
