function [MCP2, MCV2, DR_sold_volume,prod_surplus,con_surplus,delta_surplus_test,compensation] = MCP_calculator(all_hourly_data,comp_price,DR_bid_volume,DR_act_cost,comp_share_soc,MCV,MCP,prod_surplus_0,con_surplus_0)

% MCP_calculator - function to perform market clearing simulation with
% and without additional offers by an IA
% this code was used to obtain the results for sensitivity analyses in the manuscript
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

%% Prepare data
% seperate the data from the market curve file into seperate variables
hour_bids = all_hourly_data(12:end,1);
block_buy = all_hourly_data(1,1)/1000;
block_sell = all_hourly_data(2,1)/1000;
net_flow = all_hourly_data(3,1)/1000;

% find where the buy bids end and sell bids start (i.e., there is an empty cell between them in the excel files)
change_idx = find(isnan(hour_bids));

% seperate the curve data into price and volume data points
buy_prices = hour_bids(1:2:change_idx-1);
buy_volumes = hour_bids(2:2:change_idx-1)/1000;                 % during the calculations and in the output results all energy is handled in GWh (for easier overview)
sell_prices = hour_bids(change_idx+1:2:end);
sell_volumes = hour_bids(change_idx+2:2:end)/1000;

% add net import and accepted block bid volume as per NP instructions
buy_volumes = buy_volumes+block_buy-net_flow*(net_flow<0);
sell_volumes = sell_volumes+block_sell+net_flow*(net_flow>0);


%% Calculate the MCP
DR_sell_price = DR_act_cost + round((1 - comp_share_soc)*comp_price,2);      % calculate DR sell price

if ~isempty(MCP) && MCP <= DR_sell_price                % only try to calculate new MCP if there's point in doing so (DR bid price is below original MCP) /saves time
    MCP2 = MCP;
    MCV2 = MCV;
else
    new_sell_volumes = sell_volumes;
    change_idxs = sell_prices>=DR_sell_price;
    break_idx = find(change_idxs,1,'first');
    new_sell_prices = sell_prices;
    
    if ~ismember(DR_sell_price,sell_prices) && DR_bid_volume > 0                % If there is no price point corresponding to the IA offer price, it needs to be added
        new_sell_prices = [sell_prices(1:break_idx-1); DR_sell_price; DR_sell_price; sell_prices(break_idx:end)];
        new_sell_volumes = [sell_volumes(1:break_idx-1); interp1(sell_prices,sell_volumes,DR_sell_price); interp1(sell_prices,sell_volumes,DR_sell_price)+DR_bid_volume; sell_volumes(break_idx:end)+DR_bid_volume];
    elseif ismember(DR_sell_price,sell_prices)&& DR_bid_volume > 0
        new_sell_prices = [new_sell_prices(1:break_idx); new_sell_prices(break_idx:end)];
        new_sell_volumes = [new_sell_volumes(1:break_idx); new_sell_volumes(break_idx:end) + DR_bid_volume];
    end
    % invoke curve intersection algorithm
    [MCV2, MCP2] = intersections(buy_volumes,buy_prices,new_sell_volumes,new_sell_prices);
end

% Calculate the volume of DR sold –> necessary when the available DR volume exceeds the one necessary to drive the MCP down to the DR bid price
DR_sold_volume = intersections([0,99999],[MCP2,MCP2],buy_volumes,buy_prices) - intersections([0,99999],[MCP2,MCP2],sell_volumes,sell_prices);
DR_sold_volume = round(DR_sold_volume,6);

%% calculate producer surplus and gross consumer surplus 
% (i.e., these are the surpluses that arise from the market bid and offer curves

if isempty(prod_surplus_0)
    
    if ~exist('new_sell_volumes','var')
        new_sell_volumes = sell_volumes;
        new_sell_prices = sell_prices;
    end
    
    buy_volumes = [buy_volumes; 0]; % add the points necessary to connect the curves to the y-axis
    buy_prices = [buy_prices; 3000];
    sell_volumes = [0; sell_volumes];
    sell_prices = [-500; sell_prices];
    new_sell_volumes = [0; new_sell_volumes];
    new_sell_prices = [-500; new_sell_prices];
    % if the MCV,MCV2, MCP or MCP2 are missing from the curves, they need to be added for the integration to be accurate
    if ~ismember(MCV,new_sell_volumes)                                                              % this code is not optimized for efficiency, but it surely could be done
        add_idx = find(new_sell_volumes>MCV,1,'first');
        [x,add_price] = intersections([MCV,MCV],[-500,3000],new_sell_volumes,new_sell_prices);
        new_sell_prices = [new_sell_prices(1:add_idx-1); add_price; new_sell_prices(add_idx:end)];
        new_sell_volumes = [new_sell_volumes(1:add_idx-1); MCV; new_sell_volumes(add_idx:end)];
    end
    if ~ismember(MCV,sell_volumes)
        add_idx = find(sell_volumes>MCV,1,'first');
        sell_volumes = [sell_volumes(1:add_idx-1); MCV; sell_volumes(add_idx:end)];
        sell_prices = [sell_prices(1:add_idx-1); MCP; sell_prices(add_idx:end)];
    end
    if ~ismember(MCP,new_sell_prices)
        add_idx = find(new_sell_prices>MCP,1,'first');
        add_vol = intersections(new_sell_volumes,new_sell_prices,[0,99999],[MCP,MCP]);
        new_sell_prices = [new_sell_prices(1:add_idx-1); MCP; new_sell_prices(add_idx:end)];
        new_sell_volumes = [new_sell_volumes(1:add_idx-1); add_vol; new_sell_volumes(add_idx:end)];
    end
    if ~ismember(MCP,sell_prices)
        add_idx = find(sell_prices>MCP,1,'first');
        sell_prices = [sell_prices(1:add_idx-1); MCP; sell_prices(add_idx:end)];
        sell_volumes = [sell_volumes(1:add_idx-1); MCV; sell_volumes(add_idx:end)];
    end
    if ~ismember(MCV2,new_sell_volumes)
        add_idx = find(new_sell_volumes>MCV2,1,'first');
        new_sell_volumes = [new_sell_volumes(1:add_idx-1); MCV2; new_sell_volumes(add_idx:end)];
        new_sell_prices = [new_sell_prices(1:add_idx-1); MCP2; new_sell_prices(add_idx:end)];
    end
    if ~ismember(MCV2,sell_volumes)
        add_idx = find(sell_volumes>MCV2,1,'first');
        [x,add_price] = intersections([MCV2,MCV2],[-500,3000],sell_volumes,sell_prices);
        sell_prices = [sell_prices(1:add_idx-1); add_price; sell_prices(add_idx:end)];
        sell_volumes = [sell_volumes(1:add_idx-1); MCV2; sell_volumes(add_idx:end)];
    end
    if ~ismember(MCP2,new_sell_prices)
        add_idx = find(new_sell_prices>MCP2,1,'first');
        new_sell_prices = [new_sell_prices(1:add_idx-1); MCP2; new_sell_prices(add_idx:end)];
        new_sell_volumes = [new_sell_volumes(1:add_idx-1); MCV2; new_sell_volumes(add_idx:end)];
    end
    if ~ismember(MCP2,sell_prices)
        add_idx = find(sell_prices>MCP2,1,'first');
        add_vol = intersections(sell_volumes,sell_prices,[0,99999],[MCP2,MCP2]);
        sell_prices = [sell_prices(1:add_idx-1); MCP2; sell_prices(add_idx:end)];
        sell_volumes = [sell_volumes(1:add_idx-1); add_vol; sell_volumes(add_idx:end)];
    end
    if ~ismember(MCV,buy_volumes)
        add_idx = find(buy_volumes<MCV,1,'first');
        buy_volumes = [buy_volumes(1:add_idx-1); MCV; buy_volumes(add_idx:end)];
        buy_prices = [buy_prices(1:add_idx-1); MCP; buy_prices(add_idx:end)];
    end
    if ~ismember(MCV2,buy_volumes)
        add_idx = find(buy_volumes<MCV2,1,'first');
        buy_volumes = [buy_volumes(1:add_idx-1); MCV2; buy_volumes(add_idx:end)];
        buy_prices = [buy_prices(1:add_idx-1); MCP2; buy_prices(add_idx:end)];
    end
    if ~ismember(MCP, buy_prices)
        add_idx = find(buy_prices>MCP,1,'first');
        buy_volumes = [buy_volumes(1:add_idx-1); MCV; buy_volumes(add_idx:end)];
        buy_prices = [buy_prices(1:add_idx-1); MCP; buy_prices(add_idx:end)];
    end
    if ~ismember(MCP2, buy_prices)
        add_idx = find(buy_prices>MCP2,1,'first');
        buy_volumes = [buy_volumes(1:add_idx-1); MCV2; buy_volumes(add_idx:end)];
        buy_prices = [buy_prices(1:add_idx-1); MCP2; buy_prices(add_idx:end)];
    end
    if ~ismember(DR_sell_price,sell_prices)
        add_idx = find(sell_prices>DR_sell_price,1,'first');
        sell_volumes = [sell_volumes(1:add_idx-1); intersections(sell_volumes,sell_prices,[0,99999],[DR_sell_price,DR_sell_price]); sell_volumes(add_idx:end)];
        sell_prices = [sell_prices(1:add_idx-1); DR_sell_price; sell_prices(add_idx:end)];
    end
    
    prod_surplus = MCP2*1000*MCV2 - trapz(1000*new_sell_volumes(new_sell_volumes<=MCV2),new_sell_prices(new_sell_volumes<=MCV2)); % all surpluses in €!!!
    con_surplus = trapz(1000*flip(buy_volumes(buy_volumes<=MCV2)),flip(buy_prices(buy_volumes<=MCV2))) - MCP2*1000*MCV2;
else
    prod_surplus = prod_surplus_0;
    con_surplus = con_surplus_0;
end

delta_surplus_test = 0;
if DR_sold_volume > 0           % the surplus change is calculated with two different approaches (to double-check that the code is implemented correctly)
    delta_surplus_test = trapz(1000*sell_volumes(sell_prices>=DR_sell_price&sell_prices<=MCP),sell_prices(sell_prices>=DR_sell_price&sell_prices<=MCP),1)...
        - trapz(1000*new_sell_volumes(new_sell_prices>=DR_sell_price&new_sell_volumes<=MCV),new_sell_prices(new_sell_prices>=DR_sell_price&new_sell_volumes<=MCV),1)...
        + trapz(1000*flip(buy_volumes(buy_prices<=MCP&buy_prices>=MCP2)),flip(buy_prices(buy_prices<=MCP&buy_prices>=MCP2)),1)...
        - trapz(1000*new_sell_volumes(new_sell_volumes>=MCV&new_sell_volumes<=MCV2),new_sell_prices(new_sell_volumes>=MCV&new_sell_volumes<=MCV2),1);
end
compensation = 1000*DR_sold_volume*round(comp_share_soc*comp_price,2); % value in €
end