# Independent Aggregator Day-Ahead Market

MATLAB scripts and functions for the calculations presented in the following manuscript:

> Baltputnis, K., Schittekatte, T., Broka, Z. **Independent Aggregation in the Nordic Day-Ahead Market: What is the Welfare Impact of Socializing Supplier Compensation Payments?** *Heliyon*, 2025, Vol. 11, Issue 1, Article number e41619. e-ISSN 2405-8440.
>
> Available from: [doi:10.1016/j.heliyon.2024.e41619](https://www.sciencedirect.com/science/article/pii/S2405844024176505)

---

## Workflow

1. **Download bid data**  
   Use `bid_downloader.m` to download system price curve data reports from the Nord Pool website. If the command window displays warnings about failed downloads for specific days, manually retrieve the missing files from [Nord Pool Price Curves](https://www.nordpoolgroup.com/en/elspot-price-curves/).

2. **Configure demand response settings**  
   Verify that the demand response settings in `Input_settings_ms.xlsx` match your expectations. The `_ms` suffix indicates multi-step DR curve calculations.

3. **Run the main simulation**  
   Execute `Full_year_ms.m`. Results are saved to the working directory:
   - `main_results.mat` — primary simulation results
   - `settings_array.mat` — processed input settings
   - `DR_curve.mat` — demand response curve data

4. **Calculate DR surplus changes**  
   Run `DR_surplus_change_ms.m`. Results are saved to `DR_surplus_change.mat`.

5. **Post-process and visualize**  
   Execute `post_proc_ms.m` for an interactive interface to visualize key metrics. All metrics and their components remain accessible in the MATLAB workspace.

---

## Validation

This workflow was last validated on **2024-02-01** using **MATLAB R2021a**.

---

## Python version

A Python implementation of this simulation tool is available at:  
[https://github.com/flpp-signature/Market-Impact](https://github.com/flpp-signature/Market-Impact)

---

## Data availability

Intermediary and final results from the study are registered on Zenodo in both MATLAB and Python (NumPy) formats:  
[doi:10.5281/zenodo.18434501](https://doi.org/10.5281/zenodo.18434501)

---

## Acknowledgments

<table>
  <tr>
    <td><img src="https://www.lzp.gov.lv/sites/lzp/files/gallery_images/rtu_flpp_logo_purple1.jpg" alt="Logo" width="100%"></td>
    <td>This research is funded by the Latvian Council of Science, project "Multi-functional modelling tool for the significantly altering future electricity markets and their development (SignAture)", project No. lzp-2021/1-0227.</td>
  </tr>
</table>
