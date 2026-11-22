# CMake configuration of the Helios canopy driver (helios_main.cpp)
#
# Purpose
#   Builds the executable helios_canopy from helios_main.cpp against Helios 1.3.71
#   (commit c710cdfb) with the seven plugins the driver uses. This is the standard Helios
#   project file. The Helios CMake_project.cmake script does the rest of the configuration.
#
# Inputs
#   helios_main.cpp                     the driver source
#   <Helios>/core/CMake_project.cmake   Helios project setup
#
# Outputs
#   build/helios_canopy                 the executable
#
# Usage
#   bash scripts/01_build.sh            (or, from build/: cmake .. && make)
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
set( EXECUTABLE_NAME "helios_canopy" )
set( SOURCE_FILES "helios_main.cpp" )
set( PLUGINS "radiation;energybalance;stomatalconductance;boundarylayerconductance;solarposition;canopygenerator;photosynthesis" )

#-------- DO NOT MODIFY ---------#
include( "${BASE_DIRECTORY}/core/CMake_project.cmake" )
