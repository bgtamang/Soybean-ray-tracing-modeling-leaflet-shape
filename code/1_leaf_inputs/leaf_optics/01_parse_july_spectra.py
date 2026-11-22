"""Parse the July leaf reflectance spectra from the ASD binary files

Purpose
    Reads every ASD FieldSpec file of the late-July 2024 leaf campaign (contact probe with leaf
    clip, one file per scan) listed in the campaign inventory and writes one row per scan with its
    plot metadata and its reflectance at every 1 nm from 400 to 2500 nm. The files are read with
    specdal. Each spectrum is checked for wavelength coverage and for reflectance outside [0, 1]
    (tolerance 0.001). A spectrum that fails a check is flagged and kept. The spectra are averaged
    per plot in 02_average_spectra_per_plot.py and feed the per-plot spectra of Fig. S3A and the
    PROSPECT-D fits of Table S11.

Inputs
    data/leaf/july_campaign/inventory.csv       one row per ASD file with filename_rel (relative
                                                to data/leaf/july_campaign), site, spacing, field
                                                position, scan number (rep), Loc_ID, line and
                                                leaflet type
    data/leaf/july_campaign/<filename_rel>      ASD FieldSpec binary files

Outputs
    outputs/leaf_inputs/spectra_july_per_scan.csv      one row per scan: 12 metadata columns and
                                                       R_400 ... R_2500
    outputs/leaf_inputs/spectra_july_parse_flags.csv   files that failed a check (written only
                                                       when at least one file is flagged)

Usage
    python code/1_leaf_inputs/leaf_optics/01_parse_july_spectra.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used), numpy, specdal (0.2.1 used)
"""

import os
import pandas as pd
import numpy as np
from pathlib import Path
from specdal import Spectrum
from datetime import datetime

ROOT       = Path(os.environ.get("PACKAGE_ROOT", "."))
JULY_DIR   = ROOT / "data" / "leaf" / "july_campaign"
INVENTORY  = JULY_DIR / "inventory.csv"
OUT_DIR    = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_CSV    = OUT_DIR / "spectra_july_per_scan.csv"
VALID_LOG  = OUT_DIR / "spectra_july_parse_flags.csv"

WL_MIN = 400
WL_MAX = 2500


def main():
    t0 = datetime.now()
    print("[01_parse_july_spectra]")

    inv = pd.read_csv(INVENTORY)
    print(f"  inventory rows: {len(inv)}")

    target_wls = list(range(WL_MIN, WL_MAX + 1))      # 400..2500 nm inclusive, 2101 columns
    out_rows = []
    log_rows = []

    for i, row in inv.iterrows():
        rel = row["filename_rel"]
        fp = JULY_DIR / rel
        flags = []

        if not fp.exists():
            flags.append("FILE_MISSING")
            log_rows.append({
                "filename_rel": rel,
                "Loc_ID": row.get("Loc_ID", ""),
                "validation_flag": ";".join(flags),
            })
            continue

        try:
            s = Spectrum(filepath=str(fp))
            spec = s.measurement
        except Exception as e:
            flags.append(f"PARSE_ERROR:{type(e).__name__}")
            log_rows.append({
                "filename_rel": rel,
                "Loc_ID": row.get("Loc_ID", ""),
                "validation_flag": ";".join(flags),
            })
            continue

        # Wavelength coverage
        if spec.index.min() > WL_MIN or spec.index.max() < WL_MAX:
            flags.append(f"RANGE_BAD:{spec.index.min():.0f}-{spec.index.max():.0f}")

        # Reflectance within [0, 1], with a small tolerance
        oob = ((spec < -0.001) | (spec > 1.001)).sum()
        if oob > 0:
            flags.append(f"OOB_REFL:{oob}px")

        # Put the spectrum on the 1-nm grid, interpolating linearly where a wavelength is missing
        spec_int = spec.reindex(target_wls)
        if spec_int.isna().any():
            spec_int = (
                spec.reindex(spec.index.union(target_wls))
                    .interpolate("index")
                    .reindex(target_wls)
            )
            if spec_int.isna().any():
                flags.append(f"INTERP_FAIL:{spec_int.isna().sum()}nans")

        if flags:
            log_rows.append({
                "filename_rel": rel,
                "Loc_ID": row.get("Loc_ID", ""),
                "validation_flag": ";".join(flags),
            })

        out_row = {
            "filename_rel":  rel,
            "site":          row.get("site"),
            "spacing":       row.get("spacing"),
            "pass_raw":      row.get("pass_raw"),
            "range_raw":     row.get("range_raw"),
            "rep":           row.get("rep"),
            "Loc_ID":        row.get("Loc_ID"),
            "genotype_ID":   row.get("genotype_ID"),
            "Leaf_type":     row.get("Leaf_type"),
            "Line":          row.get("Line"),
            "parse_status":  row.get("parse_status"),
            "validation_flag": ";".join(flags) if flags else "",
        }
        for wl in target_wls:
            v = spec_int.loc[wl]
            out_row[f"R_{wl}"] = float(v) if not pd.isna(v) else np.nan
        out_rows.append(out_row)

        if (i + 1) % 200 == 0:
            print(f"  processed {i+1}/{len(inv)} files...")

    df_out = pd.DataFrame(out_rows)
    print(f"\n  parsed: {len(df_out)} files -> {OUT_CSV.name}")
    print(f"  columns: {len(df_out.columns)} (12 metadata + {len(target_wls)} wavelengths)")
    df_out.to_csv(OUT_CSV, index=False)

    if log_rows:
        df_log = pd.DataFrame(log_rows)
        df_log.to_csv(VALID_LOG, index=False)
        print(f"  flags raised on {len(df_log)} files -> {VALID_LOG.name}")
    else:
        print(f"  no flags raised")

    # Summary
    print(f"\n  Summary:")
    print(f"    Files parsed              : {len(df_out)}")
    if "Loc_ID" in df_out.columns:
        valid_loc = df_out["Loc_ID"].dropna()
        valid_loc = valid_loc[valid_loc != ""]
        print(f"    Unique Loc_IDs            : {valid_loc.nunique()}")
        rep_counts = df_out.dropna(subset=["Loc_ID"]).groupby("Loc_ID").size()
        if len(rep_counts) > 0:
            print(f"    Scans per plot mean/min/max: {rep_counts.mean():.1f} / {rep_counts.min()} / {rep_counts.max()}")
    for wl in [450, 550, 680, 800, 1500]:
        col = f"R_{wl}"
        if col in df_out.columns:
            v = df_out[col].dropna()
            if len(v) > 0:
                print(f"    R_{wl} nm: n={len(v)}, mean={v.mean():.4f}, range=[{v.min():.4f}, {v.max():.4f}]")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"\n[01_parse_july_spectra] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
