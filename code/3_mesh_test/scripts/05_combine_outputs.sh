#!/bin/bash
# Join the 56 mesh-test summaries into one file
#
# Purpose
#   Concatenates the one-row summary files of the mesh-test runs (mesh_test_main.cpp),
#   Energy Farm first and SoyFACE second, each in file-name order, with the header written
#   once. The result holds canopy A, fAPAR and canopy LUE of the eight class-mean canopies at
#   the seven sub-leaf grids, the values of Table S12 and Fig S8B-C. A warning is printed
#   when the number of rows differs from 56.
#
# Inputs
#   $MESH_TEST_DIR/EF/per_task/*.csv and $MESH_TEST_DIR/SF/per_task/*.csv   per-task summaries
#   (MESH_TEST_DIR defaults to outputs/mesh_test under the package root. The files come from
#   build/outputs/<SITE>/per_task/ of the cluster run, docs/cluster_run.md.)
#
# Outputs
#   $OUT_CSV   combined summary, 56 rows (default $MESH_TEST_DIR/mesh_test_summary.csv)
#
# Usage
#   bash code/3_mesh_test/scripts/05_combine_outputs.sh              (from the package root)
#   MESH_TEST_DIR=build/outputs bash scripts/05_combine_outputs.sh   (in the cluster project folder)
#
# Requirements
#   bash, coreutils

set -e

# Settings. Each one can be overridden from the environment.
ROOT="${PACKAGE_ROOT:-.}"
OUTDIR="${MESH_TEST_DIR:-$ROOT/outputs/mesh_test}"
OUT_CSV="${OUT_CSV:-$OUTDIR/mesh_test_summary.csv}"
export LC_ALL=C   # file-name order that does not depend on the locale

if [ ! -d "$OUTDIR/EF/per_task" ] && [ ! -d "$OUTDIR/SF/per_task" ]; then
    echo "ERROR: no per_task outputs found under $OUTDIR/{EF,SF}/per_task/" >&2
    exit 1
fi

# Header from the first file found
FIRST=$(ls "$OUTDIR"/EF/per_task/*.csv 2>/dev/null | head -1)
[ -z "$FIRST" ] && FIRST=$(ls "$OUTDIR"/SF/per_task/*.csv 2>/dev/null | head -1)
if [ -z "$FIRST" ]; then
    echo "ERROR: no per_task CSVs found in either site folder." >&2
    exit 1
fi
head -1 "$FIRST" > "$OUT_CSV"

# Data rows of every per-task file of both sites
N_FILES=0
for SITE in EF SF; do
    DIR="$OUTDIR/$SITE/per_task"
    [ ! -d "$DIR" ] && continue
    for f in "$DIR"/*.csv; do
        [ ! -f "$f" ] && continue
        tail -n +2 "$f" >> "$OUT_CSV"
        N_FILES=$((N_FILES + 1))
    done
done

N_ROWS=$(($(wc -l < "$OUT_CSV") - 1))
echo "Combined $N_FILES per-task CSVs into:"
echo "  $OUT_CSV"
echo "  $N_ROWS data rows (expected 56)"

if [ "$N_ROWS" -ne 56 ]; then
    echo ""
    echo "WARNING: row count != 56. Check for failed array tasks:"
    echo "  squeue -u \$USER --format='%i %t %r' | grep helios_mesh_test"
    echo "  sacct -j <JOBID> --format=JobID,State,ExitCode -P | grep -v COMPLETED"
fi
