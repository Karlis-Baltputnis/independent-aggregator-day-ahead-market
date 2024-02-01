% DR_surplus_calc_ms - script to calculate the DR consumer welafare impact
% metric for manuscript 
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

% The script reads various data from prior calculation steps that have been
% saved in .mat files. The results are available in the respective variables in the workspace.

clear

rf = 3; % rounding factor to handle equality conditionals

% load the settings
load('settings_array.mat');
comp_share_soc = settings_array(1,1):settings_array(1,2):settings_array(1,3);   % in percentage
comp_price = settings_array(5,1);                                               % in €/MWh

% load the DR curve (DR_price_steps_down, DR_price_steps_up and DR_vol_steps)
load('DR_curve.mat');

% reconstruct the DR curves in the form of DR flex curves (consumption at given price, rather than sell offers)
DR_flex_price_down_lin = [flip(DR_price_steps_down) + comp_price; comp_price*ones(1,4)];
DR_flex_vol_down_lin = 1000*cumsum(flip(DR_vol_steps));
DR_flex_price_down(1:2:2*size(DR_flex_price_down_lin,1)-1,:) = DR_flex_price_down_lin(1:numel(1:2:2*size(DR_flex_price_down_lin,1)-1),:);
DR_flex_price_down(2:2:2*size(DR_flex_price_down_lin,1)-1,:) = DR_flex_price_down_lin(1:numel(2:2:2*size(DR_flex_price_down_lin,1)-1),:);
DR_flex_vol_down(1:2:2*size(DR_flex_vol_down_lin,1),:) = DR_flex_vol_down_lin(1:numel(1:2:2*size(DR_flex_vol_down_lin,1)),:);
DR_flex_vol_down(2:2:2*size(DR_flex_vol_down_lin,1),:) = DR_flex_vol_down_lin(1:numel(2:2:2*size(DR_flex_vol_down_lin,1)),:);
DR_flex_vol_down = [zeros(1,4); DR_flex_vol_down];

DR_flex_vol_nom = DR_flex_vol_down(end,:);

DR_flex_price_up_lin = DR_price_steps_up + comp_price;
DR_flex_vol_up_lin = 1000*cumsum(DR_vol_steps) + DR_flex_vol_nom;
DR_flex_price_up(2:2:2*size(DR_flex_price_up_lin,1)-1,:) = DR_flex_price_up_lin(2:end,:);
DR_flex_price_up(1:2:end+1,:) = DR_flex_price_up_lin;

DR_flex_vol_up(1:2:size(DR_flex_price_up,1),:) = DR_flex_vol_up_lin;
DR_flex_vol_up(2:2:size(DR_flex_price_up,1),:) = DR_flex_vol_up_lin(1:end-1,:);

DR_flex_price = [DR_flex_price_down; DR_flex_price_up];
DR_flex_vol = [DR_flex_vol_down; DR_flex_vol_up];

% load the results of the price recalculation loop
load('main_results.mat');

% these 3-D arrays have the following dimensions – (1) Hour-of-year, (2) share of comp. socialized, (3) DR curve (none, uniform, "expensive", "cheap")
size_arr = size(MCP2);

% seperate the original (i.e., zero DR case)
MCP1 = MCP2(:,1,1,1);

DR_sold_volume = 1000*DR_sold_volume;           % convert to MWh
DR_consumption = zeros(size(DR_sold_volume));
for bid_nr = 1:4
   DR_consumption(:,:,bid_nr) = -DR_sold_volume(:,:,bid_nr) + DR_flex_vol_nom(bid_nr); 
end

DR_surplus_benchmark = zeros(size_arr);
DR_surplus_case = zeros(size_arr);

for hour_numb = 1:size_arr(1)
    
    % calculate the benchmark for each flex curve
    
    for bid_nr = 2:4  % leaving the first column with zeros, since we assumme no untapped flexibility in that scenario
        vol_nom_idx = find(comp_price >= round(DR_flex_price(:,bid_nr),rf),1,'first');                                      % the nominal non-DR point (consumption at RR)
        if round(MCP1(hour_numb),rf) >= round(DR_flex_price(1,bid_nr),rf)                                                   % if the market price is above the max price point (i.e., expected 0 consumption)
            % calculate benchmarks when the market price is above the max price point (i.e., expected 0 consumption)
            DR_surplus_b = trapz(DR_flex_vol(1:vol_nom_idx,bid_nr),DR_flex_price(1:vol_nom_idx,bid_nr)) - comp_price*DR_flex_vol_nom(bid_nr);       % Integral (0->Qnom) minus RR times Q nom
        else
            vol_idx = find(round(DR_flex_price(:,bid_nr),rf)>=round(MCP1(hour_numb),rf),1,'last');                          % the point, where consumption corresponds to the market price (effective consumption), as it is needed for the integral
            if round(MCP1(hour_numb),rf) > comp_price && round(MCP1(hour_numb),rf) < round(DR_flex_price(1,bid_nr),rf)
                if isempty(vol_idx)
                    vol_idx = 1;
                end
                % calculate benchmarks when original market price is above
                % the RR but below the maximum price point in the DR curve
                DR_surplus_b = DR_flex_vol(vol_idx,bid_nr)*MCP1(hour_numb) + trapz(DR_flex_vol(vol_idx:vol_nom_idx,bid_nr),DR_flex_price(vol_idx:vol_nom_idx,bid_nr),1) - comp_price*DR_flex_vol_nom(bid_nr);
            else
                % calculate benchmarks when original market price is below
                % the RR
                DR_surplus_b = -comp_price*DR_flex_vol_nom(bid_nr) - trapz(DR_flex_vol(vol_nom_idx:vol_idx,bid_nr),DR_flex_price(vol_nom_idx:vol_idx,bid_nr),1) + DR_flex_vol(vol_idx,bid_nr)*MCP1(hour_numb);
            end
        end
        DR_surplus_benchmark(hour_numb,:,bid_nr) = ones(1,size_arr(2))*DR_surplus_b;
        
    % calculate the alternatives w different socialization shares
    % this takes into account DR_consumption variable 
    
        for comp_share_soc_iter = 1:size_arr(2)
            if round(DR_consumption(hour_numb,comp_share_soc_iter,bid_nr),rf) ~= DR_flex_vol_nom(bid_nr) % calculate underconsumption welfare only when DR was sold (if it wasnt, that means we already are at effective consumption and the underconsumption welfare is 0)
                vol_idx_1 = find(round(DR_flex_vol(:,bid_nr),rf) >= round(DR_consumption(hour_numb,comp_share_soc_iter,bid_nr),rf),1,'first');    % consumption at MP+kRR (after DR realization)
                vol_idx_2 = find(round(DR_flex_price(:,bid_nr),rf) >= round(MCP2(hour_numb,comp_share_soc_iter,bid_nr),rf),1,'last');             % effective consumption at new MCP
                if isempty(vol_idx_1)
                    vol_idx_1 = 1;
                end
                if isempty(vol_idx_2)
                    vol_idx_2 = 1;
                end
                DR_surplus_c = -trapz([DR_consumption(hour_numb,comp_share_soc_iter,bid_nr); DR_flex_vol(vol_idx_1:vol_idx_2,bid_nr)],...
                    [MCP2(hour_numb,comp_share_soc_iter,bid_nr)+comp_share_soc(comp_share_soc_iter)*comp_price; DR_flex_price(vol_idx_1:vol_idx_2,bid_nr)],1)...
                    + MCP2(hour_numb,comp_share_soc_iter,bid_nr)*(DR_flex_vol(vol_idx_2,bid_nr) - DR_consumption(hour_numb,comp_share_soc_iter,bid_nr));    
            else
                DR_surplus_c = 0; % no underconsumption
            end
            DR_surplus_case(hour_numb,comp_share_soc_iter,bid_nr) = DR_surplus_c;
            
        end
    end
end

DR_surplus_change = DR_surplus_case - DR_surplus_benchmark;
save('DR_surplus_change.mat','DR_surplus_change');