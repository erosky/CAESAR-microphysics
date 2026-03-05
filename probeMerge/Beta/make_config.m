function out = create_config(flightnumber)
% Set source locations for input probe data
% Modify as needed to match your directory structure
% verify that each source exists
% Set output file path
% Return error message if files don't exist.

% Set options for the output file:
% which processing tasks to perform
% use phase-ID to filter ice
% use phase-ID to filter cloud

arguments
    flightnumber string
end

% Processing options
options.bulk = 0; % Process bulk values: 1=yes, 0=no
options.PSD_phase = 0; % Perform PSD phase partition: 1=yes, 0=no

% Output netcdf file
outdir = "/home/utest/Research/CAESAR/Microphysics/DataProduct/";
outnc = outdir + flightnumber + "_microphysics_beta.nc";

% Data Sources
datadir = "/home/utest/Research/CAESAR/CAESAR_Data/";
source.aircraft_nc = datadir + "aircraft/" + flightnumber + ".nc";
source.cdp_nc = source.aircraft_nc;
source.holo_nc = "/home/utest/Research/CAESAR/Microphysics/DataProduct/holodecRebin/" + flightnumber + "_holo_composite.nc";
source.f2ds_nc = datadir + "OAP/F2DS_Compact/" + flightnumber + "_H.nc";
source.hvps_nc = datadir + "OAP/HVPS/" + flightnumber + "_HVPS.nc";
source.nev_nc = datadir + "nevzorov/" + flightnumber + "_nev.nc";
source.phase_id = "/home/utest/Research/CAESAR/Microphysics/Phase_ID/from_Nick/" + flightnumber + "_processed_phases_PRELIM.csv";

% Make output directory
if ~exist(outdir)
    status = mkdir(outdir);
end
% Add trailing slash to outdir if necessary
if (outdir(end) ~= '/')
    outdir = [outdir '/'];
end

% Check if input files exist

save("config","source","outnc","options")

end

