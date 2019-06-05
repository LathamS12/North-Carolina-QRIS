/************************************************************
* Author: Scott Latham
* Purpose: Cleaning North Carolina QRIS data
*
* Date created: 	7/16/2014
* Last modified:	6/11/2018
*************************************************************/

	pause on 
	use "${path}\Generated datasets\Full dataset raw", clear
	
	//Drop variables that are exact duplicates or remnants from importing from Excel
	********************************************************************************
		#delimit ;
			
			drop AX AY FacilityType PermitType CTRStaffEDUScoreAvg 
					CTRProgramStandardsScoreAvg CTRComplianceHistory*
					CTRDidntApplyforStars CTRRatingScaleScore ;
					
				
			drop EnrollSecondShift* EnrollThirdShift* ;
				
		#delimit cr	
	
	//Rename FCCH variables to be shorter
		rename FCCHFDCRSScore 					FCCHFDCRS  
		rename FCCHHasWrittenOpsPolicies 		FCCHWrittenPols
		rename FCCHMeetsMINRequirements 		FCCHMinReqs
		rename FCCHNoMrThan3ChldUnder1 			FCCHMax3ChldUnd1
		rename FCCHProgramStandardsScore 		FCCHProgramScore
		rename FCCHProgramStandardsScoreAvg 	FCCHProgramScoreAvg
		rename FCCHProviderEducationLevel 		FCCHProvEdLevel
		rename FCCHProviderEducationScore 		FCCHProvEdScore
		rename FCCHProviderEducationScoreAv 	FCCHProvEdScoreAvg
		rename FCCHStarRating 					FCCHStarRating
		rename FCCHTotalPoints 					FCCHTotPts
		rename FCCHNOMRThan4ChldUndr_1 			FCCHMax4ChldUnd1
		rename FCCHQualityPtEducatnOptionM 		FCCHQualPtEdOption
		rename FCCHQualityPtProgramOptionM 		FCCHQualPtPgmOption
		rename FCCHCompleteBusinessTRNGCour 	FCCHBusnsTrng
		rename FCCHCompleted20InserviceTrng 	FCCH20TrngHrs
		rename FCCHHasBABSOrHigherInECC 		FCCHBABSorHigher
		rename FCCHHasInfantToddlerCertific 	FCCHInfToddCert
		rename FCCHMaxof2Infrants 				FCCHMax2Infants
		rename FCCHMaxof4PreschoolChildren 		FCCHMax4Preschl
		rename FCCHUsesAgeDevAppropCurricu		FCCHAgeApprCurr
	
	//Convert yes/no variables to standard 1-0 dummies
	*****************************************************	
		loc dummies "CTRHasSecondAdmin-CTRMeetsMI StarRating-CTRSetup "
		
		foreach x of varlist `dummies'	{
			
			replace `x' = "0" if `x' == "NO"
			replace `x' = "1" if `x' == "YES"
			
			destring `x', replace

		} //close x loop
		
		label define yesno 0 "No" 1 "Yes"
		label values `dummies' yesno
		

	//Facility information
	*****************************
		rename CountyNameOfFacilityLocation county
		label var county "County where facility is located"
		
		rename FacilityID id
		rename FacilityName fname
		
		rename ReportCalYear year
		label var year "Calendar year of report"
		
		rename AgeRange agerange
		label var agerange "Age range served by facility"	
			
		label var family_care "Type of care setting (1=family child care home)"
		label define famcare 0 "Center" 1 "Family care home"
		label values family_care famcare
				
		//Auspice
			encode CategoryOfOperation, gen(ftype)
			label variable ftype "Facility type"
			drop CategoryOfOperation
		
			gen ind = ftype ==9
			replace ind = . if ftype ==.
			label var ind "Independent center"
			
			gen lps = ftype ==10
			replace lps = . if ftype ==.
			label var lps "Local public school"
			
			gen rel = ftype == 16
			replace rel = . if ftype ==.
			label var rel "Religious sponsored"
			
			gen hs = ftype == 8
			replace hs = . if ftype ==.
			label var hs "Head Start"
			
			egen oth = anymatch(ftype), values(1/7 11/15)
			label var oth "Other center based care"

			gen public = ftype ==10 | ftype==8
			replace public = . if ftype==.
			label var public "Local public school or Head Start"
			
		//License type
			encode MaxPermit, gen(ltype)
			gen license =.
			
			replace license = 1 if (ltype >0 & ltype <=4) | ltype ==7 | ltype ==8  ///
								| (ltype >=20 & ltype <.)
			
			replace license = 2 if ltype ==18 | ltype ==19
			
			replace license = 3 if ltype ==5 | ltype ==6
			
			replace license = 4 if ltype >=9 & ltype <=17

			label var license "License type"
			
			label define lictype 1 "Star Rated" 2 "Temporary" 3 "Notice of Compliance"  ///
				4 "Provisional/probationary"
			label values license lictype	
			
			drop ltype
			
		//Capacity, enrollment
		
			egen capacity = rowmax(Capacity*Shift)
			label var capacity "Maximum capacity"
			drop Capacity*
			
			rename EnrollFirstShiftInfantsSum 	enroll_inf
			rename EnrollFirstShift1YrSum 		enroll_1yr
			rename EnrollFirstShift2YrSum 		enroll_2yr
			rename EnrollFirstShift3YrSum 		enroll_3yr
			rename EnrollFirstShift4YrSum 		enroll_4yr
			rename EnrollFirstShift5YrPSSum 	enroll_5yr
			rename EnrollFirstShiftSchlAgeSu 	enroll_sa	
			
			rename EnrollFirstShiftTotalSum 	enroll
			
			label var enroll_inf "Number of infants enrolled"
			label var enroll_sa  "Number of school-aged students enrolled"
			
			egen enroll_03 = rowtotal(enroll_inf enroll_1yr enroll_2yr enroll_3yr)
			egen enroll_45 = rowtotal(enroll_4yr enroll_5yr)

			forvalues i = 1/5	{
				label var enroll_`i'yr "Number of `i' year olds enrolled"
			} //close i loop
					
			label var enroll "Total number of students enrolled"
			replace enroll = capacity*2 if capacity*2 < enroll //Topcoding enrollment at twice capacity
			
			gen lnenroll = ln(enroll)
			label var lnenroll "Log of enrollment"
			
			gen prop_full = enroll/capacity			
			label var prop_full "Proportion of total capacity that is filled"
			
			gen prop_03 = enroll_03/enroll
			gen prop_45 = enroll_45/enroll
			gen prop_sa = enroll_sa/enroll
			
			foreach x in prop_03 prop_45 prop_sa	{
				replace `x' = 1 if `x'>1 & `x'<.
			}
	
		//Demographic characteristics
			rename percent_black p_black
			label var p_black "Percent black (zip code)"
			
			rename percent_latino p_hisp
			label var p_hisp "Percent Hispanic (zip code)"

			rename house_medincome med_income
			label var med_income "Median household income (zip code)"
			
			rename percent_fam_belowpov p_pov
			label var p_pov "Percent below poverty line (zip code)"
		
			drop pop_*

	//Overall ratings and ERS scores
	***********************************
		gen stars = .
		label var stars "overall star ratings"
		
		replace stars = 1 if MaxPermit == "One Star Center License" | MaxPermit == "One Star Family CC Home License"
		replace stars = 2 if MaxPermit == "Two Star Center License" | MaxPermit == "Two Star Family CC Home License"
		replace stars = 3 if MaxPermit == "Three Star Center License" | MaxPermit == "Three Star Family CC Home License"
		replace stars = 4 if MaxPermit == "Four Star Center License" | MaxPermit == "Four Star Family CC Home License"
		replace stars = 5 if MaxPermit == "Five Star Center License" | MaxPermit == "Five Star Family CC Home License"
		
		replace stars = 0 if stars ==. & year != 2015 //Ignoring 2015 for now		
		
		label define st 0 "No rating" 1 "1 star" 2 "2 stars" 3 "3 stars" 4 "4 stars" 5 "5 stars"
		label values stars st

		drop *StarRating MaxPermit
		
		//Binary star rating outcomes		
			gen five_star = stars ==5
			replace five_star = . if stars ==.
			label var five_star "Five star rating (1 = yes)"
			
			gen four_star = stars >=4
			replace four_star = . if stars ==.
			label var four_star "Four star rating or higher (1 = yes)"
			
			gen three_star = stars >=3
			replace three_star = . if stars ==.
			label var three_star "Three star rating or higher (1 = yes)"
			
			gen two_star = stars >=2
			replace two_star = . if stars ==.
			label var two_star "Two star rating or higher (1 = yes)"	
		
		
		gen tot_pts = CTRTotalPoints if family_care ==0
		replace tot_pts = FCCHTotPts if family_care ==1
		label var tot_pts "Total points received by facility (0-15)"
		drop *TotalPoints
		
		//ERS ratings ****Forcing variables****	
			rename CTRECERSRSCORE* ECERS*
			rename CTRITERSRSCORE* ITERS*
			rename CTRSACERSSCORE* SACERS*
			rename CTRFDCRSSCORE1  FCCERS1
			
			destring SACERS5, replace		
			
			forvalues i = 1/5	{
				
				label var ECERS`i' "Early Childhood Environment Rating Scale score `i'"
				label var ITERS`i' "Infant/Toddler Environment Rating Scale score `i'"
				label var SACERS`i' "School-Age Care Environment Rating Scale score `i'"
			cap label var FCCERS`i' "Family Child Care Care Environment Rating Scale score `i'"
				
				replace ECERS`i' = . if ECERS`i' ==0
				replace ITERS`i' = . if ITERS`i' ==0
				replace SACERS`i' = . if SACERS`i' ==0
			cap replace FCCERS`i' = . if FCCERS`i' ==0
					
			} //close i loop
			
				
			//Average and lowest ERS ratings	
				egen avgERS = rowmean(ECERS? ITERS? SACERS? FCCERS1)
				label var avgERS "Average ERS score (unrounded)"	
				
				egen avgECERS = rowmean(ECERS?)
				egen avgITERS = rowmean(ITERS?)
				egen avgSACERS = rowmean(SACERS?)
				gen avgFCCERS = FCCERS1
				
				gen above_4_5 = avgERS >= 4.5 & avgERS <.
				replace above_4_5 = . if avgERS ==.
				label var above_4_5 "Above 4.5 threshold"
				
				gen below_4_5 = avgERS < 4.5 & avgERS <.
				replace below_4_5 = . if avgERS ==.
				label var below_4_5 "Below 4.5 threshold"
				
				gen above_4_75 = avgERS >= 4.75 & avgERS !=.
				replace above_4_75 = . if avgERS ==.
				label var above_4_75 "Above 4.75 threshold"
			
				egen lowERS = rowmin(ECERS? ITERS? SACERS? FCCERS1)
				replace lowERS = . if lowERS ==0
				label var lowERS "LOWEST classroom ERS rating"

			//How many and which type of ratings				
				gen numERS_type = 0
				label var numERS_type "Number of ERS types (e.g. ECERS, ITERS)"
				
				foreach rating in ECERS ITERS SACERS FCCERS	{ 	
				
					egen num`rating' = rownonmiss(`rating'?)
							
					gen any`rating' = num`rating' >=1
					label var any`rating' "Any `rating' rating"
					
					replace numERS_type = numERS_type+1 if any`rating' ==1
				}	
				
				egen numERS = rownonmiss(ECERS? ITERS? SACERS? FCCERS1)
				label var numERS "Number of ERS ratings (ECERS/ITERS/SACERS)"
				
				gen oneERS = numERS ==1
				replace oneERS = . if numERS ==.
				label var oneERS "Setting had only 1 ERS score"
				
				gen multiERS = numERS >1
				replace multiERS = . if numERS ==.
				label var multiERS "Setting had at least 2 ERS scores"

				gen noERS_open = avgERS ==. //Prior to reshaping, no need to worry about closed centers in data
				label var noERS_open "No ERS rating, still open"
				
		
			//ERS visit date - Stored as an integer indicating the number of days since January 1, 1960
				rename VisitDate ERSvisitdate
				gen ERSyear = year(ERSvisitdate)
				label var ERSyear "Year of ERS rating"
					
				gen ERSmonth = month(ERSvisitdate)
				label var ERSmonth "Month of ERS rating"
			
	//QRIS rating components
	***************************
	
		//Program standards
			rename CTRProgramStandardsScore pgm_score
			replace pgm_score = FCCHProgramScore if family_care ==1
			label var pgm_score "program standards scores"

			rename CTRMeetsAllEnhstd pgm_allstd
			label var pgm_allstd "Meets all enhanced standards (including space/ratios)"

			rename CTRMeetEnhstdReducedRatios pgm_redrt
			label var pgm_redrt "Exceeds standards for child-staff ratios (at least 1 fewer student/adult)"
			
			rename CTRMeetsEnhstdRatio pgm_ratio
			replace pgm_ratio = 1 if pgm_redrt ==1 //meeting reduced ratios or all stds implies that ratios were met
			replace pgm_ratio = 1 if pgm_allstd ==1				
			label var pgm_ratio "Meets enhanced standards for child-staff ratios (Standard differs by age group)"

			rename CTRMeetsEnhstdSpace pgm_space
			replace pgm_space = 1 if pgm_redrt ==1 //meeting reduced ratios or all stds implies that space reqs were met
			replace pgm_space = 1 if pgm_allstd ==1
			label var pgm_space "Meets enhanced standards for space"	
			
			rename CTRMeetsMINRequirements pgm_minreq
			replace pgm_minreq = 1 if pgm_ratio ==1 | pgm_space ==1 //Either of these imply that min reqs were met
			label var pgm_minreq "Center meets minimum licensing requirements"
		
		//Education standards		
			rename CTRStaffEDUScore edu_score 
			//replace edu_score = FCCHProviderEducationScore if family_care ==1
			label var edu_score "education standards scores"
			
			drop FCCHProgramScore
			
				rename CTRAdminEDULevel edu_admin
				label var edu_admin "administrator education standards score"
				
				rename CTRPgmCoordinatorEDULevel edu_pc
				label var edu_pc "program coordinator education standards score"		
				
				rename CTRLeadTeacherEDULevel  edu_lt
				label var edu_lt "lead teacher education standards score"	

				rename CTRTeacherEDULevel edu_tch
				label var edu_tch "teacher education standards score"
				
				rename CTRGroupLeaderEDULevel edu_gl 
				label var edu_gl "group leader education standards score"

				//For settings that don't have every type of position (e.g. program coordinator, group leader)
					* Replace with missing values
				
					foreach x in admin pc lt tch gl	{
						replace edu_`x' = . if edu_`x' == 0 & edu_score >0 & edu_score <.
					}		
			
				rename CTRHasSecondAdmin edu_2admin
				label var edu_2admin "Facility has second administrator"			
				
			
		//Quality points		
			rename StarRatingQualityPoint qual_point
			label var qual_point "Facility earned an additional quality point"
			
			rename CTRQualityPtEducation qual_point_e
			label var qual_point_e "Facility met the EDUCATION option for a quality point"

			rename CTRQualityPtProgram qual_point_p
			label var qual_point_p "Facility met the PROGRAM option for a quality point"
			
			rename CTR75PCTINFTODTCHRHAVE edu_qp1
			label var edu_qp1 "75% of infant/toddler teachers have an Infant/Toddler Certificate"
		
			rename CTR75PCTTCHRHAVEAAS edu_qp2
			label var edu_qp2 "75% of teachers have an Associate of Applied Science (AAS) or higher"
	
			rename CTR75PCTLEADTCHRHAVEBA edu_qp3
			label var edu_qp3 "75% of lead teachers have a BA/BS or higher"
		
			rename CTRALLLEADTCHRHAVEAAS edu_qp4
			label var edu_qp4 "All lead teachers have an AAS or higher"	
			
			rename CTR75PCTGRPLDRHAVENCSACC edu_qp5
			label var edu_qp5 "75% of group leaders have NCSACCC"
				//North Carolina School Age Care Credential
						
			rename CTRFTLEADTCHRANDTCHR20 edu_qp6
			label var edu_qp6 "All teachers/lead teachers have completed 20 extra training hrs"
					
			rename CTR75PCTFTLDTCHRandTC edu_qp7
			label var edu_qp7 "75% of teachers/lead teachers have at least 10 yrs EC work experience"

			rename CTRFTLDTCHRANDTCHR5YRE edu_qp8
			label var edu_qp8 "All teachers/lead teachers have at least 5 yrs EC work experience"
		
			rename CTRCOMBTurnover20PCTOr edu_qp9 
			label var edu_qp9 "Combined staff turnover is 20% or less" 

			rename CTRUsesAgeDevAppropCurric pgm_qp1
			label var pgm_qp1 "Center uses developmentally appropriate curriculum"
		
			rename CTRMeetsREDGRPSizeFrom281 pgm_qp2
			label var pgm_qp2 "Center meets reduced group size standards"
			
			rename CTRMeetsREDRatiosFrom281 pgm_qp3
			label var pgm_qp3 "Center meets reduced child-staff ratio standards"
				// One less child per staff member than the enhanced ratios
			
			//A center must meet two of the following three to get a quality point
				rename CTRHasEnhancedPoliciesAppr pgm_qp4a
				label var pgm_qp4a "Center has enhanced operational policies"
				
				rename CTRHasStaffBenefitsPack pgm_qp4b
				label var pgm_qp4b "Center offers a staff benefits package"

				rename CTRSetupForParentInvolvm pgm_qp4c
				label var pgm_qp4c "Center is set up to facilitate parental involvement"
				
				egen qcount = rowtotal(pgm_qp4?), missing

				gen pgm_qp4 = qcount >=2 & qcount <.
				replace pgm_qp4 = . if qcount ==.
				label var pgm_qp4 "Center has met at least two of three out of 4a-4c"
				drop qcount

			rename CTRAdminCompleteBUSTRNGC pgm_qp5 
			label var pgm_qp5 "Center administrator completed business training course"

	
	//Assign missing values for center variables to fccs and vice versa, and those w/no star ratings
	************************************************************************************************

		foreach x of varlist edu_* pgm_*	{ //This writes over fcc_ERS..doesn't matter for now though
			replace `x' = . if family_care ==1
			replace `x' = . if stars ==0
		}
		
		foreach x of varlist qual_point* pgm_score edu_score	{
			replace `x' = . if stars ==0
		}
			
	
	//Replicating the star rating process
	********************************************
		//Centers  - Almost perfectly replicates the process (about 7 errant obs.)
			gen cprog_score = .
			label var cprog_score "Constructed program score (Centers)"
			
			replace cprog_score = 0 if pgm_score !=. & family_care ==0
			****
			replace cprog_score = 1 if pgm_minreq ==1
			****
			replace cprog_score = 2 if (pgm_space ==1 | pgm_ratio ==1)
			****
			replace cprog_score = 3 if lowERS >=4 & lowERS <. & (pgm_space ==1 | pgm_ratio ==1)
			****
			replace cprog_score = 4 if avgERS >=4.5 & avgERS <. & lowERS >=4 & pgm_ratio ==1
			****
			replace cprog_score = 5 if avgERS >=4.75 & avgERS <. & lowERS >=4 & pgm_ratio ==1
			****
			replace cprog_score = 6 if avgERS >=5 & avgERS <. & lowERS >=4 & pgm_ratio ==1 & pgm_space ==1
			****
			replace cprog_score = 7 if lowERS >=5 & lowERS <. & pgm_redrt ==1 & pgm_space ==1
			
			replace cprog_score = . if avgERS !=. & lowERS ==.  //We don't have low ERS scores for some obs.					
		

	//Define different samples
	***************************

		preserve
			gen yrs_in_data8 = 1
			
			collapse (count) yrs_in_data8 (mean) family_care, by(id)
			
			gen notypechange_8 = 1 if family_care ==1 | family_care ==0
			save "${path}\Generated datasets\temp1", replace
		restore
		
		preserve
			keep if year >=2009 & year <= 2014
			gen yrs_in_data6 = 1	
			
			collapse (count) yrs_in_data6 (mean) family_care, by(id)
			
			gen notypechange_6 = 1 if family_care ==1 | family_care ==0
			save "${path}\Generated datasets\temp2", replace
		restore
	
		preserve
			keep if year >=2008 & year <= 2014
			gen yrs_ERS_7 = 1 if avgERS !=.	

			collapse (count) yrs_ERS_7 (mean) family_care, by(id)
			
			gen notypechange_7 = 1 if family_care ==1 | family_care ==0
			save "${path}\Generated datasets\temp3", replace
		restore
		
		
		merge m:1 id using "${path}\Generated datasets\temp1"
			drop _merge
		
		merge m:1 id using "${path}\Generated datasets\temp2"
			drop _merge

		merge m:1 id using "${path}\Generated datasets\temp3"
			drop _merge
		
		gen samp1 = 1
		gen samp_07_14 = yrs_in_data8 ==8 & notypechange_8 ==1 //In data all years
		gen samp_09_14 = yrs_in_data6 ==6 & notypechange_6 ==1 //In data 09-14 
		gen ERSsamp_08_14 = yrs_ERS_7 ==7 & notypechange_7 ==1 //Has ERS rating 08-14
		
		drop if notypechange_8 == . //Drop providers that switched from center to family care or vice versa
		
		erase "${path}\Generated datasets\temp1.dta"
		erase "${path}\Generated datasets\temp2.dta"
		erase "${path}\Generated datasets\temp3.dta"
		
	save "${path}\Generated datasets\Full dataset long", replace
	
