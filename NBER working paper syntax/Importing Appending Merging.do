/************************************************************
* Author: Scott Latham
* Purpose: Importing North Carolina QRIS data into Excel and 
*	appending across years
* Date created: 	7/15/2014
* Last modified:	3/13/2017
*************************************************************/
	
	pause on
	
	//Import data into Stata
	*******************************
	
		foreach x in center FCCH	{
		
			if "`x'" == "center"  	loc fam = 0
			if "`x'" == "FCCH"		loc fam = 1
			
			//Facility data
				forvalues i = 2007/2014	{

					if "`x'" == "center"	import excel "${excel}/`i' Data `x'.xls", sheet("`i'") firstrow clear
					if "`x'" == "FCCH"		import excel "${excel}/`i' Data `x'.xls", sheet("`i'FCCH") firstrow clear
					
						replace ReportCalYear = `i' //Assigning the year
						drop if CountyName == "" //Delete observations that do not represent actual centers
						
						gen family_care = `fam'
						label var family_care "Facility is a family child care home"
					
					save "${stata}/`i' facility data (`x')", replace

				} //closes i loop
			
			//QRIS data		
				forvalues i = 2009/2014	{
					
					import excel "${excel}\ThomasDee`i' `x'.xlsx", sheet("`i'") firstrow clear
			
						drop if FacilityName == "" //Delete observations that do not represent actual centers					
						drop CTRECERS* CTRITERS* CTRSACERS* //Duplicates that are giving me trouble when appending across years
					
						if "`x'" == "center"	tostring FCCHStarRating, replace //Aligning variables across datasets
						if "`x'" == "FCCH"		tostring CTRStarRating, replace 
						
					save "${stata}/`i' QRIS data (`x')", replace
				
				} //closes i loop

	
			//Dates of ERS visits					
				forvalues i = 2009/2014	{

					import excel "${excel}\2 Component Program Standards Staff Education including ERS Date_`i' `x'.xls", sheet("`i'") firstrow clear
					
						keep FacilityID FacilityName VisitDate_			
						drop if FacilityName =="" //Delete observations that do not represent actual centers
				
					save "${stata}/`i' ERS visit dates (`x')", replace
					
				} //closes i loop
		} //closes x loop
		
		
	//Appending data across public and family settings
	***************************************************
	
		//Facility data
			forvalues i = 2007/2014	{

				use "${stata}/`i' facility data (center)", clear
				append using "${stata}/`i' facility data (FCCH)"

				save "${stata}/`i' facility data", replace
				
			}
			
		//QRIS data
			forvalues i = 2009/2014	{

				use "${stata}/`i' QRIS data (center)", clear
				append using "${stata}/`i' QRIS data (FCCH)"
			
				save "${stata}/`i' QRIS data", replace 

			}
			
		//ERS visits
			forvalues i = 2009/2014	{
				
				use "${stata}/`i' ERS visit dates (center)", clear
				append using "${stata}/`i' ERS visit dates (FCCH)"
				
				save "${stata}/`i' ERS visit dates", replace 

			}

	//Merging facility, QRIS, and ERS visit data
	**********************************************

		forvalues i = 2007/2014	{
		
			use "${stata}/`i' facility data", clear
			
			if `i' >2008	{
				merge 1:1 FacilityID using "${stata}/`i' QRIS data"
				drop _merge //Perfect merge!!!	
				
				merge 1:1 FacilityID using "${stata}/`i' ERS visit dates"
				drop if _merge ==2 //choosing to drop 16 unmatched observations in 2014 that I haven't been able to account for 
									//	(we have no info other than name, ID, ERS visit date)
				drop _merge
			}
			save "${stata}/`i' data", replace

		}
		
	//Appending data across years
	************************************
		cd "${stata}"
		
		use "2007 data", clear
		append using "2008 data" "2009 data" "2010 data" "2011 data" "2012 data" "2013 data" "2014 data"	
		
		save "${path}\Generated datasets\Appended years", replace
		
	
	//Merging with location data
	******************************
		use "${path}\Generated datasets\Appended years", clear
		
		merge m:1 FacilityID using "${path}\Raw Data\Geocode data"
			drop if _merge ==2
			drop _merge year
		
		merge m:1 zip using "${path}\Raw data\latham NC zip dem vars"
			drop if _merge ==2
			drop _merge
	
		save "${path}\Generated datasets\Full dataset raw", replace
	
	//Deleting interim data files
	******************************
		forvalues i = 2007/2015	{
		
			cap erase "${stata}/`i' facility data (center).dta"
			cap erase "${stata}/`i' facility data (FCCH).dta"
			
			cap erase "${stata}/`i' QRIS data (center).dta"
			cap erase "${stata}/`i' QRIS data (FCCH).dta"
			
			cap erase "${stata}/`i' ERS visit dates (center).dta"
			cap erase "${stata}/`i' ERS visit dates (FCCH).dta"	
		
			cap erase "${stata}/`i' facility data.dta"
			cap erase "${stata}/`i' QRIS data.dta"
			cap erase "${stata}/`i' ERS visit dates"
		}
		
		cap erase "${path}\Generated datasets\Appended years.dta"
