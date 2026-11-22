#!/bin/bash
# Write the task list of the Helios job array, one line per plot and date
#
# Purpose
#   Lists every plot-date of the two per-plot input files in the form read by
#   03_submit_array.sh, one task per line:
#     <SITE> <LOC_ID> <SPACING> <LEAF_TYPE> <DAP>
#   Energy Farm tasks come first and SoyFACE tasks second, each sorted by DAP, then Pass and
#   Range (the field position of the plot). The list has 5,299 lines (2,240 Energy Farm and
#   3,059 SoyFACE) and equals data/simulation_inputs/task_list.txt.
#
# Inputs
#   $INPUT_DIR/canopy_inputs_per_plot_per_DAP_EF.csv   per-plot inputs, Energy Farm
#   $INPUT_DIR/canopy_inputs_per_plot_per_DAP_SF.csv   per-plot inputs, SoyFACE
#   (INPUT_DIR defaults to inputs/ in the project folder)
#
# Outputs
#   $TASK_LIST   the task list (default scripts/task_list.txt in the project folder)
#
# Usage
#   bash scripts/02_make_task_list.sh                  (from the project folder on the cluster)
#   From the package root, with the package copy of the inputs:
#   INPUT_DIR=data/simulation_inputs TASK_LIST=outputs/helios/task_list.txt \
#       bash code/2_helios_simulation/scripts/02_make_task_list.sh
#
# Requirements
#   bash, awk, sort, cut

set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# Settings. Each one can be overridden from the environment.
INPUT_DIR="${INPUT_DIR:-$PROJECT_DIR/inputs}"
TASK_LIST="${TASK_LIST:-$SCRIPT_DIR/task_list.txt}"

: > "$TASK_LIST"
for cfg in "EF:$INPUT_DIR/canopy_inputs_per_plot_per_DAP_EF.csv" \
           "SF:$INPUT_DIR/canopy_inputs_per_plot_per_DAP_SF.csv"; do
    SITE="${cfg%%:*}"
    CSV="${cfg#*:}"
    if [ ! -f "$CSV" ]; then
        echo "FATAL: missing input CSV: $CSV" >&2
        exit 1
    fi
    # Columns are found by header name, after removing the quotes and the carriage returns
    # of the input files. Pass and Range are printed only for sorting and then cut off.
    awk -F',' '
        { gsub(/"/, ""); sub(/\r$/, "") }
        NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
        { print $(col["Location"]), $(col["Loc_ID"]), $(col["Spacing"]), $(col["Leaf_type"]),
                $(col["DAP"]), $(col["Pass"]), $(col["Range"]) }
    ' "$CSV" | LC_ALL=C sort -t ' ' -k5,5n -k6,6n -k7,7n | cut -d ' ' -f 1-5 >> "$TASK_LIST"
    echo "  added $SITE rows from: $(basename "$CSV")"
done

N=$(wc -l < "$TASK_LIST")
echo "wrote: $TASK_LIST  ($N rows total)"
echo "first 3 lines:"
head -n 3 "$TASK_LIST"
echo "last 3 lines:"
tail -n 3 "$TASK_LIST"
