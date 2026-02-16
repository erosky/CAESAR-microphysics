function data=read_ncar_aircraft(ncfile, refvar)
    % Read basic data from NCAR GV/C130 campaigns.  
    % Put all relevant data into a structure.
    %
    % See also holoDianostics_spicule.m and holoprep.m

    arguments
        ncfile string
        refvar string = "none"
    end

    %Set large time range and return if no aircraft data
    if ~isfile(ncfile)
       data.timerange = [datetime(2000,1,1), datetime(2100,1,1)];
       return
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
    data.ncfile = ncfile;
    nctime = ncread(ncfile,'Time');
    data.nctime = nctime;
    aircraft.tas = ncread(ncfile,'TASX');
    aircraft.t = ncread(ncfile,'ATX');
    aircraft.w = ncread(ncfile,'WIC');
    aircraft.lat = ncread(ncfile, 'GGLAT');
    aircraft.lon = ncread(ncfile, 'GGLON');
    aircraft.alt = ncread(ncfile, 'GGALT');

    %Find CDP LWC (PLWCD_XXXX)
    cdplwc = [];
    cdplwc2 = [];   %Some projects have two CDPs on board
    numcdps = 0;
    for i = 1:length(finfo.Variables)
        if (length(finfo.Variables(i).Name) >= 6)...
                && (finfo.Variables(i).Name(1:6) == "PLWCD_")
            if numcdps == 0
                cdplwc = ncread(ncfile, finfo.Variables(i).Name);
            end
            if numcdps == 1
                cdplwc2 = ncread(ncfile, finfo.Variables(i).Name);
            end
            numcdps = numcdps + 1;
        end
    end

    %fulltime = datenum(data.flightdate,'mm/dd/yyyy') + double(nctime)./86400;
    %Time in datetime format, need to get the 'epoch' (start date) first
    epochtime = datetime(data.flightdate, 'InputFormat','MM/dd/yyyy');
    fulltime = datetime(nctime, 'ConvertFrom', 'epochtime', 'Epoch', epochtime);

    data.aircraft = aircraft;
end
