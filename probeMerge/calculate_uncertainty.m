function assigned_err = calculate_uncertainty(Arg1,Arg2)

assigned_err = 0;
overlap_length = length(Arg1);

nonvalue = (abs(Arg1) < 0.01) | (abs(Arg2) < 0.01); % either of the probes have a zero in the bin
Arg1(nonvalue) = []; % remove points where either of the probes have a zero, 
Arg2(nonvalue) = []; % leaving only places where both probes have non-zero measurement

% Compute uncertainty if over half the crossover region has non-zero values for
% both probes
threshold = length(Arg1) / overlap_length;

if threshold>=0.5
    diff = abs(Arg1-Arg2);
    meanerr = mean(diff, 'all');
    assigned_err = meanerr;
end

end

