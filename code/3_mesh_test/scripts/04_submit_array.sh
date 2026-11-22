#!/bin/bash
# SLURM job array that runs the Helios mesh-test driver for every line of the task list
#
# Purpose
#   Runs build/helios_mesh_test once for each of the 56 lines of the task list (eight
#   class-mean canopies, each at seven sub-leaf grids). Each array task runs one line. At most
#   six array tasks run at the same time (%6), each on one NVIDIA A40 GPU. Runs with 144 and
#   225 elements per leaflet can take longer than one hour at peak LAI. Raise --time (for
#   example to 03:00:00) if they time out.
#
# Inputs
#   $TASK_LIST   task list from 03_make_task_list.sh (default scripts/task_list.txt)
#   build/helios_mesh_test and inputs/mesh_test_inputs.csv in the project folder
#   (docs/cluster_run.md)
#
# Outputs
#   build/outputs/<SITE>/per_task/ and build/outputs/<SITE>/per_leaf/   written by the driver
#   logs/helios_mesh_test_<job>_<array task>.out and .err              SLURM logs
#
# Usage
#   mkdir -p logs && sbatch scripts/04_submit_array.sh      (from the project folder)
#
# Requirements
#   SLURM, and the modules and Vulkan SDK of the build (02_build.sh). The #SBATCH settings
#   below (partition, GPU type, CPUs, memory, time limit, array size and throttle) are
#   examples to adapt.

#SBATCH --job-name=helios_mesh_test
#SBATCH --partition=gpu
#SBATCH --gres=gpu:A40:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --array=1-56%6
#SBATCH --output=logs/helios_mesh_test_%A_%a.out
#SBATCH --error=logs/helios_mesh_test_%A_%a.err

set -e

# Settings. Each one can be overridden from the environment. The project folder defaults to
# the folder the job was submitted from.
PROJECT_DIR="${PROJECT_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
TASK_LIST="${TASK_LIST:-$PROJECT_DIR/scripts/task_list.txt}"
VULKAN_SDK="${VULKAN_SDK:-$HOME/local}"
EXECUTABLE="helios_mesh_test"

# Modules (as for the build)
module load CMake/3.29.5-IGB-gcc-8.2.0
module load CUDA/12.8.0

# Vulkan SDK
export VULKAN_SDK
export LD_LIBRARY_PATH=$VULKAN_SDK/lib64:$VULKAN_SDK/lib:$LD_LIBRARY_PATH
export PATH=$VULKAN_SDK/bin:$PATH
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json

if [ ! -f "$TASK_LIST" ]; then
    echo "ERROR: $TASK_LIST not found. Run scripts/03_make_task_list.sh first." >&2
    exit 1
fi

# Each array task runs one line of the task list.
TASK_LINE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$TASK_LIST")
if [ -z "$TASK_LINE" ]; then
    echo "ERROR: empty line for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID" >&2
    exit 1
fi
read SITE SPACING LEAF DAP NX NY <<< "$TASK_LINE"

echo "=== Array task $SLURM_ARRAY_TASK_ID / 56 ==="
echo "Cell: $SITE/$SPACING/$LEAF  DAP=$DAP  N_sub=${NX}x${NY}=$((NX*NY))"
echo "Host: $(hostname); GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo unknown)"
echo "Start: $(date)"

# The driver reads ../inputs/ and writes outputs/ relative to its working directory, so it
# runs from build/.
cd "$PROJECT_DIR/build"
SUB_START=$(date +%s)
./"$EXECUTABLE" "$SITE" "$SPACING" "$LEAF" "$DAP" "$NX" "$NY"
SUB_END=$(date +%s)
echo "Wall time: $((SUB_END - SUB_START)) s"
echo "End: $(date)"
