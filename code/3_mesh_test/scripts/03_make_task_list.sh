#!/bin/bash
# Write the task list of the mesh-test job array
#
# Purpose
#   Lists the 56 mesh-test runs in the form read by 04_submit_array.sh, one run per line:
#     <SITE> <SPACING> <LEAF_TYPE> <DAP> <NX> <NY>
#   Each of the eight class-mean canopies is run on its peak-LAI date with NX = NY = 1, 2, 3,
#   5, 8, 12 and 15, that is 1, 4, 9, 25, 64, 144 and 225 sub-leaf elements per leaflet. The
#   peak-LAI dates are those of data/simulation_inputs/mesh_test_inputs.csv
#   (01_make_mesh_test_inputs.py). The list equals data/simulation_inputs/mesh_test_task_list.txt.
#
# Inputs
#   none (the classes, dates and grids are set below)
#
# Outputs
#   $TASK_LIST   the task list (default scripts/task_list.txt in the project folder)
#
# Usage
#   bash scripts/03_make_task_list.sh                  (from the project folder on the cluster)
#   From the package root:
#   TASK_LIST=outputs/mesh_test/task_list.txt bash code/3_mesh_test/scripts/03_make_task_list.sh
#
# Requirements
#   bash

set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Settings. The output location can be overridden from the environment.
TASK_LIST="${TASK_LIST:-$SCRIPT_DIR/task_list.txt}"

# Class-mean canopies, one per line: site, row spacing code (15 = 38-cm rows, 30 = 76-cm
# rows), leaflet type and peak-LAI DAP.
CELLS=(
    "EF 15 Broad 61"
    "EF 15 Narrow 61"
    "EF 30 Broad 68"
    "EF 30 Narrow 75"
    "SF 15 Broad 76"
    "SF 15 Narrow 76"
    "SF 30 Broad 76"
    "SF 30 Narrow 76"
)

# Sub-leaf grids: NX values, with NY = NX, so the number of elements per leaflet is NX^2.
NX_LEVELS=(1 2 3 5 8 12 15)

: > "$TASK_LIST"
for CELL in "${CELLS[@]}"; do
    for NX in "${NX_LEVELS[@]}"; do
        echo "$CELL $NX $NX" >> "$TASK_LIST"
    done
done

N=$(wc -l < "$TASK_LIST")
echo "wrote: $TASK_LIST  ($N tasks total)"
echo "first 3 lines:"
head -3 "$TASK_LIST"
echo "last 3 lines:"
tail -3 "$TASK_LIST"
