function data=read_nevzorov(ncfile)
    % Put all relevant data into
    % a structure.

    arguments
        ncfile string
    end

    %% Get supporting data in netCDF file
    data.time = ncread(ncfile,'Time');
    data.lwc = ncread(ncfile, 'Nev_LWC');
    data.twc = ncread(ncfile, 'Nev_TWC');  
    lwc_flag = ncread(ncfile, 'Nev_LWC_Flag');  
    twc_flag = ncread(ncfile, 'Nev_TWC_Flag'); 

    % create undertainty arrays
    data.lwc_err = zeros(length(data.time),1);
    data.twc_err = zeros(length(data.time),1);
    data.iwc_err = zeros(length(data.time),1);

    %% Filter out bad/uncertain data using flags
    data.lwc(lwc_flag>=4) = NaN;
    data.twc(twc_flag>=4) = NaN;

    %% Assume that if LWC>TWC it is because small droplets are missed, set TWC=LWC in such cases
    data.twc(data.twc<data.lwc) = data.lwc(data.twc<data.lwc);

    %% Assume that if LWC<0 or TWC<0 it is equal to zero
    data.twc(data.twc<0) = 0.0;
    data.lwc(data.lwc<0) = 0.0;

    %% Uncertainty bound on lwc is the max of 10% or 0.01
    data.lwc_err(lwc_flag==3) = 0.02;
    data.twc_err(twc_flag==3) = 0.02;
    data.lwc_err(lwc_flag<=2) = 0.01;
    data.twc_err(twc_flag<=2) = 0.01;
    per_lwc = 0.1*data.lwc;
    per_twc = 0.1*data.twc;
    data.lwc_err = max(data.lwc_err, per_lwc);
    data.twc_err = max(data.twc_err, per_twc);
     
    %% Calculate IWC where data is good
    data.iwc = data.twc-data.lwc;
    % % uncertainty added in quanderature
    squared = data.lwc_err.^2 + data.twc_err.^2;
    data.iwc_err = sqrt(squared);

end

