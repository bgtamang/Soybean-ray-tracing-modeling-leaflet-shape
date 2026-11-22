"""Combine the July and August per-plot leaf spectra of the BC3 plots

Purpose
    Joins the August survey spectra (one leaf per plot, 7-9 August 2024) to their plot
    identifiers, keeps the BC3 plots of the plot map in both the August and the July per-plot
    spectra, and forms their union on the wavelengths common to both. A plot measured in both
    campaigns takes its July spectrum, which was measured on the A-Ci leaf. The result is one
    spectrum per BC3 plot with its campaign (source = cascade_jul for July, baseline_aug for
    August). It is the spectrum set shown in Fig. S3A and fitted by PROSPECT-D in
    04_fit_prospect_per_site_spacing.py (Table S11).

Inputs
    data/leaf/spectra_august_per_plot.csv            August per-plot spectra (site, spacing,
                                                     plot_id, R_400 ... R_2500)
    data/canopy_inputs_base/leaf_optical_base.csv    plot table linking Site, Spacing and ID to
                                                     Loc_ID
    outputs/leaf_inputs/spectra_july_per_plot.csv    July per-plot spectra
                                                     (02_average_spectra_per_plot.py)
    data/plots/plot_map.csv                          plot map (Line identifies the BC3 plots)

Outputs
    outputs/leaf_inputs/spectra_combined_per_plot.csv   Loc_ID, R_400 ... R_2500 and source,
                                                        one row per BC3 plot

Usage
    python code/1_leaf_inputs/leaf_optics/03_combine_spectra.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used)
"""

import os
import pandas as pd
from pathlib import Path
from datetime import datetime

ROOT       = Path(os.environ.get("PACKAGE_ROOT", "."))
OUT_DIR    = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

BASELINE_SPECTRA = ROOT / "data" / "leaf" / "spectra_august_per_plot.csv"
BASELINE_MASTER  = ROOT / "data" / "canopy_inputs_base" / "leaf_optical_base.csv"
CANONICAL        = ROOT / "data" / "plots" / "plot_map.csv"

# July per-plot spectra (02_average_spectra_per_plot.py)
CAS_STEP02   = OUT_DIR / "spectra_july_per_plot.csv"
OUT_CSV      = OUT_DIR / "spectra_combined_per_plot.csv"


def main():
    t0 = datetime.now()
    print("[03_combine_spectra]")

    # ---- July per-plot spectra ----
    if not CAS_STEP02.exists():
        raise FileNotFoundError("outputs/leaf_inputs/spectra_july_per_plot.csv not found. "
                                "Run 02_average_spectra_per_plot.py first.")
    cas_fp = CAS_STEP02
    print("  July spectra: outputs/leaf_inputs/spectra_july_per_plot.csv")

    # ---- BC3 plots of the plot map ----
    canonical = pd.read_csv(CANONICAL)
    bc3_locids = set(canonical.loc[canonical["Line"] == "BC3", "Loc_ID"].unique())
    print(f"  BC3 Loc_IDs in the plot map: {len(bc3_locids)}")

    # ---- August spectra, with Loc_ID from the plot table ----
    bsl_spec = pd.read_csv(BASELINE_SPECTRA, low_memory=False)
    master  = pd.read_csv(BASELINE_MASTER)[["Site", "Spacing", "ID", "Loc_ID"]].copy()
    master["ID"] = master["ID"].astype(str)
    bsl_spec["plot_id"] = bsl_spec["plot_id"].astype(str)
    bsl_spec_loc = bsl_spec.merge(
        master.rename(columns={"Site": "site", "Spacing": "spacing", "ID": "plot_id"}),
        on=["site", "spacing", "plot_id"], how="left"
    ).dropna(subset=["Loc_ID"])
    bsl_bc3 = bsl_spec_loc[bsl_spec_loc["Loc_ID"].isin(bc3_locids)]

    # ---- July spectra ----
    cas_spec = pd.read_csv(cas_fp, low_memory=False)
    cas_bc3  = cas_spec[cas_spec["Loc_ID"].isin(bc3_locids)]

    print(f"  August BC3 spectra: {len(bsl_bc3)}")
    print(f"  July BC3 spectra:   {len(cas_bc3)}")

    # ---- Wavelengths common to both campaigns ----
    bsl_wls  = [c for c in bsl_bc3.columns  if c.startswith("R_") and c[2:].isdigit()]
    cas_wls = [c for c in cas_bc3.columns if c.startswith("R_") and c[2:].isdigit()]
    common_wls = sorted(set(bsl_wls) & set(cas_wls), key=lambda c: int(c[2:]))
    print(f"  common wavelength columns: {len(common_wls)} ({common_wls[0]}..{common_wls[-1]})")

    # ---- Union, with the July spectrum for plots measured in both campaigns ----
    bsl_keep  = bsl_bc3[["Loc_ID"] + common_wls].copy(); bsl_keep["source"] = "baseline_aug"
    cas_keep = cas_bc3[["Loc_ID"] + common_wls].copy(); cas_keep["source"] = "cascade_jul"
    overlap  = set(bsl_keep["Loc_ID"]) & set(cas_keep["Loc_ID"])
    print(f"  Loc_IDs in both campaigns: {len(overlap)} (July spectrum used)")

    bsl_only  = bsl_keep[~bsl_keep["Loc_ID"].isin(overlap)]
    combined = pd.concat([cas_keep, bsl_only], ignore_index=True)
    print(f"  BC3 spectra in the union: {len(combined)}  ({len(cas_keep)} July + {len(bsl_only)} August only)")

    combined.to_csv(OUT_CSV, index=False)
    print(f"\n  wrote: outputs/leaf_inputs/{OUT_CSV.name}")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"[03_combine_spectra] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
