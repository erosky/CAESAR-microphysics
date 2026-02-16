function data=read_holo(ncfile)
    % Put all relevant data into
    % a structure.

    arguments
        ncfile string
    end

    finfo = ncinfo(ncfile);

    %% Get supporting data in netCDF file
    data.ncfile = ncfile;
    data.time = ncread(ncfile,'time');
    data.endbins = ncread(ncfile, 'bin_edges');
    data.midbins = ncread(ncfile, 'bin_centers');  
    data.nt = ncread(ncfile, 'nt');

    %% Compress across circularity dimension
    conc = ncread(ncfile, 'concentration_composite');
    conc = sum(conc,3);

    movN = 3;
    data.conc = movmean(conc,movN,1); 

end


