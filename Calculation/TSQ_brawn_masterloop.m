% ------------------------------------------------------------------------------
% TSQ_brawn_masterloop
% ------------------------------------------------------------------------------
% 
% Function used in a loop by TSQ_brawn to evaluate a given master function.
% 
% ------------------------------------------------------------------------------
% Copyright (C) 2013,  Ben D. Fulcher <ben.d.fulcher@gmail.com>,
% <http://www.benfulcher.com>
% 
% If you use this code for your research, please cite:
% B. D. Fulcher, M. A. Little, N. S. Jones, "Highly comparative time-series
% analysis: the empirical structure of time series and their methods",
% J. Roy. Soc. Interface 10(83) 20130048 (2010). DOI: 10.1098/rsif.2013.0048
% 
% This work is licensed under the Creative Commons
% Attribution-NonCommercial-ShareAlike 3.0 Unported License. To view a copy of
% this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send
% a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View,
% California, 94041, USA.
% ------------------------------------------------------------------------------

function [masterOutput, masterTime] = TSQ_brawn_masterloop(x, y, masterCode, masterID, numMasterOps, fid, beVocal, theTsID)

if beVocal
    % Display code name for error checking
    fprintf(fid,'[ts_id = %u, mop_id = %u / %u] %s...', theTsID, masterID, numMasterOps, masterCode);
end

try
	masterTimer = tic;
    if beVocal
        % Any output text is printed to screen
    	masterOutput = BF_pareval(x,y,masterCode,1);
    else
        % Output text stored in T (could log this if you really want to)
        [masterOutput, T] = BF_pareval(x,y,masterCode,0);
    end
	masterTime = toc(masterTimer);
    if beVocal
        fprintf(1,' evaluated (%s).\n',BF_thetime(masterTime))
    end
	% For not-applicable/'real NaN', masterOutput is a NaN, otherwise a
	% structure with components to be called below by pointer operations.
    
catch emsg
    if beVocal
        fprintf(1,' error.\n') % ,BF_thetime(masterTime)
    end
	fprintf(fid,'---Error evaluating %s:\n%s\n',masterCode,emsg.message);
    masterOutput = {}; % Keep empty output
    masterTime = 0; % Set zero calculation time
	% Remains an empty cell entry.
end

end