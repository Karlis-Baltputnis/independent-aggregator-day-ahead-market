# independent-aggregator-day-ahead-market

These are the **MATLAB** scripts and functions used to prepare the calculations for the manuscript:  
  
K. Baltputnis, T. Schittekatte, Z. Broka,  
**Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?**

The workflow is as follows:
1) Download the system price curve data reports from Nord Pool website using the script _bid_downloader.m_. If the command window displays a warning regarding the failure of downloading data for any particular days, the missing files have to manually be downloaded from https://www.nordpoolgroup.com/en/elspot-price-curves/
2) Ensure that the demand response settings are input as expected in _Input_settings_ms.xlsx_ (the '__ms_' suffix here and elsewhere denotes that the calculations concern multi-step DR curves).
3) Run the _Full_year_ms.m_ script. It will save its results in the working directory in file _main_results.mat_, as well as processed input settings in files _settings_array.mat_ and _DR_curve.mat_
4) Run the _DR_surplus_change_ms__.m_ script. It will save its results in the working directory in file _DR_surplus_change.mat_
5) Run the _post_proc_ms.m_ script. It will provide an interactive interface to visualize the main metrics of interest. Likewise these metrics and their components will be available in the active workspace via MATLAB's interface.

The workflow was last validated on 2024-02-01 using MATLAB R2021a.

After manuscript acceptance, the repository will be archived and registered on Zenodo.
