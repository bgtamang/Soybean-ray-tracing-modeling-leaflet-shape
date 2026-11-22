"""Per-plot PROSPECT-D forward runs and PAR and NIR band optics

Purpose
    Runs PROSPECT-D forward for every plot with the parameters fitted for its site x row spacing
    combination (N, Car, Cw, Cs and Cant, 04_fit_prospect_per_site_spacing.py) and the plot's own
    LCC (PROSPECT Cab) and LMA (Cm) from 05_combine_spad_lma.py. A plot without an LCC or LMA
    value uses the mean of the August survey (64.45 ug cm-2 or 0.00476 g cm-2, the values held
    fixed in the fitting step), and a plot outside the plot map would use the parameters of the
    SoyFACE 76-cm rows, the largest combination. Reflectance R and
    transmittance T (400-2500 nm at 1 nm) are averaged with equal weight over the PAR band
    (400-700 nm) and the NIR band (above 700 nm to 2500 nm), so 700 nm is counted once, in PAR.
    Absorptance is A = 1 - R - T in each band. These band values are the leaf optical inputs of
    the simulations (Methods S1.3, Table S10, Fig. S3C-F).

Inputs
    outputs/leaf_inputs/prospect_parameters_per_site_spacing.csv   parameters per combination
    outputs/leaf_inputs/spad_lma_per_plot.csv                      per-plot LCC and LMA
    data/plots/plot_map.csv                                        Site, Spacing and Line of each Loc_ID

Outputs
    outputs/leaf_inputs/leaf_optics_bands_per_plot.csv   Loc_ID, R_PAR, T_PAR, A_PAR, R_NIR,
                                                         T_NIR, A_NIR (one row per plot)

Usage
    python code/1_leaf_inputs/leaf_optics/06_prospect_forward_per_plot.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used), numpy, prosail (2.0.5 used)
"""

import os
import pandas as pd
import numpy as np
import prosail                      # PROSPECT-D leaf optical model (prosail package)
from pathlib import Path
from datetime import datetime

ROOT        = Path(os.environ.get("PACKAGE_ROOT", "."))
OUT_DIR     = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

PER_CELL_FP = OUT_DIR / "prospect_parameters_per_site_spacing.csv"   # one row per combination
UNIFIED_FP  = OUT_DIR / "spad_lma_per_plot.csv"                      # one row per plot
CANONICAL   = ROOT / "data" / "plots" / "plot_map.csv"
OUT_CSV     = OUT_DIR / "leaf_optics_bands_per_plot.csv"

# Band limits (nm) and the August-survey means used when a plot has no value
WL_BAND_PAR = (400, 700)
WL_BAND_NIR = (700, 2500)
LCC_FIXED   = 64.45      # ug cm-2, used when a plot has no LCC
LMA_FIXED   = 0.00476    # g cm-2, used when a plot has no LMA


def prospect_predict(n, lcc, car, cw, cs, lma, cant):
    """Run PROSPECT-D once and return the reflectance and transmittance spectra.

    prosail names the inputs cab (= LCC, ug cm-2), cbrown (= Cs, senescent pigment), ant
    (= Cant, anthocyanins) and cm (= LMA, g cm-2). The wavelength grid it also returns is always
    400-2500 nm at 1 nm and is not needed.
    """
    _, r, t = prosail.run_prospect(
        n=n, cab=lcc, car=car, cbrown=cs, cw=cw, cm=lma, ant=cant,
        prospect_version='D',
    )
    return r, t


def main():
    t0 = datetime.now()
    print("[06_prospect_forward_per_plot]")

    # --- Parameters of each site x row spacing combination ----------------------
    per_cell = pd.read_csv(PER_CELL_FP)
    cell_constants = {row["cell"]: {p: float(row[p]) for p in ["N","Car","Cw","Cs","Cant"]}
                      for _, row in per_cell.iterrows()}
    print(f"  combinations: {list(cell_constants.keys())}")

    # --- Per-plot LCC and LMA, with each plot's combination ---------------------
    unified = pd.read_csv(UNIFIED_FP)
    canonical = pd.read_csv(CANONICAL).dropna(subset=["Site","Spacing"])
    # Combination label <Site>_<Spacing> as in the fitting step (Spacing 30.0 becomes "30")
    canonical["cell"] = canonical["Site"] + "_" + canonical["Spacing"].astype(int).astype(str)
    unified = unified.merge(canonical[["Loc_ID","cell","Line"]], on="Loc_ID", how="left")

    # --- Wavelength grid and band masks -----------------------------------------
    pros_wl_grid = np.arange(400, 2501)
    # 700 nm belongs to PAR only (>= 400 and <= 700), NIR is > 700 and <= 2500.
    par_mask = (pros_wl_grid >= WL_BAND_PAR[0]) & (pros_wl_grid <= WL_BAND_PAR[1])
    nir_mask = (pros_wl_grid >  WL_BAND_NIR[0]) & (pros_wl_grid <= WL_BAND_NIR[1])

    # --- Forward run for each plot ----------------------------------------------
    rows = []
    for _, row in unified.iterrows():
        cell = row.get("cell")
        if pd.isna(cell) or cell not in cell_constants:
            # A plot outside the plot map uses the parameters of SF_30, the largest combination
            c = cell_constants.get("SF_30") or list(cell_constants.values())[0]
        else:
            c = cell_constants[cell]

        # The plot's own LCC and LMA, or the August-survey means when missing
        lcc = float(row["LCC_ugcm2"]) if pd.notna(row["LCC_ugcm2"]) else LCC_FIXED
        lma = float(row["LMA_gcm2"])  if pd.notna(row["LMA_gcm2"])  else LMA_FIXED

        r, t = prospect_predict(c["N"], lcc, c["Car"], c["Cw"], c["Cs"], lma, c["Cant"])
        # Equal-weight mean over the 1-nm grid of each band
        R_PAR = float(r[par_mask].mean()); T_PAR = float(t[par_mask].mean())
        R_NIR = float(r[nir_mask].mean()); T_NIR = float(t[nir_mask].mean())
        rows.append({
            "Loc_ID":     row["Loc_ID"],
            "R_PAR":      R_PAR,  "T_PAR": T_PAR, "A_PAR": 1.0 - R_PAR - T_PAR,
            "R_NIR":      R_NIR,  "T_NIR": T_NIR, "A_NIR": 1.0 - R_NIR - T_NIR,
        })

    # --- One row per plot -------------------------------------------------------
    out = pd.DataFrame(rows)
    out.to_csv(OUT_CSV, index=False)
    print(f"  wrote: outputs/leaf_inputs/{OUT_CSV.name}  ({len(out)} plots)")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"[06_prospect_forward_per_plot] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
