function data=read_f2ds(ncfile)
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

    %% REBIN 700.  800.  900. 1000. 1200. 1400. 1600. 1800. 2000.
    % into 700  825  975  1125   1275  1425  1575  1725  1875

    old_endbins = [700.  800.  900. 1000. 1200. 1400. 1600. 1800. 2000.];
    new_endbins = [700.  825.  975.  1125.   1275.  1425.  1575.  1725.  1875.];
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

