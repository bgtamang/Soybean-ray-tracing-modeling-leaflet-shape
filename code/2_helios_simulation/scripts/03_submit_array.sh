#!/bin/bash
# SLURM job array that runs the Helios canopy driver for every line of the task list
#
# Purpose
#   Runs build/helios_canopy once for each plot-date of the task list (5,299 runs). The
#   cluster used for the paper allowed at most 1,001 tasks per array, so each array task runs
#   six consecutive lines of the task list. The 884 array tasks cover the 5,299 lines, and the
#   last array task has one line. At most six array tasks run at the same time (%6), each on
#   one NVIDIA A40 GPU. A failed run is reported in the log and the rest of the chunk goes on.
#
# Inputs
#   $TASK_LIST   task list from 02_make_task_list.sh (default scripts/task_list.txt)
#   build/helios_canopy and inputs/*.csv in the project folder (docs/cluster_run.md)
#
# Outputs
#   build/outputs/<SITE>/per_task/ and build/outputs/<SITE>/per_leaf/   written by the driver
#   logs/helios_canopy_<job>_<array task>.out and .err                  SLURM logs
#
# Usage
#   mkdir -p logs && sbatch scripts/03_submit_array.sh      (from the project folder)
#
# Requirements
#   SLURM, and the modules and Vulkan SDK of the build (01_build.sh). The #SBATCH settings
#   below (partition, GPU type, CPUs, memory, time limit, array size and throttle) are
#   examples to adapt.

#SBATCH --job-name=helios_canopy
#SBATCH --partition=gpu
#SBATCH --gres=gpu:A40:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --array=1-884%6
#SBATCH --output=logs/helios_canopy_%A_%a.out
#SBATCH --error=logs/helios_canopy_%A_%a.err

set -e

# Settings. Each one can be overridden from the environment. The project folder defaults to
# the folder the job was submitted from.
PROJECT_DIR="${PROJECT_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
TASK_LIST="${TASK_LIST:-$PROJECT_DIR/scripts/task_list.txt}"
VULKAN_SDK="${VULKAN_SDK:-$HOME/local}"
EXECUTABLE="helios_canopy"
CHUNK_SIZE=6                         # task-list lines per array task

# Modules (as for the build)
module load CMake/3.29.5-IGB-gcc-8.2.0
module load CUDA/12.8.0

# Vulkan SDK
export VULKAN_SDK
export LD_LIBRARY_PATH=$VULKAN_SDK/lib64:$VULKAN_SDK/lib:$LD_LIBRARY_PATH
export PATH=$VULKAN_SDK/bin:$PATH
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json

if [ ! -f "$TASK_LIST" ]; then
    echo "ERROR: $TASK_LIST not found. Run scripts/02_make_task_list.sh first." >&2
    exit 1
fi

# This array task runs lines START_IDX to END_IDX of the task list.
START_IDX=$(( (SLURM_ARRAY_TASK_ID - 1) * CHUNK_SIZE + 1 ))
END_IDX=$(( SLURM_ARRAY_TASK_ID * CHUNK_SIZE ))

echo "=== Array task $SLURM_ARRAY_TASK_ID: task-list lines $START_IDX..$END_IDX ==="
echo "Host: $(hostname)"
echo "Start: $(date)"

# The driver reads ../inputs/ and writes outputs/ relative to its working directory, so it
# runs from build/.
cd "$PROJECT_DIR/build"

for i in $(seq $START_IDX $END_IDX); do
    TASK_LINE=$(sed -n "${i}p" "$TASK_LIST")
    if [ -z "$TASK_LINE" ]; then
        echo "(no task on line $i, past the end of the task list, stopping chunk)"
        break
    fi
    read SITE LOC_ID SPACING LEAF DAP <<< "$TASK_LINE"
    echo
    echo "--- sub-task $i: site=$SITE loc_id=$LOC_ID spacing=$SPACING leaf=$LEAF DAP=$DAP ---"
    SUB_START=$(date +%s)
    # Five arguments. USE_CELL_MEAN_VCMAX keeps its default of 0 (per-plot Vcmax25 and
    # Jmax25, with the class mean for a missing Jmax25).
    if ! ./"$EXECUTABLE" "$SITE" "$LOC_ID" "$SPACING" "$LEAF" "$DAP"; then
        echo "FAILED: line $i ($SITE $LOC_ID $SPACING $LEAF $DAP), continuing chunk"
    fi
    SUB_END=$(date +%s)
    echo "sub-task $i wall time: $((SUB_END - SUB_START)) s"
done

echo
echo "End: $(date)"
