% Full_year - script to perform market simulations with additional DR
% marketed via IAs, for sensitivity analyses in the manuscript
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

% The script reads 365 .xls input files (system price curve data)
% downloaded from Nord Pool webpage and an .xlsx settings file, where the
% DR parameter sensitivities to be modelled are set.

% The price curve data files and the settings file needs to be in the same folder as the code files!

clear
clc
tic

% read settings
settings_array = xlsread('Input_settings.xlsx',1,'G4:I8');
comp_share_soc_min = settings_array(1,1);
comp_share_soc_step = settings_array(1,2);
comp_share_soc_max = settings_array(1,3);
DR_act_cost_min = settings_array(2,1);
DR_act_cost_step = settings_array(2,2);
DR_act_cost_max = settings_array(2,3);
DR_sell_vol_min = settings_array(3,1)/1000; % must equal 0!
DR_sell_vol_step = settings_array(3,2)/1000; % in GW
DR_sell_vol_max = settings_array(3,3)/1000;
comp_price = settings_array(5,1);

% calculate results array dimension sizes
comp_share_soc_size = (comp_share_soc_max - comp_share_soc_min)/comp_share_soc_step + 1;
DR_act_cost_size = (DR_act_cost_max - DR_act_cost_min)/DR_act_cost_step + 1;
DR_sell_vol = (DR_sell_vol_max - DR_sell_vol_min)/DR_sell_vol_step + 1;

% time
start_date = [2018,01,01];                  % [YYYY,MM,DD]
end_date = [2018,12,31];                    % [YYYY,MM,DD]
spring_DST_date = [2018,03,25];             % Spring DST for 2018
autumn_DST_date = [2018,10,28];             % Autumn DST for 2018

% create 4D arrays for results
array_size = 24*(datenum(end_date) - datenum(start_date)) + 24;
hour_numb = 0;
MCP2 = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);                 % modified price
MCV2 = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);                 % modified MCV
DR_sold_volume = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);       % total volume of DR sold (accepted) each hour
prod_surplus = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);
con_surplus = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);
delta_surplus_test = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);
compensation = zeros(array_size,DR_sell_vol,DR_act_cost_size,comp_share_soc_size);
toc

tic
% loop through days
for cur_date = datenum(start_date):datenum(end_date)
    input_file = ['mcp_data_report_' datestr(cur_date,'DD-mm-YYYY') '-00_00_00.xls'];   % construct name of the file to read from
    all_daily_data = xlsread(input_file);                                               % read all data from the file of the respective day
    
    last_hour = 24;
    if cur_date == datenum(spring_DST_date)       % Spring DST
        last_hour = 23;
    end
    if cur_date == datenum(autumn_DST_date)       % Autumn DST
        last_hour = 25;
    end
    
    % loop through hours in the day (1st dimension of the results array)
    for input_hour = 1:last_hour
        hour_numb = hour_numb + 1;
        all_hourly_data = all_daily_data(:,2*input_hour-1);
        all_hourly_data = all_hourly_data(1:find(sum(~isnan(all_hourly_data),2) > 0, 1 , 'last'),1);    % delete trailing NaNs
        MCP = []; % reset variable for the original MCP at current hour
        prod_surplus_0 = [];
        con_surplus_0 = [];
        
        % loop through the socialized comp share (4th dimension of the results array)
        comp_share_soc_iter = 0;
        for comp_share_soc = comp_share_soc_min:comp_share_soc_step:comp_share_soc_max
            comp_share_soc_iter = comp_share_soc_iter + 1;
            
            % loop through the activation cost (3rd dimension of the results array)
            DR_act_cost_iter = 0;
            for DR_act_cost = DR_act_cost_min:DR_act_cost_step:DR_act_cost_max
                DR_act_cost_iter = DR_act_cost_iter + 1;
                
                % loop through the DR bid volume (2nd dimension of the results array)
                DR_sell_vol_iter = 0;
                for DR_sell_vol = DR_sell_vol_min:DR_sell_vol_step:DR_sell_vol_max
                    DR_sell_vol_iter = DR_sell_vol_iter + 1;
                    
                    % make sure that the original price is only calculated once when bid DR volume equals 0 (to avoid unnecesary computational overhead)
                    if DR_sell_vol == 0
                        if isempty(MCP)
                            [MCP, MCV, ~, prod_surplus_0, con_surplus_0,~,~] = MCP_calculator(all_hourly_data,0,0,0,0,0,[],prod_surplus_0,con_surplus_0);  % invoke subroutine MCP_calculator
                        end
                        MCP2(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = MCP;
                        MCV2(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = MCV;
                        DR_sold_volume(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = 0;
                        prod_surplus(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = prod_surplus_0;
                        con_surplus(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = con_surplus_0;
                        delta_surplus_test(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = 0;
                        compensation(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = 0;
                    else
                        % calculate the new price
                        [MCP_new, MCV_new, DR_sold_volume_calc, prod_surplus_calc, con_surplus_calc, delta_surplus_test_calc, compensation_calc] = MCP_calculator(all_hourly_data,comp_price,DR_sell_vol,DR_act_cost,comp_share_soc,MCV,MCP,[],[]);  % invoke subroutine MCP_calculator
                        MCP2(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = MCP_new;
                        MCV2(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = MCV_new;
                        DR_sold_volume(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = DR_sold_volume_calc;
                        prod_surplus(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = prod_surplus_calc;
                        con_surplus(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = con_surplus_calc;
                        delta_surplus_test(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = delta_surplus_test_calc;
                        compensation(hour_numb,DR_sell_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = compensation_calc;
                    end
                end
            end
        end
    end
    display(datestr(cur_date))      % to track progress on the Command Window
end

toc

% save the results arrays
tic
save('settings_array.mat','settings_array');
save('main_results.mat','MCP2','MCV2','DR_sold_volume','prod_surplus','con_surplus','delta_surplus_test','compensation');
toc

% After this – begin the postprocessing of the results!
% step-1: calculate DR consumer welfare with
% DR_surplus_calc
% step-2: calculate metrics of interest with
% post_proc