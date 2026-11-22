"""Build the class-mean canopies of the sub-leaf mesh test

Purpose
    For each of the eight location x row spacing x leaflet type classes, finds the date with
    the highest class-mean LAI and averages the per-plot inputs of that date into one
    class-mean row. Numeric columns are averaged over the plots, and text columns take the
    first value present. Each row is labeled <SITE>_<SPACING>_<LEAF_TYPE>_DAP<NNN>, the
    identifier that the mesh-test driver (mesh_test_main.cpp) builds from its arguments. The
    eight rows are the inputs of the mesh test (Fig S8B-C, Table S12), and the output equals
    data/simulation_inputs/mesh_test_inputs.csv.

Inputs
    data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   per-plot inputs, Energy Farm
    data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   per-plot inputs, SoyFACE

Outputs
    outputs/mesh_test/mesh_test_inputs.csv   eight class-mean rows with the columns of the
        per-plot inputs and n_plots_aggregated (number of plots averaged)

Usage
    python code/3_mesh_test/scripts/01_make_mesh_test_inputs.py   (from the package root)

Requirements
    Python 3 (3.12 used); pandas, numpy
"""
import os
import sys
import pandas as pd
import numpy as np
from pathlib import Path

ROOT = Path(os.environ.get("PACKAGE_ROOT", "."))
INPUTS = ROOT / "data" / "simulation_inputs"
OUT_DIR = ROOT / "outputs" / "mesh_test"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_CSV = OUT_DIR / "mesh_test_inputs.csv"

print(f"Reading the per-plot inputs ...")
pp_list = []
for site in ("EF", "SF"):
    fp = INPUTS / f"canopy_inputs_per_plot_per_DAP_{site}.csv"
    d = pd.read_csv(fp)
    print(f"  [{site}] {len(d)} rows, {d['Loc_ID'].nunique()} unique plots")
    pp_list.append(d)
pp = pd.concat(pp_list, ignore_index=True)
print(f"  Combined: {len(pp)} rows, columns: {len(pp.columns)}")

# The site is the column Location of the per-plot inputs.
assert "Location" in pp.columns, "Location column missing"
assert "Spacing" in pp.columns
assert "Leaf_type" in pp.columns
assert "DAP" in pp.columns
assert "LAI_m2_m2_interp" in pp.columns

# ----------------------------------------------------------------------------
# 1. Date of the highest class-mean LAI for each Location x Spacing x Leaf_type
# ----------------------------------------------------------------------------
cell_dap_lai = (pp.groupby(["Location", "Spacing", "Leaf_type", "DAP"], as_index=False)
                  .agg(LAI_cellmean=("LAI_m2_m2_interp", "mean"),
                       n_plots=("Loc_ID", "nunique")))

peak_dap = (cell_dap_lai.sort_values(["Location", "Spacing", "Leaf_type", "LAI_cellmean"],
                                       ascending=[True, True, True, False])
                          .groupby(["Location", "Spacing", "Leaf_type"], as_index=False)
                          .first()
                          .rename(columns={"DAP": "peak_DAP"}))
print("\n=== Peak-LAI DAP per cell ===")
print(peak_dap[["Location", "Spacing", "Leaf_type", "peak_DAP",
                "LAI_cellmean", "n_plots"]].to_string(index=False))

# ----------------------------------------------------------------------------
# 2. Class means of the per-plot rows on each class's peak-LAI date
# ----------------------------------------------------------------------------
# Numeric columns are averaged. Text and logical columns take the first value present.
numeric_cols = pp.select_dtypes(include=[np.number]).columns.tolist()
categorical_cols = [c for c in pp.columns if c not in numeric_cols]
print(f"\n{len(numeric_cols)} numeric cols, {len(categorical_cols)} categorical cols")

rows = []
for _, peak_row in peak_dap.iterrows():
    site = peak_row["Location"]
    spacing = peak_row["Spacing"]
    leaf = peak_row["Leaf_type"]
    dap = int(peak_row["peak_DAP"])

    cell = pp[(pp["Location"] == site) &
              (pp["Spacing"] == spacing) &
              (pp["Leaf_type"] == leaf) &
              (pp["DAP"] == dap)].copy()
    n = len(cell)
    if n == 0:
        print(f"  WARNING: no rows for {site}/{spacing}/{leaf}/DAP={dap}")
        continue

    agg = {}
    for c in cell.columns:
        if c in numeric_cols:
            agg[c] = cell[c].mean()
        else:
            uniq = cell[c].dropna().unique()
            agg[c] = uniq[0] if len(uniq) > 0 else None

    # Identifier columns of the class-mean canopy. The identifier is the one the mesh-test
    # driver builds from its arguments, for example EF_15_Broad_DAP061.
    agg["Loc_ID"]   = f"{site}_{spacing}_{leaf}_DAP{dap:03d}"
    agg["Plot_UID"] = agg["Loc_ID"]
    agg["DAP"]      = dap
    agg["Location"] = site
    agg["Spacing"]  = spacing
    agg["Leaf_type"] = leaf
    # Number of plots averaged, added as the last column.
    agg["n_plots_aggregated"] = n
    rows.append(agg)
    print(f"  {site}/{spacing}/{leaf}/DAP{dap}: aggregated {n} plots -> Loc_ID={agg['Loc_ID']}")

out_df = pd.DataFrame(rows, columns=list(pp.columns) + ["n_plots_aggregated"])
out_df.to_csv(OUT_CSV, index=False)

print(f"\nWrote {OUT_CSV}")
print(f"  rows: {len(out_df)}, columns: {len(out_df.columns)}")
print(f"  Loc_IDs: {out_df['Loc_ID'].tolist()}")

# Class-mean LAI, biochemistry and PAR optics of the eight canopies.
print("\n=== Cell-mean biochem at peak-LAI DAP ===")
print(out_df[["Loc_ID", "LAI_m2_m2_interp", "vcmax", "jmax", "rd25", "tp25",
              "R_PAR_leaf", "T_PAR_leaf"]].to_string(index=False))
