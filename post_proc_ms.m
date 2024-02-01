% post_proc_ms – postprocessing of the market clearing simulation results,
% to summarize the various metrics of interest for the manuscript
% K. Baltputnis, T. Schittekatte, Z. Broka, 
% Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

% The script reads various data from prior calculation steps that have been
% saved in .mat files. The results are available in the respective variables in the workspace.

clear

%% initial preparation
% load the settings
load('settings_array.mat');
comp_share_soc = settings_array(1,1):settings_array(1,2):settings_array(1,3);   % in percentage
comp_price = settings_array(5,1);                                               % in €/MWh

% load the DR curve (DR_price_steps and DR_vol_steps)
load('DR_curve.mat');

% load the results of the price recalculation loop
load('main_results.mat');
% these 3-D arrays have the following dimensions – (1) Hour-of-year, (2) share of comp. socialized, (3) DR curve (none, uniform, "expensive", "cheap")
size_arr = size(MCP2);

load('DR_surplus_change.mat');

compensation = DR_sold_volume.*(comp_price.*comp_share_soc)*1000;
compensation_IA_part = DR_sold_volume.*(comp_price.*(1-comp_share_soc))*1000/1000000; % M€

% seperate the original (i.e., zero additional DR case)
MCP1 = MCP2(:,1,1);

%% find hourly values
% calculate IA revenue from the DA market
IA_rev_hourly = MCP2.*DR_sold_volume*1000/1000000;            % M€ (the '*1000' converts MCV2 from GWh to MWh, and the '/1000000' converts the result from € to M€)

% calculate metrics of interest
delta_prod_surplus_hourly = prod_surplus - prod_surplus(:,1,1,1);           % in the paper, this is Producer surplus change
delta_con_surplus_hourly = con_surplus - con_surplus(:,1,1,1);              % in the paper, this is Gross consumer surplus change
delta_surplus_hourly = delta_prod_surplus_hourly + delta_con_surplus_hourly;
consumer_net_benefit = delta_con_surplus_hourly - compensation + DR_surplus_change; % in the paper, this is Overall net benefit
overall_net_benefit = delta_surplus_hourly - compensation + DR_surplus_change;      % in the paper, this is Consumer net benefit

%% find annual sum values
% the 2-D sum arrays have the following dimensions – (1) share of comp. socialized, (2) DR curve name (none, uniform, "expensive", "cheap")
DR_sold_volume_sum = sum(abs(DR_sold_volume));                        % GWh NB! We sum both load-increase and reduce DR MWhs in absolute values here!
DR_sold_volume_sum = reshape(DR_sold_volume_sum, size_arr(2:end));
MCV2_sum = sum(MCV2);                                                 % GWh
MCV2_sum = reshape(MCV2_sum, size_arr(2:end));
compensation_sum = sum(compensation);                                 % €, in the paper, this is Compensation (IA part)
compensation_sum = reshape(compensation_sum, size_arr(2:end));
consumer_net_benefit_sum = reshape(sum(consumer_net_benefit),size_arr(2:end));
overall_net_benefit_sum = reshape(sum(overall_net_benefit),size_arr(2:end));

% Let's calculate the metrics needed to establish the IA profitability
IA_rev_sum = sum(IA_rev_hourly);                                      % M€, in the paper, this is Income from DAM
IA_rev_sum = reshape(IA_rev_sum, size_arr(2:end));
compensation_IA_part_sum = sum(compensation_IA_part);                 % M€
compensation_IA_part_sum = reshape(compensation_IA_part_sum, size_arr(2:end));

% Let's define IA profit as (income from DAM) minus un-socialized compensation minus "activation cost".
% We already have the income from DAM (IA_rev_hourly; IA_rev_sum) and the unsoc. comp. (compensation_IA_part; compensation_IA_part_sum).
% But what are the activation costs (or benefits in load-increase case)?

% Let's again construct the consumption curve (same as in DR_surplus_calc.m) and make the acivation curve out of it (as in the input excel)

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

DR_act_vol = DR_flex_vol - DR_flex_vol_nom;
DR_act_price = flip(DR_flex_price) - comp_price;

% find index for the "nominal consumption", i.e., when no DR is sold in either direction
idx_0 = size(DR_act_vol,1)/2;

% calculate the hourly "activation cost"
IA_activ_cost = zeros(size_arr);
for hour_numb = 1:size_arr(1)
    for comp_share_soc_iter = 1:size_arr(2)
        for DR_curve_nr = 1:size_arr(3)
            % for load-reducing DR
            DR_sv = DR_sold_volume(hour_numb,comp_share_soc_iter,DR_curve_nr)*1000;
            if DR_sv > 0
                idx_a = find(DR_act_vol(:,DR_curve_nr) <= DR_sv, 1, 'last');
                IA_activ_cost(hour_numb,comp_share_soc_iter,DR_curve_nr) = trapz([DR_act_vol(idx_0:idx_a, DR_curve_nr); DR_sv],[DR_act_price(idx_0:idx_a,DR_curve_nr); DR_act_price(idx_a,DR_curve_nr)]); 
            end
            
            % for load-increasing DR
            if DR_sv < 0
                idx_a = find(DR_act_vol(:,DR_curve_nr) >= DR_sv, 1, 'first');
                IA_activ_cost(hour_numb,comp_share_soc_iter,DR_curve_nr) = trapz([DR_sv; DR_act_vol(idx_a:idx_0, DR_curve_nr)],[DR_act_price(idx_a,DR_curve_nr); DR_act_price(idx_a:idx_0,DR_curve_nr)]); 
            end
        end
    end
end

IA_activ_cost = IA_activ_cost/1000000; % M€
IA_activ_cost_sum = reshape(sum(IA_activ_cost),size_arr(2:end));

IA_profit_hourly = IA_rev_hourly - compensation_IA_part - IA_activ_cost;    % M€
IA_profit_sum = reshape(sum(IA_profit_hourly),size_arr(2:end)); %./DR_flex_vol_nom; % M€/(MW of DR capacity)

%% express key outcomes relative to various parameters
% relative to total energy traded in DAM – €/MWh of total energy traded in DAM
overall_net_benefit_per_MCV = overall_net_benefit_sum./MCV2_sum/1000;    % '/1000' to convert from GWh to MWh
consumer_net_benefit_per_MCV = consumer_net_benefit_sum./MCV2_sum/1000;
IA_profit_per_MCV = IA_profit_sum./MCV2_sum/1000*1000000;                % '*1000000' to convert from M€ to €

% relative to DR energy sold – €/MWh of DR energy sold in DA
overall_net_benefit_per_DR_sold = overall_net_benefit_sum./DR_sold_volume_sum/1000;    
consumer_net_benefit_per_DR_sold = consumer_net_benefit_sum./DR_sold_volume_sum/1000;
IA_profit_per_DR_sold = IA_profit_sum./DR_sold_volume_sum/1000*1000000;


% relative to "installed" DR capacity (i.e., DR bid at any one hour – equals the varied IA max bid volume parameter) – €/MW of IA DR capacity
overall_net_benefit_per_DR_cap = overall_net_benefit_sum./sum(DR_vol_steps)/1000;    % '/1000' to convert from GW to MW
consumer_net_benefit_per_DR_cap = consumer_net_benefit_sum./sum(DR_vol_steps)/1000;
IA_profit_per_DR_cap = IA_profit_sum./sum(DR_vol_steps)/1000*1000000;

%% draw figure/s – for the time being, only draw one, and allow drawing other's from elsewhere

% create UI panel
ui_pan = uifigure;
ui_pan.Position = [689, 86, 620, 300];
ui_drop_one = uidropdown(ui_pan);
ui_drop_one.Position = [415 220 200 30];
ui_drop_one.Items = {'overall_net_benefit_per_MCV','consumer_net_benefit_per_MCV','IA_profit_per_MCV',...
    'overall_net_benefit_per_DR_sold','consumer_net_benefit_per_DR_sold','IA_profit_per_DR_sold',...
    'overall_net_benefit_per_DR_cap','consumer_net_benefit_per_DR_cap','IA_profit_per_DR_cap'};
ui_drop_one.Value = 'overall_net_benefit_per_MCV';
ui_label_one = uilabel(ui_pan,'Position', [450 240 200 30], 'Text', 'Select result variable to plot:','FontWeight', 'bold');
ui_axes = uiaxes(ui_pan,'Position',[20,20,400,250]);
ui_button = uibutton(ui_pan,'Text', 'REDRAW', 'Position', [450 30 150 30], 'FontSize', 14, 'FontWeight', 'bold',...
    'ButtonPushedFcn', {@redraw_plots,ui_axes,ui_drop_one});

redraw_plots([],[],ui_axes,ui_drop_one);

% function to execute drawing of any variable w any plotting options
function redraw_plots(~, ~,ui_axes,ui_drop_one)
% interpret plotting settings
variable_to_plot = ui_drop_one.Value;

% identify variable to plot
plot_variable = evalin('base',variable_to_plot);
x_variable = evalin('base','comp_share_soc');
plot(ui_axes,x_variable,plot_variable(:,2:end));
ui_axes.XLabel.String = 'Share of compensation socialized';
ui_axes.Title.String = strrep(variable_to_plot,'_',' ');
legend(ui_axes,{'Uniform DR','"Expensive" DR','"Cheap" DR'},'Location','best');
end
