function data = read_phaseID(csvfile)
%READ_PHASEID Summary of this function goes here
%   Detailed explanation goes here
T = readtable(csvfile);
data.time = T.time;
data.phase = T.phase;
end

