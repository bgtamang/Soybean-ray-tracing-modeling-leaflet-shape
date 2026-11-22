# CMake configuration of the Helios mesh-test driver (mesh_test_main.cpp)
#
# Purpose
#   Builds the executable helios_mesh_test from mesh_test_main.cpp against Helios 1.3.71
#   (commit c710cdfb) with the same seven plugins as the main driver. It differs from
#   code/2_helios_simulation/CMakeLists.txt only in the executable and source names.
#
# Inputs
#   mesh_test_main.cpp                  the driver source
#   <Helios>/core/CMake_project.cmake   Helios project setup
#
# Outputs
#   build/helios_mesh_test              the executable
#
# Usage
#   bash scripts/02_build.sh            (or, from build/: cmake .. && make)
#   The Helios location defaults to $HOME/Helios. Give another location with
#   cmake -DBASE_DIRECTORY=<path to Helios> ..
#
# Requirements
#   CMake 3.15 or later, a C++ compiler, CUDA and the Helios source tree (docs/helios_build.md)

cmake_minimum_required(VERSION 3.15)
project(helios)

#-------- USER INPUTS ---------#

if( NOT DEFINED BASE_DIRECTORY )
    set( BASE_DIRECTORY "$ENV{HOME}/Helios" )
endif()
set( EXECUTABLE_NAME "helios_mesh_test" )
set( SOURCE_FILES "mesh_test_main.cpp" )
set( PLUGINS "radiation;energybalance;stomatalconductance;boundarylayerconductance;solarposition;canopygenerator;photosynthesis" )

#-------- DO NOT MODIFY ---------#
include( "${BASE_DIRECTORY}/core/CMake_project.cmake" )
