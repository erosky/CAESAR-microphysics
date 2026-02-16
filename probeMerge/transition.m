function transition_values = transition(c1,c2)
%TRANSITION Summary of this function goes here
%   Detailed explanation goes here

bothzero = (c1 == 0) & (c2 == 0);
bothvalue = (c1 > 0) & (c2 > 0);

c1_value = length(nonzeros(c1));
c2_value = length(nonzeros(c2));

% Compute means if over half the crossover region has non-zero values for
% both probes
threshold = sum(bothvalue) / length(c1);

if threshold>=0.5
    c1(c1 == 0) = NaN; % Set Zeros To 1NaN1
    c2(c2 == 0) = NaN; % Set Zeros To 1NaN1
    combined = cat(3, c1, c2);

    transition_values = mean(combined, 3, 'omitnan');
    transition_values(bothzero) = 0;
elseif c1_value>c2_value
     transition_values = c1;
else transition_values = c2;
end

end

