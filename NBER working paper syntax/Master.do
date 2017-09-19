****************************************************************
* Author: Scott Latham
* Purpose: Master do file for the North Carolina QRIS project
* 
* Date Created:  5/4/2015
* Last modified: 3/13/2017
*****************************************************************

pause on

gl user "lathams"
*gl user "Scott"
 
gl path "C:\Users/${user}\Dropbox\Research\Current_projects\North_Carolina"

gl excel "${path}\Raw Data\Excel"
gl stata "${path}\Raw Data\Stata"


//Utility functions that post information from regressions

	capture program drop macs
		program macs, rclass
			args macs id lin
			
			foreach x in `macs' {
			
				if "`lin'"=="linear" & ("`x'" == "fv_2" | "`x'" == "fv_int2")	{
					gl coef_`id'_`x' ""
					gl se_`id'_`x' ""				
				}
				else {
				
					gl b_`id'_`x': di %3.2f _b[${`x'}]
					gl se_`id'_`x': di %3.2f _se[${`x'}]
					gl t_`id'_`x': di %3.2f _b[${`x'}] / _se[${`x'}] 		

					gl stars_`id'_`x' = ""
						if abs(${t_`id'_`x'}) >= 1.65		gl stars_`id'_`x' = "+"
						if abs(${t_`id'_`x'}) >= 1.96		gl stars_`id'_`x' = "*"
						if abs(${t_`id'_`x'}) >= 2.58		gl stars_`id'_`x' = "**"
						if abs(${t_`id'_`x'}) >= 3.30		gl stars_`id'_`x' = "***"
					
					gl coef_`id'_`x' "${b_`id'_`x'}${stars_`id'_`x'}" //Coefficient (beta + stars)			
					
					return loc N_`id' = e(N) 
					gl N_`id' = e(N) //sample size						
					
				} //close else statement
			} //close x loop		
		end //Ends program "macs"
			
			
	capture program drop mac_jr
		program mac_jr, rclass
			args macs id
			
			foreach x in `macs' {
			
				gl b_`id'_`x': di %3.2f _b[`x']
				gl se_`id'_`x': di %3.2f (-1)*(_se[`x'])
				gl t_`id'_`x': di %3.2f _b[`x'] / _se[`x'] 		

				gl stars_`id'_`x' = ""
					if abs(${t_`id'_`x'}) >= 1.65		gl stars_`id'_`x' = "+"
					if abs(${t_`id'_`x'}) >= 1.96		gl stars_`id'_`x' = "*"
					if abs(${t_`id'_`x'}) >= 2.58		gl stars_`id'_`x' = "**"
					if abs(${t_`id'_`x'}) >= 3.30		gl stars_`id'_`x' = "***"
				
				gl coef_`id'_`x' "${b_`id'_`x'}${stars_`id'_`x'}" //Coefficient (beta + stars)
				
				gl N_`id' = e(N) //sample size
				
			} //close x loop		
		end //Ends program "mac_jr"
		
	
	//Do files to import/clean/reshape
	do "${path}/Syntax/Importing appending merging"
	do "${path}/Syntax/Data cleaning"
	do "${path}/Syntax/Reshaping"
