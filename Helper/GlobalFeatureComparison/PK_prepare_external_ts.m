% --------------------------------------------------------------------------
% PK_prepare_external_ts
% --------------------------------------------------------------------------
% 
% This function retreives operations from the mySQL database for subsequent analysis
% in Matlab. It takes as input a set of constraints
% operations to include, and outputs the relevant subsection of the
% operations and associated metadata in HCTSA_loc
% 
%---INPUTS:
%--op_ids: a vector of op_ids to retrieve from the mySQL database.
% 
%---OUTPUT:
%--didWrite [opt] is 1 if Writes new file HCTSA_loc.mat
% 
% Other outputs are to the file HCTSA_loc.mat contains
%--Operations, contains metadata about the operations
%--MasterOperations, contains metadata about the implicatedmaster operations
% 
% ------------------------------------------------------------------------------
% Copyright (C) 2013,  Ben D. Fulcher <ben.d.fulcher@gmail.com>,
% <http://www.benfulcher.com>
% 2015 Philip Knaute <philip.knaute@gmail.com>
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

function didWrite = PK_prepare_external_ts(op_ids)
    
% Until it actually writes something, set the function output, didWrite = 0
didWrite = 0;

% --------------------------------------------------------------------------
%% Check inputs and set defaults
% --------------------------------------------------------------------------
if nargin < 1
	error('You must provide at least one input!');
end

% ------------------------------------------------------------------------------
%% Preliminaries
% ------------------------------------------------------------------------------

% Make sure ts_ids and op_ids are column vectors:
if size(op_ids,2) > size(op_ids,1), op_ids = op_ids'; end

% Sort ids ascending:
op_ids = sort(op_ids,'ascend');

% Write a comma-delimited string of ids:
op_ids_string = BF_cat(op_ids,',');

% Count the number of time series and operations
nops = length(op_ids);

if (nops == 0)
	error('Oops. There''s nothing to do! No operations to retrieve!');
end

% Open database connection
[dbc, dbname] = SQL_opendatabase;


% ------------------------------------------------------------------------------
% Refine the set of time series and operations to those that actually exist in the database
% ------------------------------------------------------------------------------
opids_db = mysql_dbquery(dbc,sprintf('SELECT op_id FROM Operations WHERE op_id IN (%s)',op_ids_string));
opids_db = vertcat(opids_db{:});

if length(opids_db) < nops % actually there are fewer operations in the database
    if (length(opids_db) == 0) % now there are no operations to retrieve
        fprintf(1,'None of the %u specified operations exist in ''%s''\n',nops,dbname)
        SQL_closedatabase(dbc); return % Close the database connection before returning
    end
    fprintf(1,['%u specified operations do not exist in ''%s'', retrieving' ...
                    ' the remaining %u\n'],nops-length(opids_db),dbname,length(opids_db))
    op_ids = opids_db; % Will always be sorted in ascending order
    op_ids_string = BF_cat(op_ids,',');
    nops = length(op_ids);
end

% Tell me about it
fprintf(1,'We have %u operations to retrieve from %s.\n',nops,dbname);
fprintf(1,['Filling and saving to local Matlab file HCTSA_loc.mat from ' ...
                                'the Results table of %s.\n'],dbname);

% % --------------------------------------------------------------------------
% %% Intialize matrices
% % --------------------------------------------------------------------------
% 
% % Initialize as Infs to distinguish unwritten entries after database retrieval
% switch RetrieveWhatData
% case 'all'
%     TS_DataMat = ones(nts,nops)*Inf;  % Outputs
%     TS_Quality = ones(nts,nops)*Inf;  % Quality labels
%     TS_CalcTime = ones(nts,nops)*Inf; % Calculation times
% case 'nocalctime'
%     TS_DataMat = ones(nts,nops)*Inf;  % Outputs
%     TS_Quality = ones(nts,nops)*Inf;  % Quality labels
% case 'outputs'
%     TS_DataMat = ones(nts,nops)*Inf;  % Outputs
% case 'quality'
%     TS_Quality = ones(nts,nops)*Inf;  % Quality labels
% end
% 
% % Display information to user:
% switch RetrieveWhatEntries
% case 'all' 
%     fprintf(1,['Retrieving all elements from the database (one time series ' ...
%                 'per database query). Please be patient...\n']);
% case 'null'
%     fprintf(1,['Retrieving NULL elements from the database (one time series ' ...
%                 'per database query). Please be patient...\n']);
% case 'error'
%     fprintf(1,['Retrieving error elements from the database (one time series ' ...
%                 'per database query). Please be patient...\n']);
% end
% 
% % --------------------------------------------------------------------------
% %% Retrieve the data from the database:
% % --------------------------------------------------------------------------
% IterationTimes = zeros(nts,1); % Record the time taken for each iteration
% DidRetrieve = zeros(nts,1);    % Keep track of whether data was retrieved at each iteration
% for i = 1:nts
%     
%     IterationTimer = tic; % Time each iteration using IterationTimer
% 
%     ts_id_now = ts_ids(i); % Range of ts_ids retrieved in this iteration
%     
%     % Start piecing together the mySQL SELECT command:
%     switch RetrieveWhatData
%     case 'all'
%         SelectWhat = 'SELECT op_id, Output, QualityCode, CalculationTime FROM Results';
%     case 'nocalctime' % Do not retrieve calculation time results
%         SelectWhat = 'SELECT op_id, Output, QualityCode FROM Results';
%     case 'outputs'
%         SelectWhat = 'SELECT op_id, Output FROM Results';
%     case 'quality'
%         SelectWhat = 'SELECT op_id, QualityCode FROM Results';
%     end
%     
%     BaseString = sprintf('%s WHERE ts_id = %u AND op_id IN (%s)',SelectWhat, ...
%                                             ts_id_now,op_ids_string);
%     
%     % We could do a (kind of blind) retrieval, i.e., without retrieving op_ids safely
%     % as long as for a given ts_id, the op_ids are in ascending order in the Results table.
%     % This will be the case if time series and operations are added
%     % using SQL_add because of the SORT BY specifier in SQL_add commands.
%     % Otherwise op_ids should also be retrieved here, and used to sort
%     % the other columns (i.e., outputs, quality codes, calculation times)
%     
%     switch RetrieveWhatEntries
%     case 'all'
%         SelectString = BaseString;
%     case 'null'
%     	SelectString = sprintf('%s AND QualityCode IS NULL',BaseString);
%     case 'error'
%     	SelectString = sprintf('%s AND QualityCode = 1',BaseString);
%     end
%     
%     % Do the retrieval
%     % DatabaseTimer = tic;
% 	[qrc, ~, ~, emsg] = mysql_dbquery(dbc,SelectString); % Retrieve data for this time series from the database
%     % fprintf(1,'Database query for %u time series took %s\n',BundleSize,BF_thetime(toc(DatabaseTimer)));
%     
%     if ~isempty(emsg)
%         error('Error retrieving outputs from %s!!! :(\n%s',dbname,emsg);
%     end
%     
%     % Check results look ok:
%     if (size(qrc) == 0) % There are no entries in Results that match the requested conditions
%         fprintf(1,'No data to retrieve for ts_id = %u\n',ts_id_now);
%         % Leave local files (e.g., TS_DataMat, TS_Quality, TS_CalcTime as Inf)
%         
%     else
%         % Entries need to be written to local matrices
%         % Set DidRetrieve = 1 for this iteration
%         DidRetrieve(i) = 1;
%         
%     	% Convert empty entries to NaNs
%     	qrc(cellfun(@isempty,qrc)) = {NaN};
%     
%         % Put results from database into rows of local matrix
%         if strcmp(RetrieveWhatEntries,'all') % easy in this case
%             % Assumes data is ordered by the op_id_string provided
%             % This will be the case if all time series and operations
%             % were added using SQL_add.
%             % Otherwise we'll have nonsense happening...
%             switch RetrieveWhatData
%             case 'all'
%                 TS_DataMat(i,:) = vertcat(qrc{:,2});
%                 TS_Quality(i,:) = vertcat(qrc{:,3});
%                 TS_CalcTime(i,:) = vertcat(qrc{:,4});
%             case 'nocalctime'
%                 TS_DataMat(i,:) = vertcat(qrc{:,2});
%                 TS_Quality(i,:) = vertcat(qrc{:,3});
%             case 'outputs'
%                 TS_DataMat(i,:) = vertcat(qrc{:,2});
%             case 'quality'
%                 TS_Quality(i,:) = vertcat(qrc{:,2});
%             end
%         else
%             % We retrieved a subset of the input op_ids
%             % We have to match retrieved op_ids to local indicies
%             iy = arrayfun(@(x)find(op_ids == x,1),vertcat(qrc{:,1}));
%             % Now fill the corresponding entries in the local matrices:
%             switch RetrieveWhatData
%             case 'all'
%                 TS_DataMat(i,iy) = vertcat(qrc{:,2});
%                 TS_Quality(i,iy) = vertcat(qrc{:,3});
%                 TS_CalcTime(i,iy) = vertcat(qrc{:,4});
%             case 'nocalctime'
%                 TS_DataMat(i,iy) = vertcat(qrc{:,2});
%                 TS_Quality(i,iy) = vertcat(qrc{:,3});
%             case 'outputs'
%                 TS_DataMat(i,iy) = vertcat(qrc{:,2});
%             case 'quality'
%                 TS_Quality(i,iy) = vertcat(qrc{:,2});
%             end
%         end
%     end
%     
%     % Note time taken for this iteration, and periodically display indication of time remaining
% 	IterationTimes(i) = toc(IterationTimer);
%     if (i==1) % Give an initial indication of time after the first iteration
%         fprintf(1,['Based on the first retrieval, this is taking ' ...
%                 'approximately %s per time series...\n'],BF_thetime(IterationTimes(1)));
% 		fprintf(1,'Approximately %s remaining...\n',BF_thetime(IterationTimes(1)*(nts-1)));
%     elseif (mod(i,floor(nts/10))==0) % Tell us the time remaining 10 times across the total retrieval
% 		fprintf(1,'Approximately %s remaining...\n',BF_thetime(mean(IterationTimes(1:i))*(nts-i)));
% 	end
% end
% 
% % --------------------------------------------------------------------------
% %% Finished retrieving from the database!
% % --------------------------------------------------------------------------
% if any(DidRetrieve)
%     fprintf(1,'Retrieved data from %s over %u iterations in %s.\n',...
%                             dbname,nts,BF_thetime(sum(IterationTimes)));
% else
%     fprintf(1,['Over %u iterations, no data was retrieved from %s.\n' ...
%                             'Not writing any data to file.\n'],nts,dbname);
%     SQL_closedatabase(dbc); return
% end
% 	
% if ismember(RetrieveWhatEntries,{'null','error'})    
%     % We only want to keep rows and columns with (NaNs for 'null' or errors for 'error') in them...
%     switch RetrieveWhatEntries
%     case 'null'
%         keepme = isnan(TS_DataMat); % NULLs in database
%         fprintf(1,['Filtering so that local files contain rows/columns containing at least ' ...
%                                 'one entry that was NULL in the database.\n']);
%     case 'error'
%         keepme = (TS_Quality == 1); % Error codes in database
%         fprintf(1,['Filtering so that local files contain rows/columns containing at least ' ...
%                                 'one entry that was an error in the database.\n']);
%     end
%     
% 	% Time series
%     keepi = (sum(keepme,2) > 0); % there is at least one entry to calculate in this row
%     if sum(keepi) == 0
%     	fprintf(1,'After filtering, there are no time series remaining! Exiting...\n');
%         SQL_closedatabase(dbc); return % Close the database connection, then exit
% 	elseif sum(keepi) < nts
% 		fprintf(1,'Cutting down from %u to %u time series\n',nts,sum(keepi));
% 		ts_ids = ts_ids(keepi); nts = length(ts_ids);
% 		ts_ids_string = BF_cat(ts_ids,',');
%         switch RetrieveWhatData
%         case 'all'
%     		TS_DataMat = TS_DataMat(keepi,:);
%             TS_Quality = TS_Quality(keepi,:);
%             TS_CalcTime = TS_CalcTime(keepi,:);
%         case 'nocalctime'
%     		TS_DataMat = TS_DataMat(keepi,:);
%             TS_Quality = TS_Quality(keepi,:);
%         case 'outputs'
%             TS_DataMat = TS_DataMat(keepi,:);
%         case 'quality'
%             TS_Quality = TS_Quality(keepi,:);
%         end
% 	end
% 	
% 	% Operations
%     keepi = (sum(keepme,1) > 0); % there is at least one entry to calculate in this column
% 	if sum(keepi) == 0
%     	fprintf(1,'After filtering, there are no operations remaining! Exiting...\n');
%         SQL_closedatabase(dbc); return % Close the database connection, then exit
%     elseif sum(keepi) < nops
% 		fprintf(1,'Cutting down from %u to %u operations\n',nops,sum(keepi));
% 		op_ids = op_ids(keepi); nops = length(op_ids);
% 		op_ids_string = BF_cat(op_ids,',');
%         switch RetrieveWhatData
%         case 'all'
%     		TS_DataMat = TS_DataMat(:,keepi);
%             TS_Quality = TS_Quality(:,keepi);
%             TS_CalcTime = TS_CalcTime(:,keepi);
%         case 'nocalctime' 
%     		TS_DataMat = TS_DataMat(:,keepi);
%             TS_Quality = TS_Quality(:,keepi);
%         case 'outputs'
%             TS_DataMat = TS_DataMat(:,keepi);
%         case 'quality'
%             TS_Quality = TS_Quality(:,keepi);
%         end
% 	end    
% end
% 
% 
% % ------------------------------------------------------------------------------
% %% Fill Metadata
% % ------------------------------------------------------------------------------
% 
% % 1. Retrieve Time Series Metadata
% SelectString = sprintf('SELECT FileName, Keywords, Length, Data FROM TimeSeries WHERE ts_id IN (%s)',ts_ids_string);
% [tsinfo,~,~,emsg] = mysql_dbquery(dbc,SelectString);
% % Convert to a structure array, TimeSeries, containing metadata for all time series
% tsinfo = [num2cell(ts_ids),tsinfo];
% % Define inline functions to convert time-series data text to a vector of floats:
% ScanCommas = @(x) textscan(x,'%f','Delimiter',',');
% TakeFirstCell = @(x) x{1};
% tsinfo(:,end) = cellfun(@(x) TakeFirstCell(ScanCommas(x)),tsinfo(:,end),'UniformOutput',0); % Do the conversion
% TimeSeries = cell2struct(tsinfo',{'ID','FileName','Keywords','Length','Data'}); % Convert to structure array
% 
% 2. Retrieve Operation Metadata
SelectString = sprintf('SELECT OpName, Keywords, Code, mop_id FROM Operations WHERE op_id IN (%s)',op_ids_string);
[opinfo,~,~,emsg] = mysql_dbquery(dbc,SelectString);
opinfo = [num2cell(op_ids), opinfo]; % add op_ids
Operations = cell2struct(opinfo',{'ID','Name','Keywords','CodeString','MasterID'});

% 3. Retrieve Master Operation Metadata
% (i) Which masters are implicated?
SelectString = ['SELECT mop_id, MasterLabel, MasterCode FROM MasterOperations WHERE mop_id IN ' ...
        				'(' BF_cat(unique([Operations.MasterID]),',') ')'];
[masterinfo,~,~,emsg] = mysql_dbquery(dbc,SelectString);
if ~isempty(emsg)
    fprintf(1,'Error retrieving Master information...\n');
    disp(emsg);
    keyboard
else
    MasterOperations = cell2struct(masterinfo',{'ID','Label','Code'});
end

% Close database connection
SQL_closedatabase(dbc)

% ------------------------------------------------------------------------------
%% Save to HCTSA_loc.mat
% ------------------------------------------------------------------------------
fprintf(1,'Saving local versions of the data to HCTSA_loc.mat...');
save('HCTSA_loc.mat','Operations','MasterOperations','-v7.3');
% switch RetrieveWhatData
% case 'all'
%     % Add outputs, quality labels, and calculation times
%     save('HCTSA_loc.mat','TS_DataMat','TS_Quality','TS_CalcTime','-append')
% case 'nocalctime'
%     % Add outputs and quality labels
%     save('HCTSA_loc.mat','TS_DataMat','TS_Quality','-append')
% case 'outputs'
%     % Add outputs
%     save('HCTSA_loc.mat','TS_DataMat','-append')
% case 'quality'
%     % Add quality labels
%     save('HCTSA_loc.mat','TS_Quality','-append')
% end
% 
fprintf(1,' Done.\n');
didWrite = 1;
% 
% % ------------------------------------------------------------------------------
% %% If retrieved quality labels, display how many entries need to be calculated
% % ------------------------------------------------------------------------------
% if strcmp(RetrieveWhatData,'outputs')
%     fprintf(1,'You have the outputs, but you don''t know which are good or not without the quality labels...\n');
% else
%     tocalculate = sum(isnan(TS_Quality(:)) | TS_Quality(:)==1);
%     fprintf(1,'There are %u entries (=%4.2f%%) to calculate in the data matrix (%ux%u).\n', ...
%                                         tocalculate,tocalculate/nops/nts*100,nts,nops);
% end

end