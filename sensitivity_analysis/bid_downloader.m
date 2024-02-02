

% bid_downloader.m - script to download System Price Curve Data from the
% Nordic electricity market operator Nord Pool
% last tested and confirmed as working on 2024-02-01

current_date_string = '2018-01-01';

current_date = datenum(current_date_string);

for i = 1:365
    
    file_name = ['mcp_data_report_' datestr(current_date,'DD-mm-YYYY') '-00_00_00.xls'];
    full_url = ['https://www.nordpoolgroup.com/globalassets/download-center-market-data/' file_name];
    
    failed_attempt = 0;
    successful_attempt = 0;
    
    % In case of 10 consecutive failures to read data for a particular
    % day, we output a warning and move on to the next day.
    % The missing data then has to be downloaded seperately.
    while failed_attempt < 10 && successful_attempt == 0
        try
            try
                websave(file_name, full_url);
            catch
                % sometimes only an .xlsx file is available instead of .xls
                websave(file_name, [full_url 'x']);
            end
            successful_attempt = 1;
            disp([datestr(current_date,'DD-mm-YYYY') ' done!']);
        catch
            failed_attempt = failed_attempt + 1;
            disp(['Failed attempt #' num2str(failed_attempt)]);
        end
        if failed_attempt == 10
            disp([datestr(current_date,'DD-mm-YYYY') ' failed to download!'])
        end
    end
    
    current_date = current_date + 1;
    
end