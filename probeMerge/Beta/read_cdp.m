function data=read_cdp(ncfile)
    % Read basic data from Convair netCDF files for the 2021 SPICULE field
    % campaign or other NCAR GV/C130 campaigns.  Put all relevant data into
    % a structure.
    %
    % See also holoDianostics_spicule.m and holoprep.m

    arguments
        ncfile string
    end

    finfo = ncinfo(ncfile);

    %% Get supporting data in netCDF file
    % Global attribute names sometimes change, need to update conditionals here to avoid Matlab errors
    globalnames = {finfo.Attributes(:).Name};
    data.flightnumber = upper(ncreadatt(ncfile, '/', 'FlightNumber'));
    data.flightdate = ncreadatt(ncfile, '/', 'FlightDate');
    if max(strcmp(globalnames, 'project')); data.project = ncreadatt(ncfile, '/', 'project'); end
    if max(strcmp(globalnames, 'ProjectName')); data.project = ncreadatt(ncfile, '/', 'ProjectName'); end
    if max(strcmp(globalnames, 'Platform')); data.aircraftname = ncreadatt(ncfile, '/', 'Platform'); end
    if max(strcmp(globalnames, 'platform')); data.aircraftname = ncreadatt(ncfile, '/', 'platform'); end
    data.time = ncread(ncfile,'Time');

    %Find CDP LWC (PLWCD_XXXX)
    data.endbins = ncreadatt(ncfile, 'CCDP_LWI', 'CellSizes');
    data.endbins = squeeze(data.endbins);
    data.midbins = (data.endbins(2:end) + data.endbins(1:end-1))./2;

    %Convert cdp conc to #/m4
    conc = ncread(ncfile,'CCDP_LWI');
    conc = permute(squeeze(conc),[2 1]);
    bw = (data.endbins(2:end) - data.endbins(1:end-1))*10^(-6); %convert to m
    data.conc = (conc*10^(6))./bw; %should now be units of #/m4

    %% REBIN 43.1  45.06 47.02
    % into 43.1  45.00 47.02
    old_endbins = [43.1  45.06 47.02];
    new_endbins = [43.1  45.00 47.02];
    old_midbins = (old_endbins(2:end) + old_endbins(1:end-1))./2;
    new_midbins = (new_endbins(2:end) + new_endbins(1:end-1))./2;

    %% Redistribute proportionally
    [~, idx_ends] = min(abs(data.endbins(:) - old_endbins(:).'), [], 1);
    [~, idx_mids] = min(abs(data.midbins(:) - old_midbins(:).'), [], 1);
    old_conc = data.conc(:,idx_mids);
    new_conc = zeros(size(old_conc));
    
    for i = 1:length(old_midbins)
        old_width = old_endbins(i+1) - old_endbins(i);

        for j = 1:length(new_midbins)
            overlap = min(old_endbins(i+1), new_endbins(j+1)) - ...
                      max(old_endbins(i), new_endbins(j));

            if overlap > 0
                fraction = overlap / old_width;
                new_conc(:,j) = new_conc(:,j) + old_conc(:,i) * fraction;
            end
        end
    end

    data.endbins(idx_ends) = new_endbins;
    data.midbins(idx_mids) = new_midbins;
    data.conc(:, idx_mids) = new_conc;

end


