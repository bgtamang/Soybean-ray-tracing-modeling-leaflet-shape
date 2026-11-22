"""Fit PROSPECT-D to the mean leaf spectrum of each site and row spacing

Purpose
    Averages the per-plot spectra within each site x row spacing combination (SoyFACE and Energy
    Farm, 38-cm and 76-cm rows) and inverts PROSPECT-D (Féret et al., 2017; prosail package)
    against each mean spectrum over 400-2400 nm by bounded nonlinear least squares (scipy
    least_squares, trust-region reflective method). The fitted parameters are the leaf structure
    parameter N, carotenoids Car (ug cm-2), equivalent water thickness Cw (g cm-2), the
    senescent-pigment parameter Cs and anthocyanins Cant (ug cm-2). Leaf chlorophyll (LCC,
    PROSPECT Cab) and LMA (Cm) are held at dataset means during the fit, to avoid the degeneracy
    of estimating all parameters from reflectance alone (Jacquemoud & Baret, 1990; Féret et al.,
    2008, 2017). The fixed values are the rounded means of the August survey, LCC 64.45 ug cm-2
    (LCC = 1.26 x SPAD + 6.63 at the mean SPAD of 45.89) and LMA 0.00476 g cm-2 (47.55 g m-2).
    The four parameter sets are Table S11 (Methods S1.3) and drive the per-plot forward runs in
    06_prospect_forward_per_plot.py.

Inputs
    outputs/leaf_inputs/spectra_combined_per_plot.csv   per-plot spectra (03_combine_spectra.py)
    data/plots/plot_map.csv                             Site and Spacing of each Loc_ID

Outputs
    outputs/leaf_inputs/prospect_parameters_per_site_spacing.csv
        one row per combination with cell (site and row spacing in inches, 15 = 38-cm rows,
        30 = 76-cm rows), n_plots, N, Car, Cw, Cs, Cant, fit_cost (half the sum of squared
        residuals) and RMSE_fit_band (root-mean-square error over 400-2400 nm)

Usage
    python code/1_leaf_inputs/leaf_optics/04_fit_prospect_per_site_spacing.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used), numpy, scipy, prosail (2.0.5 used)
"""

import os
import pandas as pd
import numpy as np
import prosail
from scipy.optimize import least_squares
from pathlib import Path
from datetime import datetime

ROOT       = Path(os.environ.get("PACKAGE_ROOT", "."))
OUT_DIR    = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

IN_SPECTRA = OUT_DIR / "spectra_combined_per_plot.csv"
CANONICAL  = ROOT / "data" / "plots" / "plot_map.csv"
OUT_CSV    = OUT_DIR / "prospect_parameters_per_site_spacing.csv"

WL_FIT_MIN, WL_FIT_MAX = 400, 2400
LCC_FIXED = 64.45    # ug cm-2, LCC = 1.26 x SPAD + 6.63 at the mean August SPAD
LMA_FIXED = 0.00476  # g cm-2, mean August LMA

PARAM_NAMES = ["N", "Car", "Cw", "Cs", "Cant"]
INITIAL     = [1.5, 10.0, 0.015, 0.0, 0.0]
BOUNDS_LOW  = [1.0, 0.0,  0.005, 0.0, 0.0]
BOUNDS_HIGH = [3.0, 30.0, 0.05,  2.0, 30.0]


def prospect_predict(n, lcc, car, cw, cs, lma, cant):
    """Run PROSPECT-D once and return the reflectance and transmittance spectra (400-2500 nm)."""
    _, r, t = prosail.run_prospect(
        n=n, cab=lcc, car=car, cbrown=cs, cw=cw, cm=lma, ant=cant,
        prospect_version='D',
    )
    return r, t


def fit_one_group(mean_R, obs_wl):
    """Fit N, Car, Cw, Cs and Cant to one mean reflectance spectrum."""
    wl_fit_mask = (obs_wl >= WL_FIT_MIN) & (obs_wl <= WL_FIT_MAX)

    def residuals(params):
        n, car, cw, cs, cant = params
        r_pred, _ = prospect_predict(n, LCC_FIXED, car, cw, cs, LMA_FIXED, cant)
        return mean_R[wl_fit_mask] - r_pred[wl_fit_mask]

    res = least_squares(residuals, x0=INITIAL, bounds=(BOUNDS_LOW, BOUNDS_HIGH),
                        method='trf', loss='linear', max_nfev=500)
    fitted = dict(zip(PARAM_NAMES, res.x))
    r_pred, _ = prospect_predict(fitted["N"], LCC_FIXED, fitted["Car"], fitted["Cw"],
                                  fitted["Cs"], LMA_FIXED, fitted["Cant"])
    rmse_fit_band = float(np.sqrt(((mean_R[wl_fit_mask] - r_pred[wl_fit_mask])**2).mean()))
    return fitted, float(res.cost), rmse_fit_band


def main():
    t0 = datetime.now()
    print("[04_fit_prospect_per_site_spacing]")

    spec = pd.read_csv(IN_SPECTRA)
    canonical = pd.read_csv(CANONICAL).dropna(subset=["Site","Spacing"])
    # Combination label <Site>_<Spacing>, for example SF_30
    canonical["cell"] = canonical["Site"] + "_" + canonical["Spacing"].astype(int).astype(str)
    spec_meta = spec.merge(canonical[["Loc_ID","cell"]], on="Loc_ID", how="left").dropna(subset=["cell"])

    wl_cols = [c for c in spec_meta.columns if c.startswith("R_") and c[2:].isdigit()]
    obs_wl  = np.array([int(c[2:]) for c in wl_cols])

    rows = []
    for cell in sorted(spec_meta["cell"].unique()):
        sub = spec_meta[spec_meta["cell"] == cell]
        mean_R = sub[wl_cols].mean(axis=0).values
        fitted, cost, rmse = fit_one_group(mean_R, obs_wl)
        rows.append({"cell": cell, "n_plots": len(sub),
                     **fitted, "fit_cost": cost, "RMSE_fit_band": rmse})
        print(f"  {cell:6s} n={len(sub):3d}  N={fitted['N']:.4f}  Car={fitted['Car']:.3f}  "
              f"Cw={fitted['Cw']:.6f}  Cs={fitted['Cs']:.4f}  Cant={fitted['Cant']:.4f}  RMSE={rmse:.5f}")

    pd.DataFrame(rows).to_csv(OUT_CSV, index=False)
    print(f"\n  wrote: outputs/leaf_inputs/{OUT_CSV.name}")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"[04_fit_prospect_per_site_spacing] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
