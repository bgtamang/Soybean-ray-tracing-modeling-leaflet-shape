"""Average the July leaf spectra over the scans of each plot

Purpose
    Averages the July reflectance spectra over the scans of each plot at every wavelength, giving
    one mean spectrum per plot. Scans without a plot identifier (Loc_ID) are left out. These are
    the Energy Farm scans whose field position matched two plots of a parent line. A quality table
    gives the number of scans per plot and the mean and maximum, across wavelengths, of the
    standard deviation among scans. The per-plot spectra are combined with the August spectra in
    03_combine_spectra.py (Fig. S3A, Table S11).

Inputs
    outputs/leaf_inputs/spectra_july_per_scan.csv   per-scan spectra (01_parse_july_spectra.py)

Outputs
    outputs/leaf_inputs/spectra_july_per_plot.csv      one mean spectrum per plot, with site,
                                                       spacing, genotype_ID, Leaf_type and Line
    outputs/leaf_inputs/spectra_july_per_plot_qc.csv   n_reps (scans), sd_mean_across_wl and
                                                       sd_max_across_wl per plot

Usage
    python code/1_leaf_inputs/leaf_optics/02_average_spectra_per_plot.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used), numpy
"""

import os
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

ROOT       = Path(os.environ.get("PACKAGE_ROOT", "."))
OUT_DIR    = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)
IN_CSV     = OUT_DIR / "spectra_july_per_scan.csv"
OUT_CSV    = OUT_DIR / "spectra_july_per_plot.csv"
QC_CSV     = OUT_DIR / "spectra_july_per_plot_qc.csv"

WL_MIN = 400
WL_MAX = 2500


def main():
    t0 = datetime.now()
    print("[02_average_spectra_per_plot]")

    df = pd.read_csv(IN_CSV)
    print(f"  input rows: {len(df)}")

    # Keep the scans with a plot identifier (drops the scans matched to two plots)
    df_valid = df[df["Loc_ID"].notna() & (df["Loc_ID"] != "")].copy()
    print(f"  rows with a Loc_ID: {len(df_valid)}")

    # Wavelength columns
    wl_cols = [c for c in df_valid.columns if c.startswith("R_") and c[2:].isdigit()]
    print(f"  wavelength columns: {len(wl_cols)} ({wl_cols[0]}..{wl_cols[-1]})")

    # Mean over the scans of each plot at every wavelength
    metadata_cols = ["site", "spacing", "genotype_ID", "Leaf_type", "Line"]

    meta_first = (df_valid.groupby("Loc_ID", as_index=False)
                          [metadata_cols].first())

    means = (df_valid.groupby("Loc_ID", as_index=False)
                     [wl_cols].mean())

    per_plot = meta_first.merge(means, on="Loc_ID", how="inner")
    print(f"  per-plot rows: {len(per_plot)}")
    per_plot.to_csv(OUT_CSV, index=False)
    print(f"  wrote: {OUT_CSV.name}")

    # ---- Quality table of scans per plot and spread among scans ----
    grouped = df_valid.groupby("Loc_ID")
    rep_counts = grouped.size().rename("n_reps").reset_index()
    sd_per_plot = grouped[wl_cols].std(ddof=1)
    sd_mean_per_plot = sd_per_plot.mean(axis=1).rename("sd_mean_across_wl").reset_index()
    sd_max_per_plot  = sd_per_plot.max(axis=1).rename("sd_max_across_wl").reset_index()
    qc = (rep_counts.merge(sd_mean_per_plot, on="Loc_ID")
                    .merge(sd_max_per_plot,  on="Loc_ID"))
    qc.to_csv(QC_CSV, index=False)
    print(f"  wrote: {QC_CSV.name}")

    # ---- Summary ----
    print(f"\n  Summary:")
    print(f"    Unique plots                  : {len(per_plot)}")
    print(f"    Mean scans per plot           : {rep_counts['n_reps'].mean():.2f}")
    print(f"    Scans per plot range          : {rep_counts['n_reps'].min()} -- {rep_counts['n_reps'].max()}")
    print(f"    Mean SD among scans           : {sd_mean_per_plot['sd_mean_across_wl'].mean():.5f}")
    print(f"    Plots with mean SD > 0.05     : {(sd_mean_per_plot['sd_mean_across_wl'] > 0.05).sum()}")
    for wl in [450, 550, 680, 800, 1500]:
        col = f"R_{wl}"
        if col in per_plot.columns:
            v = per_plot[col].dropna()
            print(f"    R_{wl} nm: n={len(v)}, mean={v.mean():.4f}, range=[{v.min():.4f}, {v.max():.4f}]")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"\n[02_average_spectra_per_plot] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
