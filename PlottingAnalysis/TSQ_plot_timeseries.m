% ------------------------------------------------------------------------------
% TSQ_plot_timeseries
% ------------------------------------------------------------------------------
% 
% Plots the time series read from a local file, in a specified format.
% 
%---INPUTS:
% whatData, The data to get information from: can be a structure, or 'norm' or
%           'cl' to load from HCTSA_N or HCTSA_cl
% whatTimeSeries, Can provide indices to plot that subset, a keyword to plot
%                   matches to the keyword, 'all' to plot all, or an empty vector
%                   to plot default groups in TimeSeries.Group
% numPerGroup, If plotting groups, plots this many examples per group
% maxLength, the maximum number of samples of each time series to plot
% displayTitles, shows time-series labels on the plot.
% plotOptions, additional plotting options as a structure.
% 
%----HISTORY:
% Previously called 'TSQ_plot_examples'
% Ben Fulcher, 9/4/2010
% Ben Fulcher, 13/5/2010 added F option (a matrix, 'norm', or 'cl')
% Ben Fulcher, 24/6/2010 added option to show examples from each class in
%                       kwgs, rather than all from the first class. In this
%                       case, <numPerGroup> means per class.
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

function TSQ_plot_timeseries(whatData,whatTimeSeries,numPerGroup,maxLength,plotOptions)

% ------------------------------------------------------------------------------
%% Check Inputs
% ------------------------------------------------------------------------------
% F -- get guide from 'norm' or 'cl'
if nargin < 1 || isempty(whatData)
    whatData = 'norm';
end

% Can specify a reduced set of time series by keyword
if nargin < 2
    whatTimeSeries = '';
end

if nargin < 3 || isempty(numPerGroup)
    % Default: plot 5 time series per group
    numPerGroup = 5;
end

if nargin < 4
    % Maximum length of time series to display (otherwise crops)
    % If empty, displays all of all time series
    maxLength = [];
end

if nargin < 5
	plotOptions = [];
end


% ------------------------------------------------------------------------------
% Evaluate any custom plotting options specified in the structure plotOptions
% ------------------------------------------------------------------------------

if isstruct(plotOptions) && isfield(plotOptions,'displayTitles')
    displayTitles = plotOptions.displayTitles;
else
    % Show titles -- removing them allows more to be fit into plot
    displayTitles = 1; % show titles by default
end
if isstruct(plotOptions) && isfield(plotOptions,'howToFilter')
    howToFilter = plotOptions.howToFilter;
else
    howToFilter = 'evenly'; % by default
end
if isstruct(plotOptions) && isfield(plotOptions,'gic')
    gic = plotOptions.gic; % local color labels -- vector
else
    gic = [];
end
% Specify the colormap to use
if isstruct(plotOptions) && isfield(plotOptions,'colorMap')
    colorMap = plotOptions.colorMap;
else
    colorMap = 'set1';
end
% Specify whether to make a free-form plot
if isstruct(plotOptions) && isfield(plotOptions,'plotFreeForm')
    plotFreeForm = plotOptions.plotFreeForm;
else
    plotFreeForm = 0; % do a normal subplotted figure
end
% Specify line width for plotting
if isstruct(plotOptions) && isfield(plotOptions,'LineWidth')
    lw = plotOptions.LineWidth;
else
    lw = 1; % do a normal subplotted figure
end

% ------------------------------------------------------------------------------
%% Load data
% ------------------------------------------------------------------------------
if isstruct(whatData)
    % Provide it all yourself
    TimeSeries = whatData.TimeSeries;
else    
    if strcmp(whatData,'cl')
        TheFile = 'HCTSA_cl.mat';
    elseif strcmp(whatData,'norm')
        TheFile = 'HCTSA_N.mat';
    end
    load(TheFile,'TimeSeries');
end


% ------------------------------------------------------------------------------
%% Get group indices:
% ------------------------------------------------------------------------------
if (isempty(whatTimeSeries) || strcmp(whatTimeSeries,'grouped')) && isfield(TimeSeries,'Group');
    % Use default groups
    GroupIndices = BF_ToGroup([TimeSeries.Group]);
    fprintf(1,'Plotting from %u groups of time series from file.\n',length(GroupIndices));
elseif isempty(whatTimeSeries) || strcmp(whatTimeSeries,'all')
    % Nothing specified but no groups assigned, or specified 'all': plot from all time series
    GroupIndices = {1:length(TimeSeries)};
elseif ischar(whatTimeSeries)
    % Just plot the specified group
    % First load group names:
    if isstruct(whatData)
        GroupNames = whatData.GroupNames;
    else
        load(TheFile,'GroupNames');
    end
    a = strcmp(whatTimeSeries,GroupNames);
    GroupIndices = {find([TimeSeries.Group]==find(a))};
    fprintf(1,'Plotting %u time series matching group name ''%s''\n',length(GroupIndices{1}),whatTimeSeries);
else % Provided a custom range as a vector
    GroupIndices = {whatTimeSeries};
    fprintf(1,'Plotting the %u time series matching indices provided\n',length(whatTimeSeries));
end
numGroups = length(GroupIndices);

% ------------------------------------------------------------------------------
%% Do the plotting
% ------------------------------------------------------------------------------
% Want numPerGroup from each time series group
iplot = zeros(numGroups*numPerGroup,1);
classes = zeros(numGroups*numPerGroup,1);
nhere = zeros(numGroups,1);
groupSizes = cellfun(@length,GroupIndices);
% howToFilter = 'rand';
for i = 1:numGroups
    % filter down to numPerGroup if too many in group, otherwise plot all in
    % group
    switch howToFilter
        case 'firstcome'
            % just plot first in group (useful when ordered by closeness to
            % cluster centre)
            jj = (1:min(numPerGroup,groupSizes(i)));
            
        case 'evenly'
            % Plot evenly spaced through the given ordering
            jj = unique(round(linspace(1,groupSizes(i),numPerGroup)));
            
        case 'rand'
            % select ones to plot at random
            if groupSizes(i) > numPerGroup
                jj = randperm(groupSizes(i)); % randomly selected
                if length(jj) > numPerGroup
                    jj = jj(1:numPerGroup);
                end
            else
                jj = (1:min(numPerGroup,groupSizes(i))); % retain order if not subsampling
            end
    end
    nhere(i) = length(jj); % could be less than numPerGroup if a smaller group
    rh = sum(nhere(1:i-1))+1:sum(nhere(1:i)); % range here
    iplot(rh) = GroupIndices{i}(jj);
    classes(rh) = i;
end

% Summarize time series chosen to plot
rkeep = (iplot > 0);
classes = classes(rkeep);
iplot = iplot(rkeep); % contains all the indicies of time series to plot (in order)
numToPlot = length(iplot);


fprintf(1,'Plotting %u (/%u) time series from %u classes\n', ...
                    numToPlot,sum(cellfun(@length,GroupIndices)),numGroups)
if ~isempty(gic)
    classes = gic; % override with our group information
    % better be firstcome, and makes sense that GroupIndices is just a vector of
    % indicies, otherwise group information is already available!
    if iscell(colorMap)
        theColors = colorMap; % specified custom colors as a cell
    else
        theColors = BF_getcmap(colorMap,max(classes),1); % 'set2'
    end
else
    if numGroups==1;
        theColors = {'k'}; % just plot in black
    else
        if iscell(colorMap)
            theColors = colorMap;
        else
            theColors = BF_getcmap(colorMap,numGroups,1); % 'set2'
        end
    end    
end

% ------------------------------------------------------------------------------
figure('color','w'); box('on');
Ls = zeros(numToPlot,1); % length of each plotted time series
if plotFreeForm
	% FREEFORM: make all within a single plot with text labels
    hold on;
	yr = linspace(1,0,numToPlot+1);
    inc = abs(yr(2)-yr(1)); % size of increment
    yr = yr(2:end);
	ls = zeros(numToPlot,1); % lengths of each time series
	if isempty(maxLength)
		for i = 1:numToPlot
			ls(i) = length(TimeSeries(iplot(i)).Data);
		end
		maxN = max(ls); % maximum length of all time series to plot
	else
		maxN = maxLength;
	end
	% Set up axes ticks
	set(gca,'XTick',linspace(0,1,3),'XTickLabel',round(linspace(0,maxN,3)))
	set(gca,'YTick',[],'YTickLabel',{})
	
	for i = 1:numToPlot
	    fn = TimeSeries(iplot(i)).FileName; % the filename
	    kw = TimeSeries(iplot(i)).Keywords; % the keywords
	    x = TimeSeries(iplot(i)).Data;
	    N0 = length(x);
		% rectangle('Position',[0,yr(i),1,inc],'EdgeColor','k')
		if ~isempty(maxN) && (N0 > maxN)
			% specified a maximum length of time series to plot
            sti = randi(N0-maxN,1);
			x = x(sti:sti+maxN-1); % subset random segment
            N = length(x);
        else
            N = N0; % length isn't changing
        end
		xx = (1:N) / maxN;
		xsc = yr(i) + 0.8*(x-min(x))/(max(x)-min(x)) * inc;
		
		plot(xx,xsc,'-','color',theColors{classes(i)},'LineWidth',lw)

	    % Annotate text labels
		if displayTitles
			theTit = sprintf('{%u} %s [%s] (%u)',TimeSeries(iplot(i)).ID,fn,kw,N0);
			text(0.01,yr(i)+0.9*inc,theTit,'interpreter','none','FontSize',8)
	    end
	end
	xlim([0,1]) % Don't let the axes annoyingly slip out
    xlabel('Time (samples)')
	
else
    % i.e., NOT a FreeForm plot:
	for i = 1:numToPlot
	    subplot(numToPlot,1,i)
	    fn = TimeSeries(iplot(i)).FileName; % the filename
	    kw = TimeSeries(iplot(i)).Keywords; % the keywords
	    x = TimeSeries(iplot(i)).Data;
	    N = length(x);
    
	    % Prepare text for the title
		if displayTitles
			startBit = sprintf('{%u} %s [%s]',TimeSeries(iplot(i)).ID,fn,kw);
	    end

	    % Plot the time series
	    if isempty(maxLength)
	        % no maximum length specified: plot the whole time series
	        plot(x,'-','color',theColors{classes(i)})
	        Ls(i) = N;
	        if displayTitles
	            title([startBit ' (' num2str(N) ')'],'interpreter','none','FontSize',8);
	        end
	    else
	        % Specified a maximum length of time series to plot: maxLength
	        if N <= maxLength
	            plot(x,'-','color',theColors{classes(i)});
	            Ls(i) = N;
	            if displayTitles
	                title([startBit ' (' num2str(N) ')'],'interpreter','none','FontSize',8);
	            end
	        else
	            sti = randi(N-maxLength,1);
	            plot(x(sti:sti+maxLength),'-','color',theColors{classes(i)}) % plot a random maxLength-length portion of the time series
	            Ls(i) = maxLength;
	            if displayTitles
	                title([startBit ' (' num2str(N) ' :: ' num2str(sti) '-' num2str(sti+maxLength) ')'],...
                                'interpreter','none','FontSize',8);
	            end
	        end
	    end
	    set(gca,'YTickLabel','');
	    if i~=numToPlot
	        set(gca,'XTickLabel','','FontSize',8) % put the ticks for the last time series
        else % label the axis
            xlabel('Time (samples)')
        end
	end
	
	% Set all xlims so that they have the same x-axis limits
	for i = 1:numToPlot
	    subplot(numToPlot,1,i); set(gca,'xlim',[1,max(Ls)])
	end
end


end