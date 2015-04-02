% ------------------------------------------------------------------------------
% SQL_ChangeDatabase
% 
% Write a new .conf file with the connection details for next time
% 
%---HISTORY:
% Ben Fulcher, 2015-03-31
% 
% ------------------------------------------------------------------------------
% Copyright (C) 2013, Ben D. Fulcher <ben.d.fulcher@gmail.com>,
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

function SQL_ChangeDatabase()
    
fprintf(1,['Time to change databases?\nThis script assumes that you have created ' ...
            'a database on a mySQL server and have the access details for it. ' ...
            'Continuing with this script will overwrite ' ...
            'the existing mySQL connection settings\n(cntrl-C to abort)\n\n']);

% ------------------------------------------------------------------------------
% Get all the details:
% ------------------------------------------------------------------------------
hostName = input('Hostname of mySQL server (DEFAULT: ''localhost''): ','s');
local_u = input('Username: ','s');
local_p = input('Password (this will appear on screen and be stored in file!): ','s');
customPort = input('Custom port to connect through (DEFAULT: 3306): ','s');
databaseName = input('Name of the database to connect to (DEFAULT: ''hctsa''): ','s');

% Set defaults:

if isempty(hostName)
    hostName = 'localhost';
end

if isempty(customPort)
    customPort = '3306';
end
customPort = str2num(customPort);

if isempty(databaseName)
    databaseName = 'hctsa';
end

% ------------------------------------------------------------------------------
% Write the .conf file:
% ------------------------------------------------------------------------------
fileName = fullfile('Database','sql_settings.conf');

fprintf(1,['Writing hostName (%s), database name (%s), username (%s), and ' ...
            'password (%s) to %s\n'],hostName,databaseName,local_u,local_p,fileName);
fid = fopen(fileName,'w');
fprintf(fid,'%s,%s,%s,%s,%u',hostName,databaseName,local_u,local_p,customPort);
fclose(fid);

% ------------------------------------------------------------------------------
% Test that the new connection settings work:
% ------------------------------------------------------------------------------
try
	dbc = SQL_opendatabase;
	SQL_closedatabase(dbc);
    fprintf(1,'Database %s at %s for %s opens and closes no problem!!\n',databaseName,hostName,local_u);
    fprintf(1,'We''re good to go!! :)\n');
catch
	fprintf(1,'Error: Unable to connect using the new database settings :(\n',databaseName);
end

end