"""Join the per-task Helios canopy summaries into one summary file per site

Purpose
    Concatenates the one-row summary files that the Helios canopy driver (helios_main.cpp)
    writes for each plot and date into one file per site, in file-name order, with the header
    written once. The results hold canopy A, fAPAR and canopy LUE of the 3,059 SoyFACE and
    2,240 Energy Farm plot-dates, used throughout the paper (Figs 2-5, 7 and S5-S8, Tables
    S15 and S19) and read by the one-dimensional model and the genetics scripts. The number
    of rows written is checked against the task list.

Inputs
    outputs/helios/SF/per_task/canopy_summary_*.csv   per-task summaries, SoyFACE
    outputs/helios/EF/per_task/canopy_summary_*.csv   per-task summaries, Energy Farm
        (build/outputs/<SITE>/per_task/ of the cluster run, docs/cluster_run.md)

Outputs
    outputs/helios/helios_canopy_summary_SF.csv   one row per plot-date, SoyFACE
    outputs/helios/helios_canopy_summary_EF.csv   one row per plot-date, Energy Farm

Usage
    python code/2_helios_simulation/scripts/04_combine_task_outputs.py   (from the package root)
    An optional argument gives another folder with the same layout (<folder>/<SITE>/per_task/),
    for example build/outputs in the cluster project folder.

Requirements
    Python 3 (3.12 used), standard library only
"""
import glob
import os
import sys
from pathlib import Path

ROOT = Path(os.environ.get("PACKAGE_ROOT", "."))
HELIOS_DIR = ROOT / "outputs" / "helios"

# Plot-dates of each site in the task list.
EXPECTED_ROWS = {"EF": 2240, "SF": 3059}


def concat_site(helios_dir, site):
    per_task_dir = os.path.join(helios_dir, site, "per_task")
    out_path = os.path.join(helios_dir, f"helios_canopy_summary_{site}.csv")

    csvs = sorted(glob.glob(os.path.join(per_task_dir, "canopy_summary_*.csv")))
    print(f"[{site}] found {len(csvs)} per_task CSVs in {per_task_dir}")
    if not csvs:
        print(f"[{site}] no files found, skipping this site")
        return

    # The header comes from the first file. Every later file must have the same header, and
    # its data rows (all lines after the header that are not blank) are appended.
    header = None
    n_rows = 0
    with open(out_path, "w", encoding="utf-8") as out:
        for fp in csvs:
            with open(fp, "r", encoding="utf-8") as f:
                lines = f.readlines()
            if not lines:
                continue
            if header is None:
                header = lines[0]
                out.write(header)
            else:
                if lines[0] != header:
                    print(f"  WARNING: header mismatch in {os.path.basename(fp)}")
            for ln in lines[1:]:
                if ln.strip():
                    out.write(ln)
                    n_rows += 1

    exp = EXPECTED_ROWS.get(site, "?")
    flag = "OK" if n_rows == exp else f"FLAG (expected {exp})"
    print(f"[{site}] wrote {n_rows} data rows -> {os.path.basename(out_path)}  [{flag}]")


def main():
    helios_dir = sys.argv[1] if len(sys.argv) > 1 else HELIOS_DIR
    print(f"Helios outputs folder: {helios_dir}\n")
    for site in ("EF", "SF"):
        concat_site(helios_dir, site)
    print("\nDone.")


if __name__ == "__main__":
    main()
