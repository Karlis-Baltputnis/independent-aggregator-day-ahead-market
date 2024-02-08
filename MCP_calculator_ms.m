function [MCP2,MCV2,DR_sold_volume,prod_surplus,con_surplus,compensation] = MCP_calculator_ms(buy_prices,buy_volumes,sell_prices,sell_volumes,comp_price,comp_share_soc,DR_price_steps_down,DR_price_steps_up,DR_vol_steps)

% MCP_calculator_ms - function to perform market clearing simulation with
% and without additional offers by an IA
% this code was used to obtain the results in the manuscript
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?


%% Calculate the MCP
% add IA offer to the sell curves
DR_price_steps_down = DR_price_steps_down + round((1 - comp_share_soc)*comp_price,6);      % calculate DR sell price

new_sell_volumes = sell_volumes;
new_sell_prices = sell_prices;

for step_nr = 1:numel(DR_price_steps_down)                                                 % add IA offer curve points to the new sell price and volume curves at the appropriate places
    change_idxs = new_sell_prices>=DR_price_steps_down(step_nr);
    break_idx = find(change_idxs,1,'first');
    if ~ismember(DR_price_steps_down(step_nr),sell_prices) && DR_vol_steps(step_nr) > 0
        new_sell_volumes = [new_sell_volumes(1:break_idx-1); interp1(sell_prices,sell_volumes,DR_price_steps_down(step_nr)) + sum(DR_vol_steps(1:step_nr)) - DR_vol_steps(step_nr); interp1(sell_prices,sell_volumes,DR_price_steps_down(step_nr)) + sum(DR_vol_steps(1:step_nr)); new_sell_volumes(break_idx:end) + DR_vol_steps(step_nr)];
        new_sell_prices = [new_sell_prices(1:break_idx-1); DR_price_steps_down(step_nr); DR_price_steps_down(step_nr); new_sell_prices(break_idx:end)];
    elseif ismember(DR_price_steps_down(step_nr),sell_prices) && DR_vol_steps(step_nr) > 0
        new_sell_volumes = [new_sell_volumes(1:break_idx); new_sell_volumes(break_idx:end) + DR_vol_steps(step_nr)];
        new_sell_prices = [new_sell_prices(1:break_idx); new_sell_prices(break_idx:end)];
    end
end

% add IA offer to the buy curve
DR_price_steps_up = DR_price_steps_up + round((1 - comp_share_soc)*comp_price,6);           % calculate DR buy price

new_buy_volumes = buy_volumes;
new_buy_prices = buy_prices;

for step_nr = 1:numel(DR_price_steps_up)                                                    % add IA offer curve points to the new buy price and volume curves at the appropriate places
    change_idxs = new_buy_prices<=DR_price_steps_up(step_nr);
    break_idx = find(change_idxs,1,'last');
    if ~ismember(DR_price_steps_up(step_nr),buy_prices) && DR_vol_steps(step_nr) > 0
        new_buy_volumes = [new_buy_volumes(1:break_idx) + DR_vol_steps(step_nr); interp1(buy_prices,buy_volumes,DR_price_steps_up(step_nr)) + sum(DR_vol_steps(1:step_nr)); interp1(buy_prices,buy_volumes,DR_price_steps_up(step_nr)) + sum(DR_vol_steps(1:step_nr)) - DR_vol_steps(step_nr); new_buy_volumes(break_idx+1:end)];
        new_buy_prices = [new_buy_prices(1:break_idx); DR_price_steps_up(step_nr); DR_price_steps_up(step_nr); new_buy_prices(break_idx+1:end)];
    elseif ismember(DR_price_steps_up(step_nr),buy_prices) && DR_vol_steps(step_nr) > 0
        new_buy_volumes = [new_buy_volumes(1:break_idx) + DR_vol_steps(step_nr); new_buy_volumes(break_idx:end)];
        new_buy_prices = [new_buy_prices(1:break_idx); new_buy_prices(break_idx:end)];
    end
end

% calculate the changed MCP and MCV
[MCV2, MCP2] = intersections(new_buy_volumes,new_buy_prices,new_sell_volumes,new_sell_prices);

DR_sold_volume = intersections([0,99999],[MCP2,MCP2],buy_volumes,buy_prices) - intersections([0,99999],[MCP2,MCP2],sell_volumes,sell_prices); % negative value implies load increase DR
DR_sold_volume = round(DR_sold_volume,12); % to avoid floating point issues

%% Calculate the surpluses and their change
% prepare curves for area calculations via trapezoidal integration
new_buy_volumes = [new_buy_volumes; 0]; % add the points necessary to connect the curves to the y-axis
new_buy_prices = [new_buy_prices; 3000];    % 3000 €/MWh was the price ceiling in 2018, if the function is used for other data it has to be adjusted (or optimally - identified programmatically)
new_sell_volumes = [0; new_sell_volumes];
new_sell_prices = [-500; new_sell_prices];  % -500 €/MWh was the price floor in 2018, if the function is used for other data it has to be adjusted (or optimally - identified programmatically)

% if the MCV2 or MCP2 are not among the defined curve points in the respective variables, they need to be added for the integretion to be accurate
if ~ismember(MCV2,new_sell_volumes)
    add_idx = find(new_sell_volumes>MCV2,1,'first');
    new_sell_volumes = [new_sell_volumes(1:add_idx-1); MCV2; new_sell_volumes(add_idx:end)];
    new_sell_prices = [new_sell_prices(1:add_idx-1); MCP2; new_sell_prices(add_idx:end)];
end
if ~ismember(MCP2,new_sell_prices)
    add_idx = find(new_sell_prices>MCP2,1,'first');
    new_sell_prices = [new_sell_prices(1:add_idx-1); MCP2; new_sell_prices(add_idx:end)];
    new_sell_volumes = [new_sell_volumes(1:add_idx-1); MCV2; new_sell_volumes(add_idx:end)];
end

if ~ismember(MCV2,new_buy_volumes)
    add_idx = find(new_buy_volumes<MCV2,1,'first');
    new_buy_volumes = [new_buy_volumes(1:add_idx-1); MCV2; new_buy_volumes(add_idx:end)];
    new_buy_prices = [new_buy_prices(1:add_idx-1); MCP2; new_buy_prices(add_idx:end)];
end
if ~ismember(MCP2, new_buy_prices)
    add_idx = find(new_buy_prices>MCP2,1,'first');
    new_buy_volumes = [new_buy_volumes(1:add_idx-1); MCV2; new_buy_volumes(add_idx:end)];
    new_buy_prices = [new_buy_prices(1:add_idx-1); MCP2; new_buy_prices(add_idx:end)];
end

% calculate producer surplus and gross consumer surplus (i.e., these are
% the surpluses that arise from the market bid and offer curves
prod_surplus = MCP2*1000*MCV2 - trapz(1000*new_sell_volumes(new_sell_volumes<=MCV2),new_sell_prices(new_sell_volumes<=MCV2)); % all surpluses in €
con_surplus = trapz(1000*flip(new_buy_volumes(new_buy_volumes<=MCV2)),flip(new_buy_prices(new_buy_volumes<=MCV2))) - MCP2*1000*MCV2;

compensation = 1000*DR_sold_volume*round(comp_share_soc*comp_price,6); % value in €

end
