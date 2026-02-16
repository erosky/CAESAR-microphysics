function [conc, conc_err] = PSD_merge(flightnumber, timestamps)
% Read in required files
% OUTPUTS:
% composite DSD best estimate
% mean uncertainty

%% Read in aircraft file
try
    make_config(flightnumber);
catch
    disp("Error in make_config")
    return %stop script if config doesnt work
end
load("config","source")

if exist(source.cdp_nc, 'file')
    cdp = read_cdp(source.cdp_nc);
    % endbins, midbins, conc, date, time
end
if exist(source.holo_nc, 'file')
    holo = read_holo(source.holo_nc);
    % endbins, midbins, conc, nt
end
if exist(source.f2ds_nc, 'file')
    f2ds = read_f2ds(source.f2ds_nc);
    % endbins, midbins, conc
end
if exist(source.hvps_nc, 'file')
    hvps = read_OAP(source.hvps_nc);
    % endbins, midbins, conc
end

%% Read in composite bin data (requires bins.mat file in same directory)
create_bins();
load("bins","probe_endbins","probe_midbins");
endbins = probe_endbins.composite;
binwidth = endbins(2:end) - endbins(1:end-1);
midbins = probe_midbins.composite;

%% Masks
cdp_mask = ismembertol(midbins,probe_midbins.fixed_cdp); % composite bins that are used
cdp_idx = ismembertol(cdp.midbins,probe_midbins.fixed_cdp); % cdp bins that are used

holo_mask = ismembertol(midbins,probe_midbins.fixed_holo);% composite bins that are used
holo_idx = ismembertol(holo.midbins,probe_midbins.fixed_holo); % holo bins that are used

f2ds_mask = ismembertol(midbins,probe_midbins.fixed_f2ds); % composite bins that are used
f2ds_idx = ismembertol(f2ds.midbins,probe_midbins.fixed_f2ds); % f2ds bins that are used

hvps_mask = ismembertol(midbins,probe_midbins.fixed_hvps); % composite bins that are used
hvps_idx = ismembertol(hvps.midbins,probe_midbins.fixed_hvps); % hvps bins that are used

cdp_holo_mask = ismembertol(midbins,probe_midbins.crossover_cdp_holo); % cdp holodec crossover
holo_f2ds_mask = ismembertol(midbins,probe_midbins.crossover_holo_f2ds); % holodec f2ds crossover
f2ds_hvps_mask = ismembertol(midbins,probe_midbins.crossover_f2ds_hvps); % f2ds hvps crossover

%% Set up count/concentration variables
conc= zeros(length(timestamps), length(midbins));
conc_err = zeros(length(timestamps), length(midbins));

%% Fill in each timestamp
for t=1:length(timestamps)
    time_1Hz = timestamps(t);
    [conc_t, err_t] = composite_1Hz(time_1Hz);
    conc(t,:)=conc_t;
    conc_err(t,:)=err_t;
end

%% Function
function [conc_best_t, conc_err_t]=composite_1Hz(t)
    time_idx.cdp = cdp.time == t;
    time_idx.holo = holo.time == t;
    time_idx.f2ds = f2ds.time == t;
    time_idx.hvps = hvps.time == t;
 
    conc_best_t= zeros(1, length(midbins));
    conc_err_t = zeros(1, length(midbins));

    %% Determine data availability (timestamp exists, non-nan)
    exists.cdp = 0;
    exists.holo = 0;
    exists.f2ds = 0;
    exists.hvps = 0;

    probes = fieldnames(exists);
    for i = 1:numel(probes)
        probeName = probes{i};
        timecheck = sum(time_idx.(probeName))==1;
        switch probeName
            case "cdp"
                nancheck = any(isnan(cdp.conc(time_idx.cdp,:)), 'all');
            case "holo"
                nancheck = any(isnan(holo.conc(time_idx.holo,:)), 'all'); % | all(holo.conc(time_idx.holo,:)==0);
            case "f2ds"
                nancheck = any(isnan(f2ds.conc(time_idx.f2ds,:)), 'all');
            case probeName=="hvps"
                nancheck = any(isnan(hvps.conc(time_idx.hvps,:)), 'all');
        end
        if timecheck & ~nancheck
            exists.(probeName)=1;
        end
    end
  
    %% Calculate cdp/holodec uncertainty
    if exists.cdp & exists.holo
        cdp_holo_err = calculate_uncertainty(cdp.conc(time_idx.cdp,ismembertol(cdp.midbins,probe_midbins.overlap_cdp_holo)),...
                                            holo.conc(time_idx.holo,ismembertol(holo.midbins,probe_midbins.overlap_cdp_holo)));
    else cdp_holo_err = 0;
    end

    %% Calculate holodec/f2ds uncertainty
    if exists.holo & exists.f2ds
        holo_f2ds_err = calculate_uncertainty(f2ds.conc(time_idx.f2ds,ismembertol(f2ds.midbins,probe_midbins.overlap_holo_f2ds)),...
                                            holo.conc(time_idx.holo,ismembertol(holo.midbins,probe_midbins.overlap_holo_f2ds)));
    else holo_f2ds_err = 0;
    end

    %% Calculate f2ds/hvps uncertainty
    if exists.f2ds & exists.hvps
        f2ds_hvps_err = calculate_uncertainty(f2ds.conc(time_idx.f2ds,ismembertol(f2ds.midbins,probe_midbins.overlap_f2ds_hvps)),...
                                            hvps.conc(time_idx.hvps,ismembertol(hvps.midbins,probe_midbins.overlap_f2ds_hvps)));
    else f2ds_hvps_err = 0;
    end

    % Take max uncertainty for f2ds
    f2ds_err = max([holo_f2ds_err,f2ds_hvps_err]);
    
    %% Fill in CDP fixed range
    if exists.cdp
        conc_best_t(cdp_mask) = cdp.conc(time_idx.cdp,cdp_idx);
    % Fill with NaN if data is unavailable
    else conc_best_t(cdp_mask) = NaN;
    end
    % assign error
    conc_err_t(cdp_mask) = cdp_holo_err;
    
    %% Fill in Holodec fixed range
    if exists.holo
        conc_best_t(holo_mask) = holo.conc(time_idx.holo,holo_idx);
    % Use CDP as backup
    elseif exists.cdp
        conc_best_t(holo_mask) = cdp.conc(time_idx.cdp,holo_idx);
    % Fill with NaN if data is unavailable
    else conc_best_t(holo_mask) = NaN;     
    end
    % assign error
    conc_err_t(holo_mask) = cdp_holo_err;

    %% Fill in CDP HOLODEC crossover values
    if exists.cdp & exists.holo
        conc_best_t(cdp_holo_mask)=transition(holo.conc(time_idx.holo,ismembertol(holo.midbins,probe_midbins.crossover_cdp_holo)),...
                                                cdp.conc(time_idx.cdp,ismembertol(cdp.midbins,probe_midbins.crossover_cdp_holo)));
    % Use backup if one probe is unavailable
    elseif exists.cdp & ~exists.holo
        conc_best_t(cdp_holo_mask)=cdp.conc(time_idx.cdp,ismembertol(cdp.midbins,probe_midbins.crossover_cdp_holo));
    elseif ~exists.cdp & exists.holo
        conc_best_t(cdp_holo_mask)=holo.conc(time_idx.holo,ismembertol(holo.midbins,probe_midbins.crossover_cdp_holo));
    % Fill with NaN if data is unavailable
    else conc_best_t(cdp_holo_mask) = NaN;   
    end
    % assign error
    conc_err_t(cdp_holo_mask) =  cdp_holo_err;
     
    %% Fill in HOLODEC F2DS crossover values
    if exists.holo & exists.f2ds
        conc_best_t(holo_f2ds_mask)=transition(holo.conc(time_idx.holo,ismember(holo.midbins,probe_midbins.crossover_holo_f2ds)),...
                                                f2ds.conc(time_idx.f2ds,ismember(f2ds.midbins,probe_midbins.crossover_holo_f2ds)));
    % Use backup if one probe is unavailable
    elseif exists.f2ds & ~exists.holo
        conc_best_t(holo_f2ds_mask)=f2ds.conc(time_idx.f2ds,ismember(f2ds.midbins,probe_midbins.crossover_holo_f2ds));
    elseif ~exists.f2ds & exists.holo
        conc_best_t(holo_f2ds_mask)=holo.conc(time_idx.holo,ismember(holo.midbins,probe_midbins.crossover_holo_f2ds))
    % Fill with NaN if data is unavailable
    else conc_best_t(holo_f2ds_mask) = NaN;   
    end
    % assign error
    conc_err_t(holo_f2ds_mask) = holo_f2ds_err;
   
    %% Fill in F2DS values
    if exists.f2ds
        conc_best_t(f2ds_mask) = f2ds.conc(time_idx.f2ds,f2ds_idx);
    % Fill with NaN if data is unavailable
    else conc_best_t(f2ds_mask) = NaN
    end
    % assign error
    conc_err_t(f2ds_mask) = f2ds_err;

    %% Fill in F2DS HVPS crossover values
    if exists.f2ds & exists.hvps
        conc_best_t(f2ds_hvps_mask)=transition(f2ds.conc(time_idx.f2ds,ismember(f2ds.midbins,probe_midbins.crossover_f2ds_hvps)),...
                                                hvps.conc(time_idx.hvps,ismember(hvps.midbins,probe_midbins.crossover_f2ds_hvps)));
    elseif exists.f2ds & ~exists.hvps
        conc_best_t(f2ds_hvps_mask)=f2ds.conc(time_idx.f2ds,ismember(f2ds.midbins,probe_midbins.crossover_f2ds_hvps));
    elseif ~exists.f2ds & exists.hvps
        conc_best_t(f2ds_hvps_mask)=hvps.conc(time_idx.hvps,ismember(hvps.midbins,probe_midbins.crossover_f2ds_hvps));
    else conc_best_t(f2ds_hvps_mask)=NaN;
    end
    % assign error
    conc_err_t(f2ds_hvps_mask) = f2ds_hvps_err;
    
    %% Fill in HVPS values
    if exists.hvps
        conc_best_t(hvps_mask) = hvps.conc(time_idx.hvps,hvps_idx);
    else conc_best_t(hvps_mask) = NaN;
    end
    % assign error
    conc_err_t(hvps_mask) = 0;
end

end
