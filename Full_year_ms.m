% Full_year_ms - script to perform market simulations with additional DR
% marketed via IAs, for manuscript
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

% The script reads 365 .xls input files (system price curve data)
% downloaded from Nord Pool webpage and an .xlsx settings file, where the
% DR parameters to be modelled are set.

% The price curve data files and the settings file needs to be in the same folder as the code files!

% There are no per-DR-volume or per-DR-price loops here -> there is per-soc-comp loop and an outer loop for the N number of proposed DR curves

clear
clc
tic

% read settings
settings_array = xlsread('Input_settings_ms.xlsx',1,'G4:I8');
comp_share_soc_min = settings_array(1,1);
comp_share_soc_step = settings_array(1,2);
comp_share_soc_max = settings_array(1,3);
comp_price = settings_array(5,1);
price_step = settings_array(2,2);

% read IA DR_down bid steps
DR_step_info = xlsread('Input_settings_ms.xlsx',1,'A16:K215');
numb_of_steps = max(DR_step_info(:,1));
DR_price_steps = zeros(numb_of_steps,4); % 1st column – no DR, 2nd – uniform, 3rd – "expensive", 4th – "cheap"
DR_vol_steps = zeros(numb_of_steps,4);
DR_price_steps_down(:,2) = DR_step_info(1:numb_of_steps,2);
DR_price_steps_down(:,3) = DR_step_info(1:numb_of_steps,6);
DR_price_steps_down(:,4) = DR_step_info(1:numb_of_steps,10);
DR_vol_steps(:,2) = DR_step_info(1:numb_of_steps,3)/1000;
DR_vol_steps(:,3) = DR_step_info(1:numb_of_steps,7)/1000;
DR_vol_steps(:,4) = DR_step_info(1:numb_of_steps,11)/1000;

% construct IA DR_up bid steps
DR_price_steps_up = DR_price_steps_down - price_step*((1:numb_of_steps)'*2 - 1);
DR_price_steps_up(:,1) = zeros(numb_of_steps,1);

% calculate results array dimension sizes
comp_share_soc_size = (comp_share_soc_max - comp_share_soc_min)/comp_share_soc_step + 1;

% time
start_date = [2018,01,01];                  % [YYYY,MM,DD]
end_date = [2018,12,31];                    % [YYYY,MM,DD]
spring_DST_date = [2018,03,25];             % Spring DST for 2018
autumn_DST_date = [2018,10,28];             % Autumn DST for 2018

% create 3D arrays for results
array_size = 24*(datenum(end_date) - datenum(start_date)) + 24;
hour_numb = 0;
MCP2 = zeros(array_size,comp_share_soc_size,4);                 % modified price
MCV2 = zeros(array_size,comp_share_soc_size,4);                 % modified MCV
DR_sold_volume = zeros(array_size,comp_share_soc_size,4);       % total volume of DR sold (accepted) each hour
prod_surplus = zeros(array_size,comp_share_soc_size,4);         % producer surplus
con_surplus = zeros(array_size,comp_share_soc_size,4);          % gross consumer surplus
compensation = zeros(array_size,comp_share_soc_size,4);         % total socialized compensation costs
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
        
        % prepare data
        % –----- this part used to be located in MCP_calculator_ms, but was moved here for time-efficiency (have to execute it significantly less often)
        % seperate the data from the market curve file into seperate variables
        hour_bids = all_hourly_data(12:end,1);
        block_buy = all_hourly_data(1,1)/1000;
        block_sell = all_hourly_data(2,1)/1000;
        net_flow = all_hourly_data(3,1)/1000;
        
        % find where the buy bids end and sell bids start (i.e., there is an empty cell between them in the excel files)
        change_idx = find(isnan(hour_bids));
        
        % seperate the curve data into buy and sell curve
        buy_curve = unique([hour_bids(1:2:change_idx-1),hour_bids(2:2:change_idx-1)],'rows','stable');  % UNIQUE is necessary to remove sometimes (extremely rarely) present duplicate data in NP files (causes issues with interp1), STABLE ensures that no ascending sorting takes place, which might impact later functions (e.g., buy_volumes is expected to be descending)
        sell_curve = unique([hour_bids(change_idx+1:2:end),hour_bids(change_idx+2:2:end)],'rows','stable');

        buy_prices = buy_curve(:,1);
        buy_volumes = buy_curve(:,2)/1000; % during the calculations and in the output results, all energy is handled in GWh (for easier overview)
        sell_prices = sell_curve(:,1);
        sell_volumes = sell_curve(:,2)/1000;
        
        % add net import and accepted block bid volume as per NP
        % instructions from https://www.nordpoolgroup.com/49568f/globalassets/download-center/information-in-market-cross-point-data-reports-.pdf
        buy_volumes = buy_volumes+block_buy-net_flow*(net_flow<0);
        sell_volumes = sell_volumes+block_sell+net_flow*(net_flow>0);
        % –-----
        
        % calculate the original price
        [MCP, MCV, ~,prod_surplus_0,con_surplus_0,~] = MCP_calculator_ms(buy_prices,buy_volumes,sell_prices,sell_volumes,0,0,0,0,0);  % calculate benchmark (IA DR not marketed) values
        MCP2(hour_numb,:,1) = ones(1,comp_share_soc_size)*MCP;
        MCV2(hour_numb,:,1) = ones(1,comp_share_soc_size)*MCV;
        prod_surplus(hour_numb,:,1) = ones(1,comp_share_soc_size)*prod_surplus_0;
        con_surplus(hour_numb,:,1) = ones(1,comp_share_soc_size)*con_surplus_0;
        
        % loop through the socialized comp share (2nd dimension of the results array)
        comp_share_soc_iter = 0;
        for comp_share_soc = comp_share_soc_min:comp_share_soc_step:comp_share_soc_max
            comp_share_soc_iter = comp_share_soc_iter + 1;
            % loop through the DR bid curves (3rd dimension of the results array)
            for bid_nr = 2:4
                % calculate the new price
                % invoke subroutine (MCP_calculator_ms)
                [MCP_new, MCV_new, DR_sold_volume_calc,prod_surplus_calc,con_surplus_calc,compensation_calc] = MCP_calculator_ms(buy_prices,buy_volumes,sell_prices,sell_volumes,comp_price,comp_share_soc,DR_price_steps_down(:,bid_nr),DR_price_steps_up(:,bid_nr),DR_vol_steps(:,bid_nr));  
                MCP2(hour_numb,comp_share_soc_iter,bid_nr) = MCP_new;
                MCV2(hour_numb,comp_share_soc_iter,bid_nr) = MCV_new;
                DR_sold_volume(hour_numb,comp_share_soc_iter,bid_nr) = DR_sold_volume_calc;
                prod_surplus(hour_numb,comp_share_soc_iter,bid_nr) = prod_surplus_calc;
                con_surplus(hour_numb,comp_share_soc_iter,bid_nr) = con_surplus_calc;
                compensation(hour_numb,comp_share_soc_iter,bid_nr) = compensation_calc;
            end
        end
    end
    display(datestr(cur_date))      % to track progress on the Command Window
end

toc

% save the results arrays
tic
save('main_results.mat','MCP2','MCV2','DR_sold_volume','prod_surplus','con_surplus','compensation');
save('settings_array.mat','settings_array');
save('DR_curve.mat','DR_price_steps_down','DR_price_steps_up','DR_vol_steps');
toc

% After this – begin the postprocessing of the results!
% step-1: calculate DR consumer welfare with
% DR_surplus_calc_ms
% step-2: calculate metrics of interest with
% post_proc_ms