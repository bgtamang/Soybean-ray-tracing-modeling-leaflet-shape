#!/bin/bash
# Build the Helios canopy driver on the cluster
#
# Purpose
#   Sets up the build environment (CMake and CUDA modules, the Vulkan SDK and the C runtime
#   library path), configures the project with CMake and compiles helios_main.cpp into
#   build/helios_canopy. Run it on a GPU compute node. On the cluster used for the paper the
#   login nodes lacked part of the C runtime (libc_nonshared.a in /usr/lib64).
#
# Inputs
#   CMakeLists.txt and helios_main.cpp in the project folder (the folder above scripts/)
#   the Helios source tree at $HELIOS_DIR (docs/helios_build.md)
#
# Outputs
#   build/helios_canopy in the project folder (build/ is emptied first)
#
# Usage
#   bash scripts/01_build.sh                      (from the project folder, on a compute node)
#   HELIOS_DIR=/path/to/Helios bash scripts/01_build.sh
#
# Requirements
#   environment modules for CMake 3.15 or later and CUDA, a C++ compiler, the Vulkan SDK.
#   The module names and paths below are those of the cluster used for the paper and are
#   examples to adapt (docs/cluster_run.md).

set -e  # stop at the first error

# Settings. Each one can be overridden from the environment.
HELIOS_DIR="${HELIOS_DIR:-$HOME/Helios}"                            # Helios source tree
VULKAN_SDK="${VULKAN_SDK:-$HOME/local}"                             # Vulkan SDK installation
CRT_FALLBACK_DIR="${CRT_FALLBACK_DIR:-/home/apps/software/MAESTRO}" # searched for crt1.o if /usr/lib64 lacks it
EXECUTABLE="helios_canopy"                                          # EXECUTABLE_NAME in CMakeLists.txt

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_DIR"
echo "Building the Helios canopy driver in: $PROJECT_DIR"

# Modules
module load CMake/3.29.5-IGB-gcc-8.2.0
module load CUDA/12.8.0

# Vulkan SDK
export VULKAN_SDK
export LD_LIBRARY_PATH=$VULKAN_SDK/lib64:$VULKAN_SDK/lib:$LD_LIBRARY_PATH
export PATH=$VULKAN_SDK/bin:$PATH
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json

# C runtime start files (crt1.o, crti.o, crtn.o). /usr/lib64 is used when it holds both
# crt1.o and libc_nonshared.a of the system glibc, as on the compute nodes. Otherwise crt1.o
# is searched for under CRT_FALLBACK_DIR. That copy may come from an older glibc and then
# fails to link against a newer one (undefined __libc_csu_init).
if [ -f /usr/lib64/crt1.o ] && [ -f /usr/lib64/libc_nonshared.a ]; then
    CRT_DIR=/usr/lib64
    echo "Using system C runtime path: $CRT_DIR"
else
    CRT_DIR=$(find "$CRT_FALLBACK_DIR" -name "crt1.o" 2>/dev/null | head -1 | xargs -r dirname || true)
    if [ -z "$CRT_DIR" ]; then
        echo "FATAL: crt1.o not found in /usr/lib64 nor under $CRT_FALLBACK_DIR"
        exit 1
    fi
    echo "WARNING: /usr/lib64 incomplete (missing crt1.o or libc_nonshared.a)"
    echo "         Falling back to: $CRT_DIR"
    echo "         (This may fail with __libc_csu_init errors on newer-glibc systems.)"
fi

if [ ! -f "$CRT_DIR/crt1.o" ]; then
    echo "FATAL: $CRT_DIR/crt1.o does not exist. Searching the file system..."
    find / -name "crt1.o" 2>/dev/null | head -5
    exit 1
fi
echo "Verified C runtime files:"
ls -l "$CRT_DIR/crt1.o" "$CRT_DIR/crti.o" "$CRT_DIR/crtn.o" 2>/dev/null | head -3

export LIBRARY_PATH="${CRT_DIR}:/usr/lib64:${LIBRARY_PATH}"
export LD_LIBRARY_PATH="$CRT_DIR:$LD_LIBRARY_PATH"

# Empty the build folder, configure and compile
mkdir -p build
rm -rf build/*
cd build

echo "=================================================================="
echo "CMAKE CONFIGURE"
echo "=================================================================="
cmake -DBASE_DIRECTORY="$HELIOS_DIR" ..

echo
echo "=================================================================="
echo "MAKE"
echo "=================================================================="
make -j8

echo
echo "=================================================================="
echo "RESULT"
echo "=================================================================="
if [ -f "$EXECUTABLE" ]; then
    ls -lh "$EXECUTABLE"
    echo "SUCCESS - binary built"
else
    echo "FAILED - no binary produced; see make output above for errors"
    exit 1
fi
