"""Assemble per-plot SPAD and LMA from the July and August leaf campaigns

Purpose
    Builds one row per plot with the SPAD chlorophyll-meter reading and the leaf mass per area
    (LMA) used for its leaf optics. The July value, measured on the A-Ci leaf, is used when
    present. Otherwise the August survey value is used. The source of each value is recorded as
    cascade_jul (July), baseline_aug (August measurement), baseline_cell_mean (the August table
    held a combination mean) or missing. Leaf chlorophyll content follows
    LCC = 1.26 x SPAD + 6.63 (ug cm-2), and LMA is also given in g cm-2, the unit of PROSPECT-D.
    These values anchor the per-plot PROSPECT-D runs (06_prospect_forward_per_plot.py) and appear
    in Table S10 and Figs S1F-G and S3B.

Inputs
    data/leaf/july_campaign/SF_30in/leafscan_spad/Scan.csv                July SPAD and LMA, SoyFACE 76-cm rows
    data/leaf/july_campaign/SF_15in/leafscan_spad/SF_BC3_15inch.csv       July SPAD and LMA, SoyFACE 38-cm rows
    data/leaf/july_campaign/EF_30in/leafscan_lma/7-23-24_EF_BC_30inch.csv July SPAD and LMA, Energy Farm 76-cm rows
    data/leaf/july_campaign/EF_15in/leafscan/7-24-24_EF_BC_15inch.csv     July SPAD and LMA, Energy Farm 38-cm rows
    data/leaf/spad_lma_august_per_plot.csv                                August SPAD and LMA per plot, with
                                                                          source flags

Outputs
    outputs/leaf_inputs/spad_lma_per_plot.csv   one row per plot with the August and July values,
                                                the values used (SPAD_unified, LMA_unified_gm2)
                                                and their sources, LCC_ugcm2 and LMA_gcm2

Usage
    python code/1_leaf_inputs/leaf_optics/05_combine_spad_lma.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used), numpy
"""

import os
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

ROOT       = Path(os.environ.get("PACKAGE_ROOT", "."))
CASCADE    = ROOT / "data" / "leaf" / "july_campaign"
OUT_DIR    = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

BASELINE_LCC_LMA = ROOT / "data" / "leaf" / "spad_lma_august_per_plot.csv"
OUT_CSV    = OUT_DIR / "spad_lma_per_plot.csv"

# July sheets by (site, row spacing in inches)
CAS_SPADLMA_SRCS = {
    ("SF", 30): CASCADE / "SF_30in" / "leafscan_spad" / "Scan.csv",
    ("SF", 15): CASCADE / "SF_15in" / "leafscan_spad" / "SF_BC3_15inch.csv",
    ("EF", 30): CASCADE / "EF_30in" / "leafscan_lma"  / "7-23-24_EF_BC_30inch.csv",
    ("EF", 15): CASCADE / "EF_15in" / "leafscan"      / "7-24-24_EF_BC_15inch.csv",
}


def load_cascade_one(site, spacing, fp):
    """Read one July sheet and return Loc_ID, SPAD and LMA (g m-2) per plot."""
    df = pd.read_csv(fp)
    # The LMA column is named differently in the four sheets.
    lma_col = None
    for c in ["LMA (gm-2)", "LMA (g m-2)", "LMA_gm2", "LMA"]:
        if c in df.columns:
            lma_col = c; break
    if lma_col is None:
        raise ValueError(f"No LMA column found in {fp.name}")
    df = df[["Pass","Range","SPAD",lma_col]].rename(columns={"SPAD":"SPAD_cascade", lma_col:"LMA_cascade_gm2"})
    df = df.dropna(subset=["Pass","Range"])
    df["Pass"] = pd.to_numeric(df["Pass"], errors="coerce")
    df["Range"] = pd.to_numeric(df["Range"], errors="coerce")
    df = df.dropna(subset=["Pass","Range"])
    df["Pass"] = df["Pass"].astype(int)
    df["Range"] = df["Range"].astype(int)
    df["SPAD_cascade"]    = pd.to_numeric(df["SPAD_cascade"],    errors="coerce")
    df["LMA_cascade_gm2"] = pd.to_numeric(df["LMA_cascade_gm2"], errors="coerce")
    # Plot identifiers carry Pass + 10 for the 38-cm plots (Spacing = 15).
    df["pass_loc_id"]     = df["Pass"] + (10 if spacing == 15 else 0)
    df["Loc_ID"]          = f"{site}_" + df["pass_loc_id"].astype(str) + "_" + df["Range"].astype(str)
    return df[["Loc_ID","SPAD_cascade","LMA_cascade_gm2"]]


def main():
    t0 = datetime.now()
    print("[05_combine_spad_lma]")

    parts = []
    for (site, spacing), fp in CAS_SPADLMA_SRCS.items():
        d = load_cascade_one(site, spacing, fp)
        parts.append(d)
        print(f"  July {site}, {38 if spacing == 15 else 76}-cm rows: {len(d)} rows")
    cas = pd.concat(parts, ignore_index=True).drop_duplicates(subset=["Loc_ID"])
    print(f"  July SPAD/LMA: {len(cas)} unique Loc_IDs")

    bsl = pd.read_csv(BASELINE_LCC_LMA)[["Loc_ID","SPAD_raw","SPAD_source","LMA_raw_gm2","LMA_source"]].rename(columns={
        "SPAD_raw":"SPAD_baseline","SPAD_source":"SPAD_source_baseline",
        "LMA_raw_gm2":"LMA_baseline_gm2","LMA_source":"LMA_source_baseline"
    })

    u = bsl.merge(cas, on="Loc_ID", how="outer")

    # July value first, then the August value
    u["SPAD_unified"]       = u["SPAD_cascade"].where(u["SPAD_cascade"].notna(), u["SPAD_baseline"])
    u["SPAD_source_unified"] = np.where(u["SPAD_cascade"].notna(), "cascade_jul",
                                np.where(u["SPAD_baseline"].notna(),
                                  np.where(u["SPAD_source_baseline"] == "measured", "baseline_aug", "baseline_cell_mean"),
                                  "missing"))

    u["LMA_unified_gm2"]    = u["LMA_cascade_gm2"].where(u["LMA_cascade_gm2"].notna(), u["LMA_baseline_gm2"])
    u["LMA_source_unified"] = np.where(u["LMA_cascade_gm2"].notna(), "cascade_jul",
                                np.where(u["LMA_baseline_gm2"].notna(),
                                  np.where(u["LMA_source_baseline"] == "measured", "baseline_aug", "baseline_cell_mean"),
                                  "missing"))

    # Leaf chlorophyll content (ug cm-2) from SPAD, and LMA in g cm-2
    u["LCC_ugcm2"] = 1.26 * u["SPAD_unified"] + 6.63
    u["LMA_gcm2"]  = u["LMA_unified_gm2"] / 1e4

    print(f"  plots: {len(u)}")
    n_cas = (u["SPAD_source_unified"] == "cascade_jul").sum()
    n_bas = u["SPAD_source_unified"].isin(["baseline_aug","baseline_cell_mean"]).sum()
    print(f"  SPAD from July:   {n_cas}")
    print(f"  SPAD from August: {n_bas}")

    u.to_csv(OUT_CSV, index=False)
    print(f"\n  wrote: outputs/leaf_inputs/{OUT_CSV.name}")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"[05_combine_spad_lma] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
