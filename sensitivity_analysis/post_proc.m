% post_proc – postprocessing of the market clearing simulation results,
% to summarize the various metrics of interest for the sensitivity analyses in the manuscript
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

% The script reads various data from prior calculation steps that have been
% saved in .mat files. The results are available in the respective variables in the workspace.

% load the settings
load('settings_array.mat');
comp_share_soc = settings_array(1,1):settings_array(1,2):settings_array(1,3);   % in percentage
DR_act_cost = settings_array(2,1):settings_array(2,2):settings_array(2,3);      % in €/MWh
DR_bid_vol = settings_array(3,1):settings_array(3,2):settings_array(3,3);       % in MWh/h
comp_price = settings_array(5,1);                                               % in €/MWh

% load the results of the price recalculation loop
load('main_results.mat');

% this 4-D array hase the following dimensions – (1) Hour-of-year, (2) DR bid volume, (3) DR activation cost, (4) share of comp. socialized
size_arr = size(MCP2);

load('DR_surplus_change.mat');

% seperate the original (i.e., zero DR case)
MCP1 = MCP2(:,1,1,1);

%% find hourly values
% calculate deltaMCP
deltaMCP_hourly = -MCP2 + MCP1;                               % €/MWh

% calculate DA cost reduction
DA_cost_red_hourly = deltaMCP_hourly.*MCV2*1000/1000000;      % M€ (the '*1000' converts MCV2 from GWh to MWh, and the '/1000000' converts the result from € to M€)

% calculate IA revenue from the DA market
IA_rev_hourly = MCP2.*DR_sold_volume*1000/1000000;         % M€

% calculate net benefit (producer and gross consumer surplus change sum)
delta_prod_surplus_hourly = prod_surplus - prod_surplus(:,1,1,1);
delta_con_surplus_hourly = con_surplus - con_surplus(:,1,1,1);
delta_surplus_hourly = delta_prod_surplus_hourly + delta_con_surplus_hourly;
overall_net_benefit_hourly = delta_surplus_hourly - compensation + DR_surplus_change;
consumer_net_benefit_hourly = delta_con_surplus_hourly - compensation + DR_surplus_change;

%% find annual sum values
% the 3-D sum arrays have the following dimensions – (1) DR bid volume, (2) DR activation cost, (3) share of comp. socialized
DR_sold_volume_sum = sum(DR_sold_volume);                             % GWh
DR_sold_volume_sum = reshape(DR_sold_volume_sum, size_arr(2:end));
IA_rev_sum = sum(IA_rev_hourly);                                % M€
IA_rev_sum = reshape(IA_rev_sum, size_arr(2:end));
MCV2_sum = sum(MCV2);                                                 % GWh
MCV2_sum = reshape(MCV2_sum, size_arr(2:end));
overall_net_benefit_sum = sum(overall_net_benefit_hourly);
overall_net_benefit_sum = reshape(overall_net_benefit_sum, size_arr(2:end));
consumer_net_benefit_sum = reshape(sum(consumer_net_benefit_hourly),size_arr(2:end));

% overall_net_benefit_norm = reshape(mean(overall_net_benefit_hourly./MCV2/1000), size_arr(2:end)); % net benefit €/MWh MCV normalized
% consumer_net_consumer_benefit_norm = reshape(mean(consumer_net_benefit_hourly./MCV2/1000), size_arr(2:end));

% calculate IA profitability
IA_exp_activ_sum = DR_sold_volume_sum.*DR_act_cost*1000/1000000;                                                     % M€ – sum cost for DR activation
IA_exp_comp_sum = DR_sold_volume_sum.*(comp_price*reshape(1-comp_share_soc,[1 size(comp_share_soc)]))*1000/1000000;  % M€ – sum cost for IA comp.
IA_profit_sum = IA_rev_sum - IA_exp_activ_sum - IA_exp_comp_sum;                                                     % M€ – sum IA "profitability"

%% express key outcomes relative to various parameters
% relative to total energy traded in DA – €/MWh of total energy traded in DA
IA_profit_per_MCV = 1000000*IA_profit_sum./MCV2_sum/1000;
overall_net_benefit_per_MCV = overall_net_benefit_sum./MCV2_sum/1000;
consumer_net_benefit_per_MCV = consumer_net_benefit_sum./MCV2_sum/1000;

% relative to DR energy sold – €/MWh of DR energy sold in DA
IA_profit_per_DR_sold = 1000000*IA_profit_sum./DR_sold_volume_sum/1000;
overall_net_benefit_per_DR_sold = overall_net_benefit_sum./DR_sold_volume_sum/1000;
consumer_net_benefit_per_DR_sold = consumer_net_benefit_sum./DR_sold_volume_sum/1000;

% relative to "installed" DR capacity (i.e., DR bid at any one hour – equals the varied IA max bid volume parameter) – €/MW of IA DR capacity
IA_profit_per_DR_cap = 1000000*IA_profit_sum./DR_bid_vol';
overall_net_benefit_per_DR_cap = 1000000*overall_net_benefit_sum./DR_bid_vol';
consumer_net_benefit_per_DR_cap = consumer_net_benefit_sum./DR_bid_vol';

%% draw figure/s – for the time being, only draw one, and allow drawing other's from elsewhere

% create UI panel
ui_pan = uifigure;
ui_pan.Position = [689, 86, 620, 300];
ui_drop_one = uidropdown(ui_pan);
ui_drop_one.Position = [415 220 200 30];
ui_drop_one.Items = {'IA_profit_per_MCV','overall_net_benefit_per_MCV','consumer_net_benefit_per_MCV'...
    'IA_profit_per_DR_sold','overall_net_benefit_per_DR_sold','consumer_net_benefit_per_DR_sold',...
    'IA_profit_per_DR_cap', 'overall_net_benefit_per_DR_cap','consumer_net_benefit_per_DR_cap'};
ui_drop_one.Value = 'overall_net_benefit_per_MCV';
ui_label_one = uilabel(ui_pan,'Position', [450 240 200 30], 'Text', 'Select result variable to plot:','FontWeight', 'bold');

ui_drop_two = uidropdown(ui_pan);
ui_drop_two.Position = [5 90 610 30];
ui_drop_two.Items = {'On X-axis: DR bid volume. With seperate lines: DR activation cost. In diff. figures: Share of comp. socialized.'
'On X-axis: DR bid volume. With seperate lines: Share of comp. socialized. In diff. figures: DR activation cost.'
'On X-axis: DR activation cost. With seperate lines: DR bid volume. In diff. figures: Share of comp. socialized.'
'On X-axis: DR activation cost. With seperate lines: Share of comp. socialized. In diff. figures: DR bid volume.'
'On X-axis: Share of comp. socialized. With seperate lines: DR activation cost. In diff. figures: DR bid volume.'
'On X-axis: Share of comp. socialized. With seperate lines: DR bid volume. In diff. figures: DR activation cost.'};
ui_label_two = uilabel(ui_pan,'Position', [450 110 200 30], 'Text', 'Select the options for plotting:','FontWeight', 'bold');

ui_button = uibutton(ui_pan,'Text', 'REDRAW', 'Position', [259 30 150 30], 'FontSize', 14, 'FontWeight', 'bold',...
'ButtonPushedFcn', {@redraw_plots,ui_drop_one,ui_drop_two});

redraw_plots([],[],ui_drop_one,ui_drop_two);

% function to execute drawing of any variable w any plotting options
function redraw_plots(~, ~,ui_drop_one,ui_drop_two)
% interpret plotting settings
variable_to_plot = ui_drop_one.Value;
plot_options = find(contains(ui_drop_two.Items,ui_drop_two.Value));
plot_str = ui_drop_two.Value;
options_var_map = [1 2 3; 1 3 2; 2 1 3; 2 3 1; 3 2 1; 3 1 2];
options_var_key = {'DR_bid_vol', 'DR_act_cost', 'comp_share_soc'};
options_num_key = options_var_map(plot_options,:);
O1 = figure('units','normalized','outerposition',[0 0 1 1]);
O1.NumberTitle = 'off';
O1.Name = plot_str;
x_axis_var = evalin('base',options_var_key{:,options_var_map(plot_options,1)});
line_var = evalin('base',options_var_key{:,options_var_map(plot_options,2)});
subfigure_var = evalin('base',options_var_key{:,options_var_map(plot_options,3)});
numb_of_plots = numel(subfigure_var);
plot_grid = dim_find(numb_of_plots);

% identify variable to plot
plot_variable = evalin('base',variable_to_plot);

% plot
for idx = 1:numb_of_plots
    subplot(plot_grid(1),plot_grid(2),idx);
    switch options_num_key(3)
        case 1
            plot(x_axis_var',squeeze(plot_variable(idx,:,:)));
            title(['DR bid volume = ' num2str(subfigure_var(idx)) ' MWh/h']);
        case 2
            plot(x_axis_var',squeeze(plot_variable(:,idx,:)));
            title(['DR activation cost = ' num2str(subfigure_var(idx)) ' €/MWh']);
        case 3
            plot(x_axis_var',squeeze(plot_variable(:,:,idx)));
            title(['Share of comp. socialized = ' num2str(subfigure_var(idx)*100) '%']);
    end
    xlim([min(x_axis_var) max(x_axis_var)]);
    ylim([min(min(min(plot_variable))) max(max(max(plot_variable)))]);
    line(xlim(), [0,0], 'LineWidth', 2, 'Color', 'k');
    
    switch options_num_key(1)
        case 1
            xlabel('DR bid volume, MWh/h');
        case 2
            xlabel('DR activation cost, €/MWh');
        case 3
            xlabel('Share of compensation socialized');
    end
    ylabel(strrep(variable_to_plot,'_',' '));
end
legend_entries = compose('%g',line_var);
switch options_num_key(2)
    case 1
        legend_entries = strcat(legend_entries,' MWh/h');
    case 2
        legend_entries = strcat(legend_entries,' €/MWh');
    case 3
        legend_entries = strcat(legend_entries);
end
plot_leg = legend(legend_entries);
plot_leg.Position(1) = 0.001;
plot_leg.Position(2) = 0.35;

end

function ab = dim_find(n)
a = floor(sqrt(n));
b = round(n/a,0);
if a*b < n
    b = b + 1;
end
ab = [a b];
end