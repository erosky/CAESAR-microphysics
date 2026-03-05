function fnout = createMicrophysics(flightnumber)
    % Create a netcdf file containing value-added microhysics data.
    % 
    % Beta Version
    % Feb 12, 2026
    %
    % source: Input data source paths are specified inside "make_config.m" 
    % outnc:  Path for output netcdf is specified inside "make_config.m"
    % options: Options for processing may be specified inside "make_config.m"
    % 
    %
    % Example:
    %    fn = createMicrophysics('RF01')
    %
    % Dependencies: make_config.m, create_bins.m
    % read_ncar_aircraft.m
    % read_phaseID.m, read_nevzorov.m
    % PSD_merge_1Hz.m
    % PSD_phase_partition_1Hz.m
    % read_cdp.m, read_holo.m, read_f2ds.m, read_OAP.m

    arguments
        flightnumber string
    end

    %% Read in config data (modify this by editing the make_config.m script)
    try
        make_config(flightnumber);
    catch
        disp("Error in make_config")
        return %stop script if config doesnt work
    end
    
    version = 'beta';
    load("config","source","outnc","options")
    disp(outnc)
    
    %% Get supporting aircraft data
    flightdate = ncreadatt(source.aircraft_nc, '/', 'FlightDate')  %This works for all projects so far, may need to change later       
    ac = read_ncar_aircraft(source.aircraft_nc)
    nctime = ac.nctime;

    %% Set up bulk/concentration variables
    % Create and read in bin data
    create_bins();
    load("bins","probe_endbins","probe_midbins")
    endbins = probe_endbins.composite;
    binwidth = endbins(2:end) - endbins(1:end-1);
    midbins = probe_midbins.composite;
     
    phase_id = NaN(1, length(nctime));
    conc = zeros(length(nctime), length(midbins));
    conc_err = zeros(length(nctime), length(midbins));

    if options.PSD_phase ~= 0
        concround = zeros(length(nctime), length(midbins));
        concice = zeros(length(nctime), length(midbins));
        concround_err = zeros(length(nctime), length(midbins));
        concice_err = zeros(length(nctime), length(midbins));
    end
    if options.bulk ~= 0
        lwc = zeros(1, length(nctime));
        twc = zeros(1, length(nctime));
        iwc = zeros(1, length(nctime));  
        lwc_err = zeros(1, length(nctime));
        %twc_err = zeros(1, length(nctime));
        %iwc_err = zeros(1, length(nctime));
    end

    %% Set up the netCDF file
    cmode = netcdf.getConstant('NETCDF4');
    if exist(outnc, 'file') 
       delete(outnc)
    end
    ncid = netcdf.create(outnc, cmode);

    % Dimensions
    nctime_dimid = netcdf.defDim(ncid, 'time', length(nctime));
    midbins_dimid = netcdf.defDim(ncid, 'bin_centers', length(midbins));
    endbins_dimid = netcdf.defDim(ncid, 'bin_edges', length(endbins));

    % Variables and attributes
    ncdfprops = {'time', 'UTC time for concentration arrays and bulk variables', 'Seconds from midnight of start date', nctime_dimid;
        'bin_edges', 'Upper/lower edges of concentration size bins', 'microns', endbins_dimid;
        'bin_centers', 'Center value of concentration size bins', 'microns', midbins_dimid;
        'concentration', 'Best estimate of particle number concentration, all particles, normalized by bin width', '#/m4', [nctime_dimid, midbins_dimid];
        'concentration_err', 'Uncertainty bound on particle number concentration, all particles, normalized by bin width', '#/m4', [nctime_dimid, midbins_dimid];
        'lat', 'Latitude', 'degrees North', nctime_dimid;
        'lon', 'Longitude', 'degrees East', nctime_dimid;
        'alt', 'GPS Altitude', 'meters', nctime_dimid;
        't', 'Ambient Temperature', 'C', nctime_dimid};
    if options.bulk ~= 0
        % Add bulk variables
        ncdfprops(end+1:end+5,:) = ...
        {'lwc', 'Best estimate of liquid water content', 'g/m3', nctime_dimid;
        'twc', 'Best estimate of total water content', 'g/m3', nctime_dimid;
        'iwc', 'Best estimate of ice water content', 'g/m3', nctime_dimid;
        'lwc_err', 'Uncertainty bound on liquid water content', 'g/m3', nctime_dimid};
    end
    if options.PSD_phase ~= 0
        % Add PSD phase partitioning
        ncdfprops(end+1:end+5,:) = ...
        {'concentration_round', 'Best estimate of particle number concentration, round particles, normalized by bin width', '#/m4', [nctime_dimid, midbins_dimid];
        'concentration_ice', 'Best estimate of particle number concentration, ice particles, normalized by bin width', '#/m4', [nctime_dimid, midbins_dimid];
        'concentration_round_err', 'Uncertainty bound on particle number concentration, round particles, normalized by bin width', '#/m4', [nctime_dimid, midbins_dimid];
        'concentration_ice_err', 'Uncertainty bound on particle number concentration, ice particles, normalized by bin width', '#/m4', [nctime_dimid, midbins_dimid]};
    end

    for i = 1:length(ncdfprops)
        varid = netcdf.defVar(ncid, ncdfprops{i,1}, 'NC_DOUBLE', ncdfprops{i,4});
        netcdf.putAtt(ncid, varid, 'longname', ncdfprops{i,2});
        netcdf.putAtt(ncid, varid, 'units', ncdfprops{i,3});
        netcdf.defVarDeflate(ncid, varid, true, true, 5);   %Turn on compression
    end

    % Special case for cloud phase variable
    varid_phaseID = netcdf.defVar(ncid, 'cloud_phase', 'NC_INT', nctime_dimid);
    netcdf.putAtt(ncid, varid_phaseID, 'longname', 'Estimate of cloud phase identification using algorithm');
    netcdf.putAtt(ncid, varid_phaseID, 'units', 'none');
    netcdf.putAtt(ncid, varid_phaseID, 'flag_values', [0 1 2 3 4],'NC_INT');
    netcdf.putAtt(ncid, varid_phaseID, 'flag_meaning', ['clear' 'ice' 'mixed' 'liquid' 'drizzle']);
    netcdf.defVarDeflate(ncid, varid_phaseID, true, true, 5);   %Turn on compression

    % Write global attributes
    % Version, date created, Source, contact
    varid = netcdf.getConstant('NC_GLOBAL');  %Need to set for global atts
    netcdf.putAtt(ncid, varid, 'ProductName', 'Cloud Microphysics Value-Added Data Product');
    netcdf.putAtt(ncid, varid, 'Version', version);
    netcdf.putAtt(ncid, varid, 'Source', 'CDP, F2DS, HOLODEC, HVPS, Nevzorov');
    netcdf.putAtt(ncid, varid, 'DataContact', 'Elise Rosky (emrosky@ucar.edu) or EOL Sarah Woods');
    netcdf.putAtt(ncid, varid, 'FlightDate', flightdate);
    netcdf.putAtt(ncid, varid, 'ProjectName', ac.project);
    netcdf.putAtt(ncid, varid, 'Platform', ac.aircraftname);
    netcdf.putAtt(ncid, varid, 'FlightNumber', ac.flightnumber);
    netcdf.putAtt(ncid, varid, 'date_created', string(datetime('today'), 'yyyy/MM/dd'));
    netcdf.endDef(ncid);  

    %% Enter data mode

    % Write time and bin sizes
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'time'), nctime)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'bin_centers'), midbins)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'bin_edges'), endbins)

    %% Input phase id data
    % For all nctime, match with phaseidtime and create array
    phase_data = read_phaseID(source.phase_id);
    [tf_ph, loc_ph] = ismember(nctime, phase_data.time);
    phase_id(tf_ph) = phase_data.phase(loc_ph(tf_ph));


    %% Calculate composite distribution
    [conc, conc_err] = PSD_merge_beta(flightnumber,nctime);

    %% TESTS
    size(nctime)
    size(phase_id)
    size(conc)
    size(conc_err)
    size(ac.aircraft.lat)

    %% Write concentration and bulk to netCDF
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'lat'), ac.aircraft.lat)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'lon'), ac.aircraft.lon)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'alt'), ac.aircraft.alt)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 't'), ac.aircraft.t)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'cloud_phase'), phase_id)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'concentration'), conc)
    netcdf.putVar(ncid, netcdf.inqVarID(ncid, 'concentration_err'), conc_err)
    % if options.PSD_phase ~= 0
    % end
    % if options.PSD_phase ~= 0
    % end

    netcdf.close(ncid);
end