These are the MATLAB scripts and functions used to prepare the sensitivity analyses in the manuscript:
K. Baltputnis, T. Schittekatte, Z. Broka,
Independent aggregation in the Nordic day-ahead market: what is the welfare impact of socializing supplier compensation payments?

The workflow is as follows:
1) Download the system price curve data reports from Nord Pool website using the script bid_downloader.m. If the command window displays a warning regarding the failure of downloading data for any particular days, the missing files have to manually be downloaded from https://www.nordpoolgroup.com/en/elspot-price-curves/
2) Ensure that the demand response sensitivity settings are input as expected in Input_settings.xlsx
3) Run the Full_year.m script. It will save its results in the working directory in file main_results.mat, as well as processed input settings in files settings_array.mat and DR_curve.mat
4) Run the DR_surplus_change.m script. It will save its results in the working directory in file DR_surplus_change.mat
5) Run the post_proc.m script. It will provide an interactive interface to visualize the main metrics of interest. Likewise these metrics and their components will be available in the active workspace via MATLAB's interface.

The workflow was last validated on 2024-02-01 using MATLAB R2021a.

Note: intermeddiate results files DR_surplus_change.mat and main_results.mat are not included in this folder due to their large size (~94 MB and ~440 MB). They can be obtained by running the scripts as described above.
