function data=read_OAP(ncfile)
    % Put all relevant data into
    % a structure.

    arguments
        ncfile string
    end

    %% Get supporting data in netCDF file
    data.time = ncread(ncfile,'utc_time');
    data.endbins = ncread(ncfile, 'ENDBINS');
    data.midbins = ncread(ncfile, 'MIDBINS');  
    data.conc = ncread(ncfile, 'CONCENTRATION');  

end

