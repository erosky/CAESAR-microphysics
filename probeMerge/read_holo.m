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
    conc_full = ncread(ncfile, 'concentration_composite');
    conc = sum(conc_full,3);

    %% Isolate round particles
    % circularity dimensions [1 2 3 4 5 6] -> [0.5 0.6 0.7 0.8 0.9 1.0]
    sm_thresh = 26; %um
    lg_thresh = 45; %um
    sm_circ = 2; %0.5 circulatity threshold
    md_circ = 4; %0.7 circulatity threshold
    lg_circ = 5; %0.8 circulatity threshold

    % Find bin edges
    [sm, smix] = min(abs(data.midbins-sm_thresh));
    [lg, lgix] = min(abs(data.midbins-lg_thresh));

    conc_round = zeros(size(conc_full,1), size(conc_full,2));
    conc_round(:,1:smix) = sum(conc_full(:,1:smix,sm_circ:end),3);
    conc_round(:,smix:lgix) = sum(conc_full(:,smix:lgix,md_circ:end),3);
    conc_round(:,lgix:end) = sum(conc_full(:,lgix:end,lg_circ:end),3);

    %% Isolate ice particles
    conc_ice = zeros(size(conc_full,1), size(conc_full,2));
    conc_ice(:,1:smix) = sum(conc_full(:,1:smix,1),3);
    conc_ice(:,smix:lgix) = sum(conc_full(:,smix:lgix,1:md_circ-1),3);
    conc_ice(:,lgix:end) = sum(conc_full(:,lgix:end,1:lg_circ-1),3);

    %% 3 second moving average to increase sampling statistics
    movN = 5;
    data.conc = movmean(conc,movN,1); 
    data.conc_round = movmean(conc_round,movN,1); 
    data.conc_ice = movmean(conc_ice,movN,1); 

end


