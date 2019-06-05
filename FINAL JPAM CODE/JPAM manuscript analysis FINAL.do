*************************************************************************
* Author: Scott Latham
* Purpose: This file produces all of the tables/figures for the NC QRIS 
*			NBER working paper
* 
* Date Created:  5/4/2015
* Last modified: 9/19/2017
*************************************************************************
	
	****************	
	//Tables
	****************
	
		// Table 1 - Descriptives
			use "${path}\Generated datasets\Full dataset wide", clear
			
			tempname name
			tempfile file
			postfile `name' str60(var m0 sd0 m1 sd1 m2 sd2 m3 sd3 m4 sd4 m5 sd5) using `file'
				
			#delimit ;
			//Outcomes 2007-2014;
			loc dvs "three_star four_star five_star avgERS below_4_5 enroll prop_full u5";
			//loc attrit "rerated noERS_open closed" //Attrition descriptives;
			
			# delimit cr
			loc n = ""
			foreach x in `dvs' 	{
			
				loc yfull: variable label ctr1_`x'_5
				loc ylen = length("`yfull'")		
				loc ylab = substr("`yfull'", 1, `ylen'-9)
		
				forvalues i = 0/5	{
					loc y "ctr1_`x'_`i'"
				
					sum `y'
					loc m`i': di %3.2f r(mean)
					loc sd`i': di %3.2f r(sd)
					
					if "`x'" == "three_star" 	loc n`i' = r(N) //Have it flagged to use the star rated sample for Ns
					
				} //close i loop
					
				post `name' ("`ylab'") ("`m0'") ("(`sd0')") ("`m1'") ("(`sd1')") ("`m2'") ("(`sd2')") ("`m3'") ("(`sd3')") ("`m4'") ("(`sd4')") ("`m5'") ("(`sd5')")
				
			} //close x loop
			
			post `name' ("N") ("`n0'") ("") ("`n1'") ("") ("`n2'") ("") ("`n3'") ("") ("`n4'") ("") ("`n5'") ("")
			
			postclose `name'

			preserve
				use `file', clear
				export excel using "${path}\Tables\Table 1", replace
			restore

		
		//Table 2 - First stage estimates
		
		use "${path}\Generated datasets\Full dataset wide", clear
		
		capture program drop llr
		program llr
			args dv fv year samp title baseline

				tempname name
				tempfile file
				postfile `name' str25(coef Q BW0 BW1 BW2 BW3 TK) using `file' 
					
				//Set macros
					gl fv = "ctr1_fv_`fv'"
					gl cut = "ctr1_cut_`fv'"
					gl int = "ctr1_int_`fv'"
					gl fv_2 = "ctr1_fv_sq_`fv'"
					gl fv_int2 = "ctr1_int_sq_`fv'"
					
					loc z = "$fv $cut $int" //List of instruments
					loc z2 = "$fv $cut $int $fv_2 $fv_int2" //Including squared terms
				
					loc macros "cut" //fv_2 fv_int2
			
					loc controls "ctr1_ind_0 ctr1_lps_0 ctr1_hs_0 ctr1_rel_0 i.init_ERS_yr"
					loc sample "ctr1_`samp'"
					
					cap drop tk
					gen tk = max(0, 1-abs(${fv})) //Triangular kernel weight

					post `name' ("Bandwidth") ("Quadratic") ("Linear") ("1.5") ("1.25") ("1") ("Triangular kernel")	
				
				foreach y in `dv'	{
					
					if "`baseline'" == "base"	loc base "ctr1_`y'_0"
					
					//Full sample, quadratic estimates
						xi: reg ctr1_`y'_`year' `z2' `base' if `sample' ==1, robust
						macs "`macros'" TQ quadratic //linear estimates
					
					//Bandwidth restrictions
						loc c = 0
						foreach i in 2.5 1.5 1.25 1	{					
							
							loc bw_`c' "`i'"
							
							xi: reg ctr1_`y'_`year' `z' `base' if abs(${fv}) <= `i' & `sample' ==1, robust					
							macs "`macros'" T`c'L linear //linear estimates

							loc c `++c' //Increment counter
					
						} //close i loop
				
					//Triangular kernel
						xi: reg ctr1_`y'_`year' `z' `base' if `sample' ==1 [pw = tk], robust					
						macs "`macros'" TK linear //linear estimates
						
						foreach x in `macros'	{				
						
							post `name' ("`y'") ("${coef_TQ_`x'}") ("${coef_T0L_`x'}") ("${coef_T1L_`x'}") ("${coef_T2L_`x'}")	("${coef_T3L_`x'}")	("${coef_TK_`x'}")
							post `name' ("")	("(${se_TQ_`x'})") ("(${se_T0L_`x'})") ("(${se_T1L_`x'})") ("(${se_T2L_`x'})")	("(${se_T3L_`x'})") ("(${se_TK_`x'})")
					
						} //close x loop
				} //close y loop
				
				post `name' ("N") ("${N_TQ}") ("${N_T0L}") ("${N_T1L}") ("${N_T2L}") ("${N_T3L}") ("${N_TK}")
				
			postclose `name'
			macro drop b* se* t* stars* coef* N* AIC* F* //Clear out macros
			drop tk
			
			preserve
				use `file', clear
				export excel using "${path}\Tables/`title'", replace
			restore
				
		end //ends program llr
		
		llr "three_star four_star" 2	0  samp1 "Table 2" ""
		
		llr "three_star four_star noERS_open avgERS " 	2	5  samp1 "Table A5 - Panel A"  //These estimates don't have a column that includes controls
		llr "enroll prop_full" 							2	5  samp1 "Table A5 - Panel B" "base" 
		
		
		//Table 3
		use "${path}\Generated datasets\Full dataset wide", clear

		capture program drop rdaux // Must run "macs" above before running this
		program rdaux
			args dv type fv samp title
			
				tempname name
				tempfile file
				postfile `name' str25(var Q ) using `file' 
					
				//Set macros
					gl fv = "`type'_fv_`fv'"
					gl cut = "`type'_cut_`fv'"
					gl int = "`type'_int_`fv'"
					gl fv_2 = "`type'_fv_sq_`fv'"
					gl fv_int2 = "`type'_int_sq_`fv'"
					
					loc z2 = "$fv $cut $int $fv_2 $fv_int2" //Including squared terms			
					loc fe = "i.init_ERS_yr"
					
				foreach y in `dv'	{
					
					xi: reg `type'_`y'_0 `z2' if `type'_`y'_0 !=. & `samp', robust		
						macs "cut" T0Q quadratic //quadratic estimates


					post `name' ("`y'") ("${coef_T0Q_cut}") 
					post `name' ("")	("(${se_T0Q_cut})")
				
				} //Ends y loop
				
				post `name' ("N") ("${N_T0Q}")
				
			postclose `name'
			macro drop b* se* t* stars* coef* N* AIC* F* //Clear out macros
			
			preserve
				use `file', clear
				export excel using "${path}\Tables/`title'", replace
			restore
				
		end //ends program rdaux
		
		gl auxvars "ind lps hs rel oth"
	
		rdaux "$auxvars" 	ctr1 	2	ctr1_samp1 "Table 3"
	
	
	// Table 4 - Estimates do not include controls
		use "${path}\Generated datasets\Full dataset wide", clear

		capture program drop rdtab // Must run "macs" above before running this
		program rdtab
			args dv fv type fixed title baseline
			
				tempname name
				tempfile file
				postfile `name' str25(coef T T1 T2 T3 T4 T5) using `file' 
					
				//Set macros
					loc z2 = "`type'_fv_`fv' `type'_cut_`fv' `type'_int_`fv' `type'_fv_sq_`fv' `type'_int_sq_`fv'"
					loc postmacs "`type'_cut_2" //Coef/SEs you want to post in table
					
					loc controls "ctr1_ind_0 ctr1_lps_0 ctr1_hs_0 ctr1_rel_0 ctr1_oth_0"
					loc fe = "i.ERS_yr_1st"
					
				//Regression sequence
					foreach y in `dv'	{
						if "`baseline'" == "base" loc base "`type'_`y'_0" 
						
						forvalues i = 0/5	{	
							xi: reg `type'_`y'_`i' `base' `z2' if `type'_samp1==1, robust		
							mac_jr "`type'_cut_2" T`i'Q quadratic //quadratic estimates

						}
						
						foreach x in `postmacs'	{				
					
							post `name' ("`y'") ("${coef_T0Q_`x'}") ("${coef_T1Q_`x'}") ("${coef_T2Q_`x'}")	("${coef_T3Q_`x'}") ("${coef_T4Q_`x'}")	("${coef_T5Q_`x'}")
							post `name' ("")	("(${se_T0Q_`x'})") ("(${se_T1Q_`x'})") ("(${se_T2Q_`x'})")	("(${se_T3Q_`x'})") ("(${se_T4Q_`x'})")	("(${se_T5Q_`x'})")
							
							post `name' ("N") ("${N_T0Q}") ("${N_T1Q}") ("${N_T2Q}") ("${N_T3Q}") ("${N_T4Q}") ("${N_T5Q}")
							
						} //close x loop
				} //Ends y loop
		
			postclose `name'
			macro drop b* se* t* stars* coef* N* AIC* F* //Clear out macros
			
			preserve
				use `file', clear
				export excel using "${path}\Tables/`title'", replace
			restore
				
		end //ends program rdtab
		
		rdtab "three_star four_star avgERS" 2	ctr1	ERS_yr_1st	"Table 4 - Panel A"
		rdtab "enroll prop_full"			2	ctr1	ERS_yr_1st	"Table 4 - Panel B" "base" //Results that control for baseline values

	
	// Table 5
		use "${path}\Generated datasets\Full dataset wide", clear
		
		capture program drop hetero
		program hetero
		args dv type fv title baseline
		
		pause on
		loc samples "lowcomp hicomp "
		loc sampvars ""
		
		foreach x in `samples'	{
			loc sampvars "`sampvars' `x'_T1 `x'_T2 `x'_T3 `x'_T4 `x'_T5 "
		}
		
		tempname name
		tempfile file
		postfile `name' str25(var `sampvars') using `file' 
			
		//Set macros
			loc z2 = "`type'_fv_`fv' `type'_cut_`fv' `type'_int_`fv' `type'_fv_sq_`fv' `type'_int_sq_`fv'"
			
			foreach y in `dv'	{
				
				if "`baseline'" == "base"	loc base "`type'_`y'_0"
				loc controls "ctr1_ind_0 ctr1_lps_0 ctr1_hs_0 ctr1_rel_0 ctr1_oth_0"
				loc fe = "i.ERS_yr_1st"
				
				foreach x in `samples'	{
				
					loc samp = "`type'_`x'"
				
					forvalues i = 1/5	{	
						reg `type'_`y'_`i' `base' `z2' 	/*`controls' `fe'*/ if `samp' ==1, robust		
						mac_jr "`type'_cut_2" T`i'_`x' quadratic //quadratic estimates	
					
						count if `type'_`y'_`i' != . & `samp' ==1
						loc `x'_`i'_n = r(N)
					}

					loc `x'_co `"("${coef_T1_`x'_`type'_cut_2}") ("${coef_T2_`x'_`type'_cut_2}") ("${coef_T3_`x'_`type'_cut_2}") ("${coef_T4_`x'_`type'_cut_2}") ("${coef_T5_`x'_`type'_cut_2}") "' //Coefficient
					loc `x'_se `"("(${se_T1_`x'_`type'_cut_2})") ("(${se_T2_`x'_`type'_cut_2})") ("(${se_T3_`x'_`type'_cut_2})") ("(${se_T4_`x'_`type'_cut_2})") ("(${se_T5_`x'_`type'_cut_2})")"'
					loc `x'_n  `"("``x'_1_n'") ("``x'_2_n'") ("``x'_3_n'") ("``x'_4_n'") ("``x'_5_n'") "' //Sample size
					
				}
				
				loc coefs `" `samp1_co'  `lowcomp_co' `hicomp_co' "'
				loc SEs   `" `samp1_se'  `lowcomp_se' `hicomp_se' "'
				loc Ns    `" `samp1_n'   `lowcomp_n'  `hicomp_n'  "'
				
				post `name' ("`y'") `coefs'	
				post `name' ("") `SEs'
				
			} //Ends y loop
			
			post `name' ("N")  `Ns'
			
		postclose `name'
		macro drop b* se* t* stars* coef* N* AIC* F* //Clear out macros
		
		preserve
			use `file', clear
			browse
			export excel using "${path}\Tables/`title'", replace
		restore
			
	end //ends program rdest
	
	//High competition sample estimates slightly different than what these produce..noticed an error after submission that I was including 
	// providers with competition > median rather than >= median. Affected about 40 obs, doesn't change pattern/significance of results at all
		hetero "three_star four_star avgERS" ctr1 2 "Table 5 - Panel A"	
		hetero "enroll prop_full" 			 ctr1 2 "Table 5 - Panel B" "base"
	

	//Appendix A1
		use "${path}\Generated datasets\Full dataset wide", clear	

		tempname name
		tempfile file
		postfile `name' str60(var) str10(s2007 ns2007 space1 s2008 ns2008 space2 s2009 ns2009) using `file'
		
		loc dv6 "ind lps hs rel three_star four_star five_star noERS_open capacity enroll prop_full u5 "

		loc n = ""
		foreach x in `dv6' 	{

			loc yfull: variable label ctr1_`x'_5
			loc ylen = length("`yfull'")		
			loc ylab = substr("`yfull'", 1, `ylen'-9)
	
				forvalues i = 2007/2009	{
					loc y "`x'_`i'"
				
					ttest `y', by(ctr1_samp1)
					
						loc s_m`i': di %3.2f r(mu_2) //s for "sample"
						loc ns_m`i': di %3.2f r(mu_1) //ns for "non-sample"
						
						loc st`i' ""
						if r(p) <.10 	loc st`i' "+"
						if r(p) <.05	loc st`i' "*"
						if r(p) <.01	loc st`i' "**"
						if r(p) <.001	loc st`i' "***"
						
						if "`x'" == "capacity" 	{
							loc s_N`i' = r(N_2)
							loc ns_N`i' = r(N_1)
						}
					
				} //close i loop
				
			post `name' ("`ylab'") ("`s_m2007'") ("`ns_m2007'") ("") ("`s_m2008'") ("`ns_m2008'") ("") ("`s_m2009'") ("`ns_m2009'") 
			
		} //close x loop
		
		post `name' ("N") ("`s_N2007'") ("`ns_N2007'") ("") ("`s_N2008'") ("`ns_N2008'") ("") ("`s_N2009'") ("`ns_N2009'") 
		
		postclose `name'

		preserve
			use `file', clear
			export excel using "${path}\Tables\Table A1", replace
		restore

		
		
	//Appendix A2, A3, A4
		use "${path}\Generated datasets\Full dataset wide", clear
		
		capture program drop full_hi_low
		program full_hi_low
			args dv title baseline
			
			pause on
			loc samples "samp hicomp lowcomp"
			
			tempname name
			tempfile file
			postfile `name' str25(var T1 T2 T3 T4 T5) using `file' 
				
			//Set macros
				loc z2 = "ctr1_fv_2 ctr1_cut_2 ctr1_int_2 ctr1_fv_sq_2 ctr1_int_sq_2"
				loc cut "ctr1_cut_2"
				
				foreach y in `dv'	{
					
					foreach x in `samples'	{
					
						loc samp = "ctr1_`x'"
					
						forvalues i = 1/5	{	
							sum ctr1_`y'_`i'		if `samp' ==1
							gl mean_`i': di %3.2f r(mean)
	
							reg ctr1_`y'_`i'  `z2'  if `samp' ==1, robust		
							mac_jr "`cut'" T`i'_`x' quadratic //quadratic estimates					
						} //close i loop
						
						post `name' ("Mean") ("${mean_1}") 			  ("${mean_2}") 		   ("${mean_3}") 			("${mean_4}") 			 ("${mean_5}")
						post `name' ("Coef") ("${coef_T1_`x'_`cut'}") ("${coef_T2_`x'_`cut'}") ("${coef_T3_`x'_`cut'}") ("${coef_T4_`x'_`cut'}") ("${coef_T5_`x'_`cut'}")  //Coefficient
						post `name' ("SE") 	 ("(${se_T1_`x'_`cut'})") ("(${se_T2_`x'_`cut'})") ("(${se_T3_`x'_`cut'})") ("(${se_T4_`x'_`cut'})") ("(${se_T5_`x'_`cut'})")
						post `name' ("N") 	 ("${N_T1_`x'}") 		  ("${N_T2_`x'}") 		   ("${N_T3_`x'}") 		    ("${N_T4_`x'}") 		 ("${N_T5_`x'}")  //Sample size
											
					} // close x loop					
				} //Ends y loop
							
			postclose `name'
			macro drop mean* b* se* t* stars* coef* N* AIC* F* //Clear out macros
			
			preserve
				use `file', clear
				export excel using "${path}\Tables/`title'", replace
			restore
			
		end //ends program full_hi_low	
	
		full_hi_low "rerated"	  "Table A2"
		full_hi_low "closed"	  "Table A3" 
		full_hi_low "noERS_open"  "Table A4"
		
		
	//Table A6
		use "${path}\Generated datasets\Full dataset wide", clear		

		loc dvs "three_star four_star avgERS enroll prop_full" 

		mat table = J(1,11,.)
		
		foreach dv in `dvs'	{
			mat row = J(3,1,.)
			loc covs ""
			if "`dv'" == "enroll"		loc covs "covs(ctr1_enroll_0)"
			if "`dv'" == "prop_full"	loc covs "covs(ctr1_prop_full_0)"
			
			forvalues i = 1/5	{		
				
				rdrobust ctr1_`dv'_`i' ctr1_fv_2 , all  bwselect(msetwo) `covs'
				mat B = e(b)		
				mat V = e(V)
				
				loc N = e(N_b_l) + e(N_b_r)
				
				loc b = B[1,2]
				loc se = sqrt(V[2,2])
				
				loc b_round: di %4.2f (B[1,2])*-1 //Flipping signs to match our treatment assignment (i.e. < cutoff =1)
				loc se_round: di %4.2f sqrt(V[2,2])
				
				loc t = .
				if abs(`b'/`se') >= 1.645		loc t = 0
				if abs(`b'/`se') >= 1.96		loc t = 1
				if abs(`b'/`se') >= 2.58		loc t = 2
				if abs(`b'/`se') >= 3.29		loc t = 3
				
				mat cell = [[`b_round' \ `se_round' \ `N'] , [`t' \ . \ .] ]
				mat row = [row , cell]
				
			} //close i loop
			
			mat table = [table \ row]
			
		} // close dv loop
		
		loc rnames "blank"
		
		foreach dv in `dvs'	{
			loc rnames = "`rnames' `dv' se N" 
		}
		mat rownames table = `rnames'
		
		mat list table
		
		putexcel set  "${path}\Tables\Table A6.xlsx", replace
		putexcel A1 = matrix(table)
		

	//Table A7
		use "${path}\Generated datasets\Full dataset wide", clear
		loc dvs "three_star four_star avgERS enroll prop_full " 

		mat table = J(1,11,.)
		
		foreach dv in `dvs'	{
			mat row = J(3,1,.)
			loc covs ""
			if "`dv'" == "enroll"		loc covs "covs(ctr1_enroll_0)"
			if "`dv'" == "prop_full"	loc covs "covs(ctr1_prop_full_0)"
			
			forvalues i = 1/5	{		
				
				rdrobust ctr1_`dv'_`i' ctr1_fv_2 if ctr1_hicomp==1, all  bwselect(msetwo) `covs'
				mat B = e(b)		
				mat V = e(V)
				
				loc N = e(N_b_l) + e(N_b_r)
				
				loc b = B[1,2]
				loc se = sqrt(V[2,2])
					
				loc b_round: di %4.2f (B[1,2])*-1 //Flipping signs to match our treatment assignment (i.e. < cutoff =1)
				loc se_round: di %4.2f sqrt(V[2,2])
				
				loc t = .
				if abs(`b'/`se') >= 1.645	loc t = 0
				if abs(`b'/`se') >= 1.96		loc t = 1
				if abs(`b'/`se') >= 2.58		loc t = 2
				if abs(`b'/`se') >= 3.29		loc t = 3
				
				mat cell = [[`b_round' \ `se_round' \ `N'] , [`t' \ . \ .]]
				mat row = [row , cell]
				
			} //close i loop
			
			mat table = [table \ row]	
			
		} // close dv loop
		
		loc rnames "blank"
		
		foreach dv in `dvs'	{
			loc rnames = "`rnames' `dv' se N" 
		}
		mat rownames table = `rnames'
		
		putexcel set  "${path}\Tables\Table A7.xlsx", replace
		putexcel A1 = matrix(table), rownames

	
	
	**********************
	//Figures
	**********************
	
		//Figure 2
			use "${path}\Generated datasets\Full dataset wide", clear
		
			preserve
				loc fv "ctr1_fv_2"
				loc cut "ctr1_cut_2"			
				loc fvlabel: variable label `fv'

				keep if ctr1_samp1 ==1
				loc bin  ".1" //Bin width
				loc bandwidth = "& abs(`fv') <=1" //Bandwidth restriction of 1 around the RD cutoff

				count
				loc N = r(N)
				
				//Plot binned outcomes on either side of cut points
				
					//First, construct bins
					gen bin = `fv' - mod(`fv', `bin') + `bin'/2		
					sort bin
					egen tag = tag(bin) //Only need 1 observation since they are means

					//The plot them
					foreach dvstub in three_star four_star	{
					
						if "`dvstub'" == "three_star" 	loc dvtit "3+ stars"
						if "`dvstub'" == "four_star" 	loc dvtit "4+ stars"
						
						loc dv "ctr1_`dvstub'_0"
						egen `dv'_mean = mean(`dv'), by(bin) //construct binned outcomes
						
						xi: reg `dv' `fv' `cut' ctr1_int_2 ctr1_fv_sq_2 ctr1_int_sq_2 if ctr1_samp1==1 `bandwidth', robust		
						mac_jr "ctr1_cut_2" "`dvstub'" //run regressions to add into figures
					
						twoway  (scatter `dv'_mean bin if tag `bandwidth', msymbol(circle) msize(med) mcolor(black)) ///	
								(qfit `dv' `fv' if `fv' <0 `bandwidth', lwidth(medthick) lcolor(black)) ///
								(qfit `dv' `fv' if `fv' >=0 `bandwidth', lwidth(medthick) lcolor(black)), ///
									leg(off) xline(0, lcolor(black))  yscale(range(0 1)) ylab(0(.2)1)	 ///
									xtitle("Average ERS rating centered at 4.5") ytitle("p(`dvtit')")
						
						graph display, ysize(10) xsize(7.5)
						graph export "${path}\Figures/Figure 2 - `dvstub'.png", replace

					}
					
				restore
	
	
	//Figure 3a
		use "${path}\Generated datasets\Full dataset wide", clear

		capture program drop dist
		program dist
			args fv samp title
	
			loc bins ".05 .025"
			loc c = 0 //counter to be incremented
			
			count if `samp' ==1
			loc N = r(N)
					
			foreach bin in `bins'	{
			
				loc c `++c'
				
				if `c' == 1	{
	
					hist `fv' if `samp' ==1, start(2) width(`bin') ///
						fcolor(gs13) lcolor(gs6) xline(4.5, lcolor(black)) xlabel(2(.5)7) xtitle("Average ERS rating in baseline year") freq ytitle("Frequency") ///
						note("Bins are of size `bin'") nodraw
					 
					graph save "sample`c'", replace			
				}
				else if `c'==2 {

					hist `fv' if `fv' >=4.0 & `fv' < 5.0 & `samp'==1, start(4.0) width(`bin') ///
					 fcolor(gs13) lcolor(gs6) xline(4.5, lcolor(black)) xlabel(4.0(.25)5.0) xtitle("Average ERS rating in baseline year") freq  ytitle("Frequency") ///
					 note("Bins are of size `bin'")	 nodraw
				
					graph save "sample`c'", replace

				}
			}
			//7 10 	
			graph combine "sample1" "sample2", rows(2)
				
			graph export "${path}/Figures/Figure 3a.png", replace
			
			forvalues i = 1/2	{
				erase "sample`i'.gph"
			}
			
		end //Ends program "dist"
		
		dist  "ctr1_avgERS_0" 	"ctr1_samp1"		"All centers"	
		
		 
	//Figure 3b - Have to add label in manually (also doesn't save because of a space in the path, easily fixable)
		use "${path}\Generated datasets\Full dataset wide", clear
			
			gl densvars "Xj Yj r0 fhat se_fhat"
			
			capture program drop mccrary
			program mccrary
			args samp cut type
			
				if `cut' == 4.5 	loc cutsave "4_5"
				if `cut' == 4.75 	loc cutsave "4_75"
				
				cap drop $densvars
				DCdensity `type'_avgERS_0 if `type'_`samp', breakpoint(`cut') generate($densvars) graphname("${path}\Figures\Figure 3b.png")
		
			end //ends program mccrary
				
			//4.5 cutoff
				mccrary samp1 		4.5 ctr1
	
	
	// Figure 4a/4b
	use "${path}\Generated datasets\Full dataset wide", clear

		capture program drop rdfigs
		program rdfigs
			args type dvstub dvtit ytit fvnum samp ychars gtit

				preserve
					
					loc fv "ctr1_fv_2"
					loc fvlabel: variable label `fv'
					
					loc dv "`type'_`dvstub'"
					
					loc bin  ".1"
					loc bandwidth = "& abs(`fv') <=1"
					
					keep if `type'_`samp' ==1
					count
					loc N = r(N)
					
					//Plot binned outcomes on either side of cut points
					
						* First, construct bins
						gen bin = `fv' - mod(`fv',`bin') + `bin'/2		
						sort bin
						egen tag = tag(bin) //Only need 1 observation since they are means
						
						* Construct binned outcomes	

						forvalues i =0/5	{
							egen `dv'_`i'_mean = mean(`dv'_`i'), by(bin)
						}
						
						* Plot outcomes separately, then use graph combine
					
						forvalues i = 0/5	{
						
							if `i' ==0  loc tit "Initial rating year (T)"
							else		loc tit "T + `i'"
						
							twoway  (scatter `dv'_`i'_mean bin if tag `bandwidth', msymbol(circle) msize(small) mcolor(black)) ///	
										(qfit `dv'_`i' `fv' if `fv' <0 `bandwidth', lwidth(medthick) lcolor(black)) ///
										(qfit `dv'_`i' `fv' if `fv' >=0 `bandwidth', lwidth(medthick) lcolor(black)), ///
										leg(off) xline(0, lcolor(black))  `ychars' ///
										title("`tit'") xtitle("Average ERS rating") ytitle("`ytit'") ///
										saving("${path}\Figures\x_`i'", replace)
									
							graph export "${path}\Figures\x_`i'.png", replace
						}				
		
						cd "${path}\Figures"
	
						graph combine  x_0.gph x_1.gph x_2.gph x_3.gph x_4.gph x_5.gph
		
						graph export "${path}\Figures/`gtit'.png",  replace //width(1200) height(800)
				
						//Clean up temporary files
							forvalues i = 0/5	{
								cap erase "x_`i'.gph"
							}					
				restore
				
		end //ends program init_thru_6
	
		rdfigs ctr1 three_star	"3+ stars" 	"p(3+ stars)"   fv_2 	samp1 	"yscale(range(.4 1)) ylab(.4(.2)1)" "Figure 4a"
		rdfigs ctr1 four_star	"4+ stars" 	"p(4+ stars)"   fv_2 	samp1 	"yscale(range(0 1)) ylab(0(.2)1)"	"Figure 4b"
		
		
		//Figures 5, 6, A2
		capture program drop full_hi_low
		program full_hi_low
			args dvstub dvtit ytit ychars title1 title2 title3

				preserve
					
					version 12
					
					loc bin = .1
					loc band = 1
					loc delta = .5
					
					loc dv "ctr1_`dvstub'"
					loc fv "ctr1_fv_2"
					loc fvlabel: variable label `fv'
					
					loc setband "& abs(`fv') <= `band'"
					
					keep if ctr1_samp1 ==1
						count
						loc N = r(N)
					
					//Plot binned outcomes on either side of cut points
					
						foreach samp in samp1 hicomp lowcomp	{
						
							* First, construct bins
							gen bin_`samp' = `fv' - mod(`fv',`bin') + `bin'/2	if ctr1_`samp' ==1
							sort bin_`samp'
							egen tag_`samp' = tag(bin_`samp') //Only need 1 observation since they are means
							
							* Construct binned outcomes	
								egen `dv'_mean_`samp' = mean(`dv'_5), by(bin_`samp') 
							
							* Plot outcomes separately, then use graph combine				

							twoway  (scatter `dv'_mean_`samp' bin_`samp' if tag_`samp' `setband', msymbol(circle) msize(small) mcolor(black)) ///	
										(qfit `dv'_5 `fv' if `fv' <0 `setband' & ctr1_`samp' ==1, lwidth(medthick) lcolor(black)) ///
										(qfit `dv'_5 `fv' if `fv' >=0 `setband' & ctr1_`samp' ==1, lwidth(medthick) lcolor(black)), ///
										leg(off) xline(0, lcolor(black)) xscale(range(-`band' `band')) xlabel(-`band'(`delta')`band') `ychars' ///
										xtitle("Average ERS rating centered at 4.5") ytitle("`ytit'") ///
							
							if "`samp'" == "samp1" 		graph export "${path}\Figures/`title1'.png", replace  
							if "`samp'" == "hicomp" 	graph export "${path}\Figures/`title2'.png", replace
							//if "`samp'" == "lowcomp" 	graph export "${path}\Figures/`title3'.png", replace
							
						} //close samp loop		
							
				restore
				
		end //ends program full_hi_low

		full_hi_low avgERS 		"Average ERS rating"			"ERS rating" 		"yscale(range(4.5 5.5)) ylab(4.5(.5)5.5)" 	"Figure 5a" "Figure 6a"
		
		full_hi_low enroll		"Total enrollment" 				"Enrollment" 		"yscale(range(20 80)) ylab(20(20)80)" 		"Figure 5b" "Figure 6b"
		full_hi_low prop_full	"Proportion of capacity filled"	"Proportion filled"	"yscale(range(.4 1)) ylab(.4(.2)1)" 		"Figure 5c" "Figure 6c"
			
		full_hi_low closed		"Likelihood of closure"			"p(closed)"			"yscale(range(0 1)) ylab(0(.2)1)"			"Figure A2a" "Figure A2b"

		
	/*Extra tables/figures
	*****************************
	//Comparing opt ins to opt outs
	use "${path}\Generated datasets\Full dataset wide", clear
	
		tempname name
		tempfile file
		postfile `name' str60(var m0 sd0 m1 sd1 ) using `file'
				
			#delimit ;
			//Outcomes 2007-2014;
			loc dv6 "ind lps hs three_star four_star five_star capacity enroll prop_full u5 avgERS above_4_5";

			# delimit cr
			loc n = ""
			
			preserve
			//keep if abs(ctr1_fv_2 <=.5)	//Set bandwidth (if wanted)
			
			foreach x in `dv6' 	{
			
				loc yfull: variable label ctr1_`x'_5
				loc ylen = length("`yfull'")		
				loc ylab = substr("`yfull'", 1, `ylen'-9)
		
				sum ctr1_`x'_0 if ctr1_noERS_open_5 ==0
				loc m0: di %3.2f r(mean)
				loc sd0: di %3.2f r(sd)
				
				if "`x'" == "three_star" 	loc n0 = r(N) //Have it flagged to use the star rated sample for Ns
				
				sum ctr1_`x'_0 if ctr1_noERS_open_5 ==1
				loc m1: di %3.2f r(mean)
				loc sd1: di %3.2f r(sd)
				
				if "`x'" == "three_star" 	loc n1 = r(N) //Have it flagged to use the star rated sample for Ns

					
				post `name' ("`ylab'") ("`m0'") ("(`sd0')") ("`m1'") ("(`sd1')")
				
			} //close x loop
			
			post `name' ("N") ("`n0'") ("") ("`n1'") ("") 
			
			restore
			
			postclose `name'

			preserve
				use `file', clear
				export excel using "${path}\Tables\Compare opt in to opt out", replace
			restore
	

		