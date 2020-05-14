clc, clear all, close all;

    time = [.42, .55, 0.03];
    % available time
    x = rand();
    if x <=.42
        PSF_time = 10;
    elseif x>.42 && x<= .97
        PSF_time = 1;
    else
        PSF_time = .1;
    end
    
    %stress
    
    x = rand();
    if x <=.03
        PSF_stress = 5;
    elseif x>.03 && x<= .34
        PSF_stress = 2;
    else
        PSF_stress = 1;
    end
    
    %complexity
    x = rand();
    if x <=.11
        PSF_complexity = 5;
    elseif x>.11 && x<= .78
        PSF_complexity = 2;
    elseif x>.78 && x<= .92
        PSF_complexity  = 1;
    else
        PSF_complexity = 0.1;
    end
    
    %experience
    
    x = rand();
    if x <=.11
        PSF_experience = 10;
    elseif x>.11 && x<= .47
        PSF_experience = 1;
    else
        PSF_experience = .5;
    end
    
    
    %procedures
    x = rand();
    if x <=.06
        PSF_procedures = 50;
    elseif x>.06 && x<= .14
        PSF_procedures = 20;
    elseif x>.14 && x<= .20
        PSF_procedures  = 5;
    else
        PSF_procedures = 1;
    end
    
    %ergonomics
    
    x = rand();
    if x <=.36
        PSF_ergonomics = 50;
    elseif x>.36 && x<= .53
        PSF_ergonomics = 10;
    else
        PSF_ergonomics = 1;
    end
    
    PSF_fitness =1;
    
    %work_process
    
    x = rand();
    if x <=.11
        PSF_work_process = 2;
    elseif x>.11 && x<= .80
        PSF_work_process= 1;
    else
        PSF_work_process = .8;
    end
    
    HEP = (0.01*(PSF_complexity*PSF_ergonomics*PSF_experience*PSF_fitness*PSF_procedures*PSF_stress*PSF_time*PSF_work_process))/ ((0.01*((PSF_complexity*PSF_ergonomics*PSF_experience*PSF_fitness*PSF_procedures*PSF_stress*PSF_time*PSF_work_process)-1))+1);

HEP




























