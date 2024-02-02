% DR_surplus_calc - script to calculate the DR consumer welafare impact
% metric for sensitivity analyses in the manuscript 
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

% The script reads various data from prior calculation steps that have been
% saved in .mat files. The results are available in the respective variables in the workspace.

clear

rf = 3; % rounding to handle equality checks

% load the settings
load('settings_array.mat');
comp_share_soc = settings_array(1,1):settings_array(1,2):settings_array(1,3);   % in percentage
DR_act_cost = settings_array(2,1):settings_array(2,2):settings_array(2,3);      % in €/MWh
DR_bid_vol = settings_array(3,1):settings_array(3,2):settings_array(3,3);       % in MWh/h
comp_price = settings_array(5,1);                                               % in €/MWh

% load the results of the price recalculation loop
load('main_results.mat');

% these 4-D arrays have the following dimensions – (1) Hour-of-year, (2) DR bid volume, (3) DR activation cost, (4) share of comp. socialized
size_arr = size(MCP2);

% seperate the original (i.e., zero DR case)
MCP1 = MCP2(:,1,1,1);

DR_surplus_benchmark = zeros(size_arr);
DR_surplus_case = zeros(size_arr);

for hour_numb = 1:size_arr(1)
    for DR_bid_vol_iter = 1:size_arr(2)
        for DR_act_cost_iter = 1:size_arr(3)
            if round(MCP1(hour_numb),rf) > round(DR_act_cost(DR_act_cost_iter) + comp_price,rf)
                DR_surplus_b = DR_act_cost(DR_act_cost_iter)*DR_bid_vol(DR_bid_vol_iter);
            else
                DR_surplus_b = (MCP1(hour_numb) - comp_price)*DR_bid_vol(DR_bid_vol_iter);
            end
            DR_surplus_benchmark(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,:) = ones(1,1,1,size_arr(4)).*DR_surplus_b;
            
            for comp_share_soc_iter = 1:size_arr(4)
                if round(MCP1(hour_numb),rf) == round(MCP2(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,comp_share_soc_iter),rf)
                    DR_surplus_c = 0; % if no DR takes place, we do not have socialization-induced underconsumption
                else
                    if round(MCP2(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,comp_share_soc_iter) + comp_share_soc(comp_share_soc_iter)*comp_price,rf) >= round(DR_act_cost(DR_act_cost_iter) + comp_price,rf)...
                        && round(DR_act_cost(DR_act_cost_iter) + comp_price,rf) >= round(MCP2(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,comp_share_soc_iter),rf)
                    DR_surplus_c = (MCP2(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,comp_share_soc_iter) - DR_act_cost(DR_act_cost_iter) - comp_price)...
                        *1000*DR_sold_volume(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,comp_share_soc_iter);
                    else
                        DR_surplus_c = 0;
                    end
                end
                DR_surplus_case(hour_numb,DR_bid_vol_iter,DR_act_cost_iter,comp_share_soc_iter) = DR_surplus_c;
            end
            
        end
    end
end

DR_surplus_change = DR_surplus_case - DR_surplus_benchmark;
save('DR_surplus_change.mat','DR_surplus_change');