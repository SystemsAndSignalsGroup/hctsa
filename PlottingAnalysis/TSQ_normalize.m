% --------------------------------------------------------------------------
% TSQ_normalize
% --------------------------------------------------------------------------
% 
% Reads in data from HCTSA_loc.mat, writes a trimmed, normalized version to
% HCTSA_loc_N.mat
% The normalization is all about a rescaling to the [0,1] interval for
% visualization and clustering.
% 
%---INPUTS:
% normFunction: String specifying how to normalize the data.
% 
% filterOptions: Vector specifying thresholds for the minimum proportion of bad
%                values tolerated in a given row or column, in the form of a 2-vector:
%                [row proportion, column proportion] If one of the filterOptions
%                is set to 1, will have no bad values in your matrix.
%                
% fileName_HCTSA_loc: Custom filename to import. Default is 'HCTSA_loc.mat'.
% 
% subs [opt]: Only normalize and trim a subset of the data matrix. This can be used,
%             for example, to analyze just a subset of the full space, which can
%             subsequently be clustered and further subsetted using TS_cluster2...
%             For example, can choose a subset using SUB_autolabel2 to get only sound
%             time series.
%             subs in the form {[rowrange],[columnrange]} (rows and columns to
%             keep, from HCTSA_loc).
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

function TSQ_normalize(normFunction,filterOptions,fileName_HCTSA_loc,subs,trainset)

% --------------------------------------------------------------------------
%% Check Inputs
% --------------------------------------------------------------------------
if nargin < 1 || isempty(normFunction)
    fprintf(1,'Using the default, scaled quantile-based sigmoidal transform: ''scaledSQzscore''\n')
    normFunction = 'scaledSQzscore';
end

if nargin < 2 || isempty(filterOptions)
    filterOptions = [0.80, 1];
    % By default remove less than 80%-good-valued time series, & then less than 
    % 100%-good-valued operations.
end
fprintf(1,['Removing time series with more than %.2f%% special-valued outputs\n' ...
            'Removing operations with more than %.2f%% special-valued outputs\n'], ...
            (1-filterOptions(1))*100,(1-filterOptions(2))*100);

% By default, work with a file called HCTSA_loc.mat, as obtained from
% TSQ_prepared...
if nargin < 3 || isempty(fileName_HCTSA_loc)
    fileName_HCTSA_loc = 'HCTSA_loc.mat';
end

if nargin < 4
    % Empty by default, i.e., don't subset:
    subs = {};
end

if nargin < 5
    % Empty by default: get normalization parameters using the full set
    trainset = [];
end

% --------------------------------------------------------------------------
%% Read data from local files
% --------------------------------------------------------------------------
fprintf(1,'Reading data from %s...',fileName_HCTSA_loc);
load(fileName_HCTSA_loc,'TS_DataMat','TS_Quality','TimeSeries','Operations','MasterOperations')
fprintf(1,' Loaded.\n');

% In this script, each of these pieces of data (from the database) will be trimmed and normalized
% then saved to HCTSA_N.mat

% ------------------------------------------------------------------------------
%% Subset using given indices, subs
% ------------------------------------------------------------------------------
if ~isempty(subs)
    kr0 = subs{1}; % rows to keep (0)
    if isempty(kr0),
        kr0 = 1:size(TS_DataMat,1);
    else
        fprintf(1,'Filtered down time series by given subset; from %u to %u.\n',...
                    size(TS_DataMat,1),length(kr0))
        TS_DataMat = TS_DataMat(kr0,:);
        TS_Quality = TS_Quality(kr0,:);
    end
    
    kc0 = subs{2}; % columns to keep (0)
    if isempty(kc0),
        kc0 = 1:size(TS_DataMat,2);
    else
        fprintf(1,'Filtered down operations by given subset; from %u to %u.\n',...
            size(TS_DataMat,2),length(kc0))
        TS_DataMat = TS_DataMat(:,kc0);
        TS_Quality = TS_Quality(:,kc0);
    end
else
    kr0 = 1:size(TS_DataMat,1);
    kc0 = 1:size(TS_DataMat,2);
end


% --------------------------------------------------------------------------
%% Trim down bad rows/columns
% --------------------------------------------------------------------------

% (i) NaNs in TS_DataMat mean values uncalculated in the matrix.
TS_DataMat(~isfinite(TS_DataMat)) = NaN; % Convert all nonfinite values to NaNs for consistency
% Need to also incorporate knowledge of bad entries in TS_Quality and filter these out:
TS_DataMat(TS_Quality > 0) = NaN;
fprintf(1,'There are %u special values in the data matrix.\n',sum(TS_Quality(:) > 0))
% Now all bad values are NaNs, and we can get on with the job of filtering them out

% (*) Filter based on proportion of bad entries. If either threshold is 1,
% the resulting matrix is guaranteed to be free from bad values entirely.
[badr, badc] = find(isnan(TS_DataMat));
thresh_r = filterOptions(1); thresh_c = filterOptions(2);
if thresh_r > 0 % if 1, then even the worst are included
    [badr, ~, rj] = unique(badr); % neat code, but really slow to do this
%     unique... Loop instead
    % (ii) Remove rows with more than a proportion thresh_r bad values
    badrp = zeros(length(badr),1); % stores the number of bad entries
    for i = 1:length(badr)
        badrp(i) = sum(rj==i);
    end
    badrp = badrp/size(TS_DataMat,2);
    xkr1 = badr(badrp >= 1 - thresh_r); % don't keep rows (1) if fewer good values than thresh_r
    kr1 = setxor(1:size(TS_DataMat,1),xkr1);

    if ~isempty(kr1)
        if ~isempty(xkr1)
            fprintf(1,['\nRemoved %u time series with fewer than %4.2f%% good values:'...
                            ' from %u to %u.\n'],size(TS_DataMat,1)-length(kr1),thresh_r*100,size(TS_DataMat,1),length(kr1))
            % display filtered times series to screen:
            fprintf(1,'Time series removed: %s.\n\n',BF_cat({TimeSeries(xkr1).FileName},','))
        else
            fprintf(1,'All %u time series had greater than %4.2f%% good values. Keeping them all.\n', ...
                            size(TS_DataMat,1),thresh_r*100)
        end
        % ********************* kr1 ***********************
        TS_DataMat = TS_DataMat(kr1,:);
        TS_Quality = TS_Quality(kr1,:);
    else
        error('No time series had more than %4.2f%% good values.',thresh_r*100)
    end
else
    % fprintf(1,'No filtering of time series based on proportion of bad values.\n')
    kr1 = (1:size(TS_DataMat,1));
end

if thresh_c > 0
    if thresh_r > 0 && ~isempty(kr1) % did row filtering and removed some
        [~, badc] = find(isnan(TS_DataMat)); % have to recalculate indicies
    end
    [badc, ~, cj] = unique(badc);
    % (iii) Remove metrics that are more than thresh_c bad
    badcp = zeros(length(badc),1); % stores the number of bad entries
    for i = 1:length(badc), badcp(i) = length(find(cj==i)); end
    badcp = badcp/size(TS_DataMat,1);
    xkc1 = badc(badcp >= 1-thresh_c); % don't keep columns if fewer good values than thresh_c
    kc1 = setxor(1:size(TS_DataMat,2),xkc1); % keep columns (1)
    
    if ~isempty(kc1)
        if ~isempty(xkc1)
            fprintf(1,'\nRemoved %u operations with fewer than %5.2f%% good values: from %u to %u.\n',...
                            size(TS_DataMat,2)-length(kc1),thresh_c*100,size(TS_DataMat,2),length(kc1))
            fprintf(1,'Operations removed: %s.\n\n',BF_cat({Operations(xkc1).Name},','))
        else
            fprintf(1,['All operations had greater than %5.2f%% good values; ' ...
                    'keeping them all :-)'],thresh_c*100)
        end

        % *********************** kc1 *********************
        TS_DataMat = TS_DataMat(:,kc1);
        TS_Quality = TS_Quality(:,kc1);
    else
        error('No operations had fewer than %u%% good values.',thresh_c*100)
    end
else
    % fprintf(1,'No filtering of operations based on proportion of bad values\n')
    kc1 = (1:size(TS_DataMat,2));
end

% --------------------------------------------------------------------------
%% Filter out operations that are constant across the time-series dataset
%% And time series with constant feature vectors
% --------------------------------------------------------------------------
if size(TS_DataMat,1) > 1 % otherwise just a single time series remains and all will be constant!
    crap_op = zeros(size(TS_DataMat,2),1);
    for j = 1:size(TS_DataMat,2)
        crap_op(j) = (range(TS_DataMat(~isnan(TS_DataMat(:,j)),j)) < eps);
    end
    kc2 = find(crap_op==0); % kept column (2)

    if ~isempty(kc2)
        if length(kc2) < size(TS_DataMat,2)
            fprintf(1,'Removed %u operations with near-constant outputs: from %u to %u.\n',...
                             size(TS_DataMat,2)-length(kc2),size(TS_DataMat,2),length(kc2))
            TS_DataMat = TS_DataMat(:,kc2); % ********************* KC2 **********************
            TS_Quality = TS_Quality(:,kc2);
        end
    else
        error('All %u operations produced constant outputs on the %u time series?!',length(kc2),size(TS_DataMat,1))
    end
else
    % just one time series remains: keep all operations
    kc2 = ones(1,size(TS_DataMat,2));
end

% (*) Remove time series with constant feature vectors
crap_ts = zeros(size(TS_DataMat,1),1);
for j = 1:size(TS_DataMat,1)
    crap_ts(j) = (range(TS_DataMat(j,~isnan(TS_DataMat(j,:)))) < eps);
end
kr2 = find(crap_ts == 0); % kept column (2)

if ~isempty(kr2)
    if (length(kr2) < size(TS_DataMat,1))
        fprintf(1,'Removed time series with constant feature vectors (weird!): from %u to %u.\n',...
                            size(TS_DataMat,1),length(kr2))
        TS_DataMat = TS_DataMat(kr2,:); % ********************* KR2 **********************
        TS_Quality = TS_Quality(kr2,:);
    end
else
    error('All time series have constant feature vectors?!')
end

% --------------------------------------------------------------------------
%% Update the labels after filtering
% --------------------------------------------------------------------------
% Time series
kr_tot = kr0(kr1(kr2)); % The full set of indices remaining after all the filtering
TimeSeries = TimeSeries(kr_tot); % Filter time series
if ~isempty(trainset)
    % Re-adjust training indices too, if relevant
    trainset = intersect(trainset,kr_tot);
end

% Operations
kc_tot = kc0(kc1(kc2)); % The full set of indices remaining after all the filtering
Operations = Operations(kc_tot); % Filter operations


% In an ideal world, you would check to see if any master operations are no longer pointed to
% and recalibrate the indexing, but I'm not going to bother.

fprintf(1,'We now have %u time series and %u operations in play.\n', ...
                                length(TimeSeries),length(Operations))
fprintf(1,'%u special-valued entries (%4.2f%%) in the %ux%u data matrix.\n',sum(isnan(TS_DataMat(:))), ...
            sum(isnan(TS_DataMat(:)))/length(TS_DataMat(:))*100,size(TS_DataMat,1),size(TS_DataMat,2))


% --------------------------------------------------------------------------
%% Actually apply the normalizing transformation
% --------------------------------------------------------------------------

if ismember(normFunction,{'nothing','none'})
    fprintf(1,'You specified ''%s'', so NO NORMALIZING IS ACTUALLY BEING DONE!!!\n',normFunction)
else
    if isempty(trainset)
        % No training subset specified
        fprintf(1,'Normalizing a %u x %u object. Please be patient...\n',length(TimeSeries),length(Operations))
        TS_DataMat = BF_NormalizeMatrix(TS_DataMat,normFunction);
    else
        % Train the normalization parameters only on a specified set of training data, then apply 
        % that transformation to the full data matrix
        fprintf(1,['Normalizing a %u x %u object using %u training time series to train the transformation!' ...
                ' Please be patient...\n'],length(TimeSeries),length(Operations),length(trainset))
        TS_DataMat = BF_NormalizeMatrix(TS_DataMat,normFunction,trainset);
    end
    fprintf(1,'Normalized! The data matrix contains %u special-valued elements.\n',sum(isnan(TS_DataMat(:))))
end

% --------------------------------------------------------------------------
%% Remove bad entries
% --------------------------------------------------------------------------
% Bad entries after normalizing can be due to feature vectors that are
% constant after e.g., the sigmoid transform -- a bit of a weird thing to do if
% pre-filtering by percentage...

nancol = zeros(size(TS_DataMat,2),1); %column of all NaNs
for i = 1:size(TS_DataMat,2)
    nancol(i) = all(isnan(TS_DataMat(:,i)));
end
if all(nancol) % all columns are NaNs
    error('After normalization, all columns were bad-values... :(');
elseif any(nancol) % there are columns that are all NaNs
    kc = find(nancol==0);
    TS_DataMat = TS_DataMat(:,kc);
    TS_Quality = TS_Quality(:,kc);
    Operations = Operations(kc);
    fprintf(1,'We just removed %u all-NaN columns from after normalization.\n',sum(nancol));
end


% --------------------------------------------------------------------------
%% Make sure the operations are still good
% --------------------------------------------------------------------------
% check again for constant columns after normalization
kc = find(range(TS_DataMat) ~= 0); % (NaN or positive)
if ~isempty(kc) && length(kc) < size(TS_DataMat,2)
    TS_DataMat = TS_DataMat(:,kc);
    TS_Quality = TS_Quality(:,kc);
    Operations = Operations(kc);
    fprintf(1,'Post-normalization filtering of %u operations with constant outputs: from %u to %u.\n', ...
                    size(TS_DataMat,2)-length(kc),size(TS_DataMat,2),length(kc))
end

fprintf(1,'%u bad entries (%4.2f%%) in the %ux%u data matrix.\n', ...
            sum(isnan(TS_DataMat(:))),sum(isnan(TS_DataMat(:)))/length(TS_DataMat(:))*100, ...
            size(TS_DataMat,1),size(TS_DataMat,2))


% --------------------------------------------------------------------------
%% Save results to file
% --------------------------------------------------------------------------

% Make a structure with statistics on normalization:
% Save the codeToRun, so you can check the settings used to run the normalization
% At the moment, only saves the first two arguments
codeToRun = sprintf('TSQ_normalize(''%s'',[%f,%f])',normFunction, ...
                                        filterOptions(1),filterOptions(2));
normalizationInfo = struct('normFunction',normFunction,'filterOptions', ...
                                    filterOptions,'codeToRun',codeToRun);


fprintf(1,'Saving the trimmed, normalized data to local files...')
save('HCTSA_N.mat','TS_DataMat','TS_Quality','TimeSeries','Operations', ...
                                    'MasterOperations','normalizationInfo');
fprintf(1,' Done.\n')

end