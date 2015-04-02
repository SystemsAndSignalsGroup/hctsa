% ------------------------------------------------------------------------------
% IN_AutoMutualInfoStats
% ------------------------------------------------------------------------------
% 
% Returns statistics on the automutual information function computed on the time
% series
% 
%---INPUTS:
% y, column vector of time series data
% 
% maxTau, maximal time delay
% 
% estMethod, extraParam -- cf. inputs to IN_AutoMutualInfo.m
% 
%---OUTPUTS:
% Statistics on the AMIs and their pattern across the range of specified time
% delays
% 
%---HISTORY:
% Ben Fulcher, 2009
% ------------------------------------------------------------------------------
% Copyright (C) 2013,  Ben D. Fulcher <ben.d.fulcher@gmail.com>,
% <http://www.benfulcher.com>
%
% If you use this code for your research, please cite:
% B. D. Fulcher, M. A. Little, N. S. Jones, "Highly comparative time-series
% analysis: the empirical structure of time series and their methods",
% J. Roy. Soc. Interface 10(83) 20130048 (2010). DOI: 10.1098/rsif.2013.0048
%
% This function is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, either version 3 of the License, or (at your option) any later
% version.
% 
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
% details.
% 
% You should have received a copy of the GNU General Public License along with
% this program.  If not, see <http://www.gnu.org/licenses/>.
% ------------------------------------------------------------------------------

function out = IN_AutoMutualInfoStats(y,maxTau,estMethod,extraParam)

% ------------------------------------------------------------------------------
%% Preliminaries
% ------------------------------------------------------------------------------
N = length(y); % length of time series

% ------------------------------------------------------------------------------
%% Check Inputs
% ------------------------------------------------------------------------------

% maxTau: the maximum time delay to investigate
if nargin < 2 || isempty(maxTau)
    maxTau = ceil(N/4);
end
maxTau0 = maxTau;

% Don't go above N/2
maxTau = min(maxTau,ceil(N/2));

% estimation method:
if nargin < 3
    estMethod = '';
end

% extraParam
if nargin < 4
    extraParam = [];
end

% ------------------------------------------------------------------------------
%% Get the AMI data:
% ------------------------------------------------------------------------------
ami = IN_AutoMutualInfo(y,1:maxTau,estMethod,extraParam);

% Convert structure to a vector
ami = struct2cell(ami);
ami = [ami{:}];

% ------------------------------------------------------------------------------
% Output the raw values:
% ------------------------------------------------------------------------------
for i = 1:maxTau0
    if i <= maxTau
        out.(sprintf('ami%u',i)) = ami(i);
    else % we've trimmed the maximum back because time series is too short
        out.(sprintf('ami%u',i)) = NaN;
    end
end

% ------------------------------------------------------------------------------
% Output statistics:
% ------------------------------------------------------------------------------
lami = length(ami);

% Mean and std of automutual information over this range of time delays:
out.mami = mean(ami);
out.stdami = std(ami);

% First minimum of mutual information across range
dami = diff(ami);
extremai = find(dami(1:end-1).*dami(2:end) < 0);
out.pextrema = length(extremai)/(lami-1);
if isempty(extremai)
    out.fmmi = lami; % actually represents lag, because indexes don't but diff delays by 1
else
    out.fmmi = min(extremai);
end

% Look for periodicities in local maxima
maximai = find(dami(1:end-1) > 0 & dami(2:end) < 0) + 1;
dmaximai = diff(maximai);
% is there a big peak in dmaxima?
 % (no need to normalize since a given method inputs its range; but do it anyway... ;-))
out.pmaxima = length(dmaximai)/floor(lami/2);
out.modeperiodmax = mode(dmaximai);
out.pmodeperiodmax = sum(dmaximai == mode(dmaximai))/length(dmaximai);

% Same for local minima
% Look for periodicities in local maxima
minimai = find(dami(1:end-1) < 0 & dami(2:end) > 0) + 1;
dminimai = diff(minimai);
% is there a big peak in dmaxima?
 % (no need to normalize since a given method inputs its range; but do it anyway... ;-))
out.pminima = length(dminimai)/floor(lami/2);
out.modeperiodmin = mode(dminimai);
out.pmodeperiodmin = sum(dminimai == mode(dminimai))/length(dminimai);

% number of crossings at mean/median level, percentiles
out.pcrossmean = sum(BF_sgnchange(ami-mean(ami)))/(lami-1);
out.pcrossmedian = sum(BF_sgnchange(ami-median(ami)))/(lami-1);
out.pcrossq10 = sum(BF_sgnchange(ami-quantile(ami,0.1)))/(lami-1);
out.pcrossq90 = sum(BF_sgnchange(ami-quantile(ami,0.9)))/(lami-1);

% ac1
out.amiac1 = CO_AutoCorr(ami,1,'Fourier');

end