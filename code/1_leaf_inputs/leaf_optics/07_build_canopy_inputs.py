"""Add the per-plot leaf optics to the canopy inputs and the plot table of leaf optics

Purpose
    Replaces the leaf-optical, SPAD and LMA columns of the base canopy inputs (one row per plot
    and date, SoyFACE and Energy Farm) with the per-plot PROSPECT-D band values
    (06_prospect_forward_per_plot.py) and the per-plot SPAD, LCC and LMA with their sources
    (05_combine_spad_lma.py). A plot is flagged leaf_optical_source = measured when its SPAD or
    LMA was measured in either campaign, and cell_mean otherwise. The per-plot Vcmax25, Jmax25,
    Tp25 and Rd25, LAI, plant height and weather columns come from data/canopy_inputs_base/ and
    pass through unchanged. The same leaf-optics columns replace those of the base plot table.
    The plot table gives Table S10 and the data of Fig. S3. The canopy inputs give Tables S4 and
    S14 (per-plot fits and their means), Fig. S1 and the plot attributes read by the LiDAR scripts.
    They are also the input of the Rd25 step (aci_respiration/05_rd25_combination_means.R and
    06_apply_rd25_to_canopy_inputs.R), which writes the simulation inputs.

Inputs
    outputs/leaf_inputs/spad_lma_per_plot.csv          per-plot SPAD, LCC and LMA (05)
    outputs/leaf_inputs/leaf_optics_bands_per_plot.csv per-plot band optics (06)
    data/canopy_inputs_base/leaf_optical_base.csv      plot table with the August leaf optics
    data/canopy_inputs_base/canopy_inputs_base_SF.csv  base canopy inputs, SoyFACE
    data/canopy_inputs_base/canopy_inputs_base_EF.csv  base canopy inputs, Energy Farm

Outputs
    outputs/leaf_inputs/leaf_optical_per_plot.csv          plot table with the per-plot leaf optics
    outputs/leaf_inputs/canopy_inputs_leaf_optics_SF.csv   canopy inputs with leaf optics, SoyFACE
    outputs/leaf_inputs/canopy_inputs_leaf_optics_EF.csv   canopy inputs with leaf optics, Energy Farm

Usage
    python code/1_leaf_inputs/leaf_optics/07_build_canopy_inputs.py   (run from the package root)

Requirements
    Python 3.12; pandas (3.0.3 used), numpy
"""

import os
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

ROOT        = Path(os.environ.get("PACKAGE_ROOT", "."))
BASELINE    = ROOT / "data" / "canopy_inputs_base"
OUT_DIR     = ROOT / "outputs" / "leaf_inputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

UNIFIED_FP  = OUT_DIR / "spad_lma_per_plot.csv"
BANDS_FP    = OUT_DIR / "leaf_optics_bands_per_plot.csv"   # 06_prospect_forward_per_plot.py


def main():
    t0 = datetime.now()
    print("[07_build_canopy_inputs]")

    unified = pd.read_csv(UNIFIED_FP)
    bands   = pd.read_csv(BANDS_FP)
    print(f"  per-plot SPAD/LMA: {len(unified)} rows | bands: {len(bands)} rows")

    # Optics anchored to a measured SPAD or LMA value, or combination-mean optics
    leaf_optical_source = np.where(
        unified["SPAD_source_unified"].isin(["cascade_jul","baseline_aug","measured"]) |
        unified["LMA_source_unified"].isin(["cascade_jul","baseline_aug","measured"]),
        "measured", "cell_mean"
    )
    unified = unified.assign(leaf_optical_source=leaf_optical_source)

    # ---- Plot table with the base columns and the new leaf-optics columns ----
    master_baseline = pd.read_csv(BASELINE / "leaf_optical_base.csv")
    drop = ["R_PAR_leaf","T_PAR_leaf","R_NIR_leaf","T_NIR_leaf",
            "A_PAR_leaf","A_NIR_leaf","leaf_optical_source",
            "LCC_ugcm2","SPAD_source","LMA_used_gm2","LMA_source"]
    master = master_baseline.drop(columns=[c for c in drop if c in master_baseline.columns], errors="ignore")
    bands_renamed = bands.rename(columns={
        "R_PAR":"R_PAR_leaf","T_PAR":"T_PAR_leaf","A_PAR":"A_PAR_leaf",
        "R_NIR":"R_NIR_leaf","T_NIR":"T_NIR_leaf","A_NIR":"A_NIR_leaf",
    })
    master = (master.merge(bands_renamed, on="Loc_ID", how="left")
                    .merge(unified[["Loc_ID","LCC_ugcm2","SPAD_source_unified",
                                    "LMA_unified_gm2","LMA_source_unified","leaf_optical_source"]].rename(
                              columns={"SPAD_source_unified":"SPAD_source",
                                       "LMA_unified_gm2":"LMA_used_gm2",
                                       "LMA_source_unified":"LMA_source"}),
                            on="Loc_ID", how="left"))
    fp = OUT_DIR / "leaf_optical_per_plot.csv"
    master.to_csv(fp, index=False)
    print(f"  wrote: outputs/leaf_inputs/{fp.name}")

    # ---- Canopy inputs for SoyFACE and the Energy Farm ----
    for site in ["SF","EF"]:
        src_fp = BASELINE / f"canopy_inputs_base_{site}.csv"
        ci = pd.read_csv(src_fp, low_memory=False)
        drop_cols = ["R_PAR_leaf","T_PAR_leaf","R_NIR_leaf","T_NIR_leaf",
                     "A_PAR_leaf","A_NIR_leaf","leaf_optical_source",
                     "LCC_ugcm2","SPAD_source","LMA_used_gm2","LMA_source",
                     "spad","lma"]
        ci = ci.drop(columns=[c for c in drop_cols if c in ci.columns], errors="ignore")
        ci = ci.merge(bands_renamed[["Loc_ID","R_PAR_leaf","T_PAR_leaf","A_PAR_leaf",
                                      "R_NIR_leaf","T_NIR_leaf","A_NIR_leaf"]],
                      on="Loc_ID", how="left")
        ci = ci.merge(unified[["Loc_ID","SPAD_unified","SPAD_source_unified",
                                "LCC_ugcm2","LMA_unified_gm2","LMA_source_unified",
                                "leaf_optical_source"]].rename(columns={
            "SPAD_unified":"spad","SPAD_source_unified":"SPAD_source",
            "LMA_unified_gm2":"lma_gm2","LMA_source_unified":"LMA_source",
        }), on="Loc_ID", how="left")
        # lma is LMA in g cm-2 (lma_gm2 in g m-2)
        ci["lma"] = ci["lma_gm2"] / 1e4
        fp = OUT_DIR / f"canopy_inputs_leaf_optics_{site}.csv"
        ci.to_csv(fp, index=False)
        print(f"  wrote: outputs/leaf_inputs/{fp.name}  ({len(ci)} rows)")

    elapsed = (datetime.now() - t0).total_seconds()
    print(f"[07_build_canopy_inputs] done in {elapsed:.1f} s")


if __name__ == "__main__":
    main()
