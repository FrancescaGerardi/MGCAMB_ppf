    !     Code for Anisotropies in the Microwave Background
    !     by Antony Lewis (http://cosmologist.info/) and Anthony Challinor
    !     See readme.html for documentation. This is a sample driver routine that reads
    !     in one set of parameters and produdes the corresponding output.

    program driver
    use IniFile
    use CAMB
    use LambdaGeneral
    use Lensing
    use AMLUtils
    use Transfer
    use constants
    use Bispectrum
    use CAMBmain
    use NonLinear
!******************************
!* MGCAMB:
    use mgvariables
!******************************
#ifdef NAGF95
    use F90_UNIX
#endif
    implicit none

    Type(CAMBparams) P

    character(LEN=Ini_max_string_len) numstr, VectorFileName, &
        InputFile, ScalarFileName, TensorFileName, TotalFileName, LensedFileName,&
        LensedTotFileName, LensPotentialFileName,ScalarCovFileName
    integer i
    character(LEN=Ini_max_string_len) TransferFileNames(max_transfer_redshifts), &
        MatterPowerFileNames(max_transfer_redshifts), outroot, version_check
    real(dl) output_factor, nmassive

    !auxiliary variable for coupling bins
    character(LEN=Ini_max_string_len) binnum
#ifdef WRITE_FITS
    character(LEN=Ini_max_string_len) FITSfilename
#endif

    logical bad

    InputFile = ''
    if (GetParamCount() /= 0)  InputFile = GetParam(1)
    if (InputFile == '') error stop 'No parameter input file'

    call Ini_Open(InputFile, 1, bad, .false.)
    if (bad) error stop 'Error opening parameter file'

    Ini_fail_on_not_found = .false.

    outroot = Ini_Read_String('output_root')
    if (outroot /= '') outroot = trim(outroot) // '_'

    highL_unlensed_cl_template = Ini_Read_String_Default('highL_unlensed_cl_template',highL_unlensed_cl_template)

    call CAMB_SetDefParams(P)

    P%WantScalars = Ini_Read_Logical('get_scalar_cls')
    P%want_background = Ini_Read_Logical('get_background')
    P%WantVectors = Ini_Read_Logical('get_vector_cls',.false.)
    P%WantTensors = Ini_Read_Logical('get_tensor_cls',.false.)

    P%OutputNormalization=outNone
    output_factor = Ini_Read_Double('CMB_outputscale',1.d0)

    P%WantCls= P%WantScalars .or. P%WantTensors .or. P%WantVectors

    P%PK_WantTransfer=Ini_Read_Logical('get_transfer')

    AccuracyBoost  = Ini_Read_Double('accuracy_boost',AccuracyBoost)
    lAccuracyBoost = Ini_Read_Real('l_accuracy_boost',lAccuracyBoost)
    HighAccuracyDefault = Ini_Read_Logical('high_accuracy_default',HighAccuracyDefault)

    P%NonLinear = Ini_Read_Int('do_nonlinear',NonLinear_none)

    P%DoLensing = .false.
    if (P%WantCls) then
        if (P%WantScalars  .or. P%WantVectors) then
            P%Max_l = Ini_Read_Int('l_max_scalar')
            P%Max_eta_k = Ini_Read_Double('k_eta_max_scalar',P%Max_l*2._dl)
            if (P%WantScalars) then
                P%DoLensing = Ini_Read_Logical('do_lensing',.false.)
                if (P%DoLensing) lensing_method = Ini_Read_Int('lensing_method',1)
            end if
            if (P%WantVectors) then
                if (P%WantScalars .or. P%WantTensors) error stop 'Must generate vector modes on their own'
                i = Ini_Read_Int('vector_mode')
                if (i==0) then
                    vec_sig0 = 1
                    Magnetic = 0
                else if (i==1) then
                    Magnetic = -1
                    vec_sig0 = 0
                else
                    error stop 'vector_mode must be 0 (regular) or 1 (magnetic)'
                end if
            end if
        end if

        if (P%WantTensors) then
            P%Max_l_tensor = Ini_Read_Int('l_max_tensor')
            P%Max_eta_k_tensor =  Ini_Read_Double('k_eta_max_tensor',Max(500._dl,P%Max_l_tensor*2._dl))
        end if
    endif

    !  Read initial parameters.

    call DarkEnergy_ReadParams(DefIni)

    P%h0     = Ini_Read_Double('hubble')

!**************************************
!* MGCAMB mod:
!* reading models and params
!**************************************
model = Ini_Read_Int('model',0)
write(*,*) "---------------------"
write(*,*) "Model : ", model
write(*,*) "---------------------"
GRtrans= Ini_Read_Double('GRtrans',0.d0)

if (model ==1) then
B1= Ini_Read_Double('B1',0.d0)
B2= Ini_Read_Double('B2',0.d0)
lambda1_2= Ini_Read_Double('lambda1_2',0.d0)
lambda2_2= Ini_Read_Double('lambda2_2',0.d0)
ss= Ini_Read_Double('ss',0.d0)

else if (model ==2) then
MGQfix= Ini_Read_Double('MGQfix',1.d0)
MGRfix= Ini_Read_Double('MGRfix',1.d0)

else if (model ==3 ) then
Qnot= Ini_Read_Double('Qnot',1.d0)
Rnot= Ini_Read_Double('Rnot',1.d0)
sss = Ini_Read_Double('sss',0.d0)

else if (model ==4) then
B1 = 4.d0/3.d0
lambda1_2= Ini_Read_Double('B0',0.d0) ! it is considered as the B0 parameter here
lambda1_2 = (lambda1_2*(299792458.d-3)**2)/(2.d0*p%H0**2)
B2 = 0.5d0
lambda2_2 = B1* lambda1_2
ss = 4.d0

else if (model ==5) then
B1 = Ini_Read_Double('beta1',0.d0)
lambda1_2= Ini_Read_Double('B0',0.d0)
lambda1_2 = (lambda1_2*(299792458.d-3)**2)/(2.d0*p%H0**2)
B2 = 2.d0/B1 -1.d0
lambda2_2 = B1* lambda1_2
ss= Ini_Read_Double('s',0.d0)

else if (model ==6) then
Linder_gamma = Ini_Read_Double('Linder_gamma',0.d0)

! New models added in the last version
else if (model == 7) then
! SYMMETRON
beta_star = Ini_Read_Double('beta_star', 0.d0)
xi_star = Ini_Read_Double ('xi_star', 0.d0)
a_star = Ini_Read_Double('a_star', 0.d0)
GRtrans = a_star

else if (model == 8) then
! GENERALIZED DILATON
beta0 = Ini_Read_Double('beta0', 0.d0)
xi0 = Ini_Read_Double('xi0', 0.d0)
DilR = Ini_Read_Double('DilR', 0.d0)
DilS = Ini_Read_Double('DilS', 0.d0)

else if (model == 9) then
! HU SAWICKI MODEL
F_R0 = Ini_Read_Double('F_R0', 0.d0)
FRn = Ini_Read_Double('FRn', 0.d0)
beta0 = 1.d0/sqrt(6.d0)

else if (model ==10) then
! SIMPLE DILATON
beta0 = Ini_Read_Double('beta0', 0.d0)
A_2 = Ini_Read_Double('A2',0.d0)

!Planck-----------------------------------------
else if (model ==11) then
E11_mg = Ini_Read_Double('E11', 0.d0)
E22_mg = Ini_Read_Double('E22',0.d0)

else if (model ==12) then
E12_mg = Ini_Read_Double('E12', 0.d0)
E21_mg = Ini_Read_Double('E21',0.d0)
!-----------------------------------------------

!FGmod: non-parametric recosntrunction of mu and sigma------------------
else if (model==13) then
    !reading parameters for binning
    P%nbmg = Ini_Read_Int('num_bins_MG',1)
    P%mu0 = Ini_Read_Double('bin_mu_0',0._dl)
    P%sig0 = Ini_Read_Double('bin_sigma_0',0._dl)
    P%modemg = Ini_Read_Int('model_MG', 1)    

    if (.not.allocated(P%zbmg)) allocate(P%zbmg(P%nbmg),P%sb(P%nbmg), P%mb(P%nbmg),P%abmg(P%nbmg))
    do i=1,P%nbmg
       write(binnum,*) i
       P%abmg(i) = Ini_Read_Double('bin_a_MG_'//trim(adjustl(binnum)))
       P%mb(i) = Ini_Read_Double('bin_mu_'//trim(adjustl(binnum)),0._dl)
       P%sb(i) = Ini_Read_Double('bin_sigma_'//trim(adjustl(binnum)),0._dl)
    end do
    do i=1,P%nbmg
       P%zbmg(i)=-1+1._dl/(P%abmg(i))
    end do
    P%endredmg = P%zbmg(P%nbmg)

    if (P%zbmg(P%nbmg).gt.P%endredmg) then
       write(*,*) 'WARNING!!!'
       write(*,*) 'final redshift for MG functions (',P%endredmg,') is lower than last bin margin ',P%zbmg(P%nbmg)
       write(*,*) 'You need final redshift to be higher. Fix this and re-run the code. '
       stop
    end if

    !reading specific parameters for different models
    if (P%modemg.eq.2) P%ms= Ini_Read_Double('smooth_factor_mu',10._dl)
    if (P%modemg.eq.2) P%ss= Ini_Read_Double('smooth_factor_sigma',10._dl)

    if (P%modemg.eq.3) P%mcorr = Ini_Read_Double('correlation_length_mu',1._dl)
    if (P%modemg.eq.3) P%scorr = Ini_Read_Double('correlation_length_sigma',1._dl)    
    
    if (P%modemg.gt.3) then
       write(*,*) 'ONLY BINNED COUPLING AND GP IMPLEMENTED AT THE MOMENT'
       write(*,*) 'PLEASE WAIT FOR MORE FANCY STUFF!'
    end if
!-----------------------------------------------------------------------

else if (model /= 0) then
print*, '***please choose a model***'
stop
end if
!* MGCAMB mod end.
!*****************************************************

    if (Ini_Read_Logical('use_physical',.false.)) then
        P%omegab = Ini_Read_Double('ombh2')/(P%H0/100)**2
        P%omegac = Ini_Read_Double('omch2')/(P%H0/100)**2
        P%omegan = Ini_Read_Double('omnuh2')/(P%H0/100)**2
        P%omegav = 1- Ini_Read_Double('omk') - P%omegab-P%omegac - P%omegan
    else
        P%omegab = Ini_Read_Double('omega_baryon')
        P%omegac = Ini_Read_Double('omega_cdm')
        P%omegav = Ini_Read_Double('omega_lambda')
        P%omegan = Ini_Read_Double('omega_neutrino')
    end if

    !reading parameters for binning
    P%mode = Ini_Read_Int('model_bin',1)

    P%nb = Ini_Read_Int('num_bins',1)
    P%w0 = Ini_Read_Double('bin_w_0',0._dl)

    if (.not.allocated(P%zb)) allocate(P%zb(P%nb),P%wb(P%nb),P%ab(P%nb))
    do i=1,P%nb
       write(binnum,*) i
       P%ab(i) = Ini_Read_Double('bin_a_'//trim(adjustl(binnum)))
       P%wb(i) = Ini_Read_Double('bin_w_'//trim(adjustl(binnum)),0._dl)
    end do
    do i=1,P%nb
       P%zb(i)=-1+1._dl/(P%ab(i))
    end do
    P%endred = P%zb(P%nb)
    if (P%zb(P%nb).gt.P%endred) then
       write(*,*) 'WARNING!!!'
       write(*,*) 'final redshift for ODE (',P%endred,') is lower than last bin margin ',P%zb(P%nb)
       write(*,*) 'You need final redshift to be higher. Fix this and re-run the code. '
       stop
    end if


    !reading specific parameters for different models
    if (P%mode.eq.2) P%s= Ini_Read_Double('smooth_factor',10._dl)

    if (P%mode.eq.3) P%corrlen = Ini_Read_Double('correlation_length',1._dl)
    
    
    if (P%mode.gt.3) then
       write(*,*) 'ONLY BINNED COUPLING AND GP IMPLEMENTED AT THE MOMENT'
       write(*,*) 'PLEASE WAIT FOR MORE FANCY STUFF!'
    end if


    P%tcmb   = Ini_Read_Double('temp_cmb',COBE_CMBTemp)
    P%yhe    = Ini_Read_Double('helium_fraction',0.24_dl)
    P%Num_Nu_massless  = Ini_Read_Double('massless_neutrinos')

    P%Nu_mass_eigenstates = Ini_Read_Int('nu_mass_eigenstates',1)
    if (P%Nu_mass_eigenstates > max_nu) error stop 'too many mass eigenstates'

    numstr = Ini_Read_String('massive_neutrinos')
    read(numstr, *) nmassive
    if (abs(nmassive-nint(nmassive))>1e-6) error stop 'massive_neutrinos should now be integer (or integer array)'
    read(numstr,*, end=100, err=100) P%Nu_Mass_numbers(1:P%Nu_mass_eigenstates)
    P%Num_Nu_massive = sum(P%Nu_Mass_numbers(1:P%Nu_mass_eigenstates))

    if (P%Num_Nu_massive>0) then
        P%share_delta_neff = Ini_Read_Logical('share_delta_neff', .true.)
        numstr = Ini_Read_String('nu_mass_degeneracies')
        if (P%share_delta_neff) then
            if (numstr/='') write (*,*) 'WARNING: nu_mass_degeneracies ignored when share_delta_neff'
        else
            if (numstr=='') error stop 'must give degeneracies for each eigenstate if share_delta_neff=F'
            read(numstr,*) P%Nu_mass_degeneracies(1:P%Nu_mass_eigenstates)
        end if
        numstr = Ini_Read_String('nu_mass_fractions')
        if (numstr=='') then
            if (P%Nu_mass_eigenstates >1) error stop 'must give nu_mass_fractions for the eigenstates'
            P%Nu_mass_fractions(1)=1
        else
            read(numstr,*) P%Nu_mass_fractions(1:P%Nu_mass_eigenstates)
        end if
    end if

    !JD 08/13 begin changes for nonlinear lensing of CMB + LSS compatibility
    !P%Transfer%redshifts -> P%Transfer%PK_redshifts and P%Transfer%num_redshifts -> P%Transfer%PK_num_redshifts
    !in the P%WantTransfer loop.
    if (((P%NonLinear==NonLinear_lens .or. P%NonLinear==NonLinear_both) .and. P%DoLensing) &
        .or. P%PK_WantTransfer) then
    P%Transfer%high_precision=  Ini_Read_Logical('transfer_high_precision',.false.)
    else
        P%transfer%high_precision = .false.
    endif
    if (P%NonLinear/=NonLinear_none) call NonLinear_ReadParams(DefIni)

    if (P%PK_WantTransfer)  then
        P%WantTransfer  = .true.
        P%transfer%kmax          =  Ini_Read_Double('transfer_kmax')
        P%transfer%k_per_logint  =  Ini_Read_Int('transfer_k_per_logint')
        P%transfer%PK_num_redshifts =  Ini_Read_Int('transfer_num_redshifts')

        transfer_interp_matterpower = Ini_Read_Logical('transfer_interp_matterpower', transfer_interp_matterpower)
        transfer_power_var = Ini_read_int('transfer_power_var',transfer_power_var)
        if (P%transfer%PK_num_redshifts > max_transfer_redshifts) error stop 'Too many redshifts'
        do i=1, P%transfer%PK_num_redshifts
            P%transfer%PK_redshifts(i)  = Ini_Read_Double_Array('transfer_redshift',i,0._dl)
            transferFileNames(i)     = Ini_Read_String_Array('transfer_filename',i)
            MatterPowerFilenames(i)  = Ini_Read_String_Array('transfer_matterpower',i)
            if (TransferFileNames(i) == '') then
                TransferFileNames(i) =  trim(numcat('transfer_',i))//'.dat'
            end if
            if (MatterPowerFilenames(i) == '') then
                MatterPowerFilenames(i) =  trim(numcat('matterpower_',i))//'.dat'
            end if
            if (TransferFileNames(i)/= '') &
                TransferFileNames(i) = trim(outroot)//TransferFileNames(i)
            if (MatterPowerFilenames(i) /= '') &
                MatterPowerFilenames(i)=trim(outroot)//MatterPowerFilenames(i)
        end do
    else
        P%Transfer%PK_num_redshifts = 1
        P%Transfer%PK_redshifts = 0
    end if

    if ((P%NonLinear==NonLinear_lens .or. P%NonLinear==NonLinear_both) .and. P%DoLensing) then
        P%WantTransfer  = .true.
        call Transfer_SetForNonlinearLensing(P%Transfer)
    end if

    call Transfer_SortAndIndexRedshifts(P%Transfer)
    !JD 08/13 end changes

    P%transfer%kmax=P%transfer%kmax*(P%h0/100._dl)

    Ini_fail_on_not_found = .false.

    DebugParam = Ini_Read_Double('DebugParam',DebugParam)
    ALens = Ini_Read_Double('Alens',Alens)

    call Reionization_ReadParams(P%Reion, DefIni)
    call InitialPower_ReadParams(P%InitPower, DefIni, P%WantTensors)
    call Recombination_ReadParams(P%Recomb, DefIni)
    if (Ini_HasKey('recombination')) then
        i = Ini_Read_Int('recombination',1)
        if (i/=1) error stop 'recombination option deprecated'
    end if

    call Bispectrum_ReadParams(BispectrumParams, DefIni, outroot)

    if (P%WantScalars .or. P%WantTransfer) then
        P%Scalar_initial_condition = Ini_Read_Int('initial_condition',initial_adiabatic)
        if (P%Scalar_initial_condition == initial_vector) then
            P%InitialConditionVector=0
            numstr = Ini_Read_String('initial_vector',.true.)
            read (numstr,*) P%InitialConditionVector(1:initial_iso_neutrino_vel)
        end if
        if (P%Scalar_initial_condition/= initial_adiabatic) use_spline_template = .false.
    end if

    if (P%WantScalars) then
        ScalarFileName = trim(outroot)//Ini_Read_String('scalar_output_file')
        LensedFileName =  trim(outroot) //Ini_Read_String('lensed_output_file')
        LensPotentialFileName =  Ini_Read_String('lens_potential_output_file')
        if (LensPotentialFileName/='') LensPotentialFileName = concat(outroot,LensPotentialFileName)
        ScalarCovFileName =  Ini_Read_String_Default('scalar_covariance_output_file','scalCovCls.dat',.false.)
        if (ScalarCovFileName/='') then
            has_cl_2D_array = .true.
            ScalarCovFileName = concat(outroot,ScalarCovFileName)
        end if
    end if
    if (P%WantTensors) then
        TensorFileName =  trim(outroot) //Ini_Read_String('tensor_output_file')
        if (P%WantScalars)  then
            TotalFileName =  trim(outroot) //Ini_Read_String('total_output_file')
            LensedTotFileName = Ini_Read_String('lensed_total_output_file')
            if (LensedTotFileName/='') LensedTotFileName= trim(outroot) //trim(LensedTotFileName)
        end if
    end if
    if (P%WantVectors) then
        VectorFileName =  trim(outroot) //Ini_Read_String('vector_output_file')
    end if

#ifdef WRITE_FITS
    if (P%WantCls) then
        FITSfilename =  trim(outroot) //Ini_Read_String('FITS_filename',.true.)
        if (FITSfilename /='') then
            inquire(file=FITSfilename, exist=bad)
            if (bad) then
                open(unit=18,file=FITSfilename,status='old')
                close(18,status='delete')
            end if
        end if
    end if
#endif


    Ini_fail_on_not_found = .false.

    !optional parameters controlling the computation

    P%AccuratePolarization = Ini_Read_Logical('accurate_polarization',.true.)
    P%AccurateReionization = Ini_Read_Logical('accurate_reionization',.false.)
    P%AccurateBB = Ini_Read_Logical('accurate_BB',.false.)
    P%DerivedParameters = Ini_Read_Logical('derived_parameters',.true.)

    version_check = Ini_Read_String('version_check')
    if (version_check == '') then
        !tag the output used parameters .ini file with the version of CAMB being used now
        call TNameValueList_Add(DefIni%ReadValues, 'version_check', version)
    else if (version_check /= version) then
        write(*,*) 'WARNING: version_check does not match this CAMB version'
    end if
    !Mess here to fix typo with backwards compatibility
    if (Ini_HasKey('do_late_rad_trunction')) then
        DoLateRadTruncation = Ini_Read_Logical('do_late_rad_trunction',.true.)
        if (Ini_HasKey('do_late_rad_truncation')) error stop 'check do_late_rad_xxxx'
    else
        DoLateRadTruncation = Ini_Read_Logical('do_late_rad_truncation',.true.)
    end if

    if (HighAccuracyDefault) then
        DoTensorNeutrinos = .true.
    else
        DoTensorNeutrinos = Ini_Read_Logical('do_tensor_neutrinos',DoTensorNeutrinos )
    end if
    FeedbackLevel = Ini_Read_Int('feedback_level',FeedbackLevel)

    output_file_headers = Ini_Read_Logical('output_file_headers',output_file_headers)

    P%MassiveNuMethod  = Ini_Read_Int('massive_nu_approx',Nu_best)

    ThreadNum      = Ini_Read_Int('number_of_threads',ThreadNum)
    use_spline_template = Ini_Read_Logical('use_spline_template',use_spline_template)

    if (do_bispectrum) then
        lSampleBoost   = 50
    else
        lSampleBoost   = Ini_Read_Double('l_sample_boost',lSampleBoost)
    end if
    if (outroot /= '') then
        if (InputFile /= trim(outroot) //'params.ini') then
            call Ini_SaveReadValues(trim(outroot) //'params.ini',1)
        else
            write(*,*) 'Output _params.ini not created as would overwrite input'
        end if
    end if

    call Ini_Close

    if (.not. CAMB_ValidateParams(P)) error stop 'Stopped due to parameter error'

#ifdef RUNIDLE
    call SetIdle
#endif

    if (global_error_flag==0) call CAMB_GetResults(P)
    if (global_error_flag/=0) then
        write(*,*) 'Error result '//trim(global_error_message)
        error stop
    endif

    if (P%PK_WantTransfer) then
        call Transfer_SaveToFiles(MT,TransferFileNames)
        call Transfer_SaveMatterPower(MT,MatterPowerFileNames)
        call Transfer_output_sig8(MT)
    end if

    if (P%WantCls) then
        call output_cl_files(ScalarFileName, ScalarCovFileName, TensorFileName, TotalFileName, &
            LensedFileName, LensedTotFilename, output_factor)

        call output_lens_pot_files(LensPotentialFileName, output_factor)

        if (P%WantVectors) then
            call output_veccl_files(VectorFileName, output_factor)
        end if

#ifdef WRITE_FITS
        if (FITSfilename /= '') call WriteFitsCls(FITSfilename, CP%Max_l)
#endif
    end if

    call CAMB_cleanup
    stop

100 stop 'Must give num_massive number of integer physical neutrinos for each eigenstate'
    end program driver


#ifdef RUNIDLE
    !If in Windows and want to run with low priorty so can multitask
    subroutine SetIdle
    USE DFWIN
    Integer dwPriority
    Integer CheckPriority

    dwPriority = 64 ! idle priority
    CheckPriority = SetPriorityClass(GetCurrentProcess(), dwPriority)

    end subroutine SetIdle
#endif
