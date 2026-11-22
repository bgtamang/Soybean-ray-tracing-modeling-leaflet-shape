# Building the Helios simulation drivers

The three-dimensional canopy simulations use Helios (Bailey, 2019), an open-source framework for
plant and canopy biophysics with GPU ray tracing. The package holds two Helios drivers, small C++
programs compiled against the Helios library:

| Driver | Folder | Runs | Paper items |
|---|---|---|---|
| `helios_main.cpp` | `code/2_helios_simulation/` | one plot on one measurement date, 5,299 runs | Helios results in Figs 2-5, 7 and S5-S8, Tables S7, S15 and S17-S20 |
| `mesh_test_main.cpp` | `code/3_mesh_test/` | one class-mean canopy at one sub-leaf grid, 56 runs | Fig S8B-C, Table S12 |

This page explains how to get Helios, which plugins the drivers use, how to build them, and how a
driver reads its inputs and writes its outputs. `docs/cluster_run.md` describes the folder layout
on the cluster, the task lists, the job arrays and the combination of the outputs.

## 1. Get Helios

The simulations were run with Helios release 1.3.71, commit
`c710cdfbb34662c813dc9983824443fb4f042ce4` (short form `c710cdfb`). Helios is distributed under
the GNU General Public License version 3.

```bash
git clone https://github.com/PlantSimulationLab/Helios.git "$HOME/Helios"
cd "$HOME/Helios"
git checkout c710cdfbb34662c813dc9983824443fb4f042ce4
```

The Helios tree used for the runs differed from this commit only in
`plugins/solarposition/src/PragueSkyModel.cpp`, which the drivers do not use.

The CMake files of the drivers look for Helios in `$HOME/Helios`. For another location, pass it
to CMake as `-DBASE_DIRECTORY=<path to Helios>`, or set `HELIOS_DIR` for the build scripts.

## 2. Plugins

Both drivers use the same seven Helios plugins (`PLUGINS` in each `CMakeLists.txt`).

| Plugin | Role in the drivers |
|---|---|
| `canopygenerator` | builds the horizontally homogeneous canopy of leaflets (planophile leaf angles, 3 x 3 m) and the ground surface |
| `solarposition` | sun position at 12:00 CDT (the drivers use the Energy Farm coordinates, 40.063476 N and 88.206586 W, for both sites), clear-sky PAR and NIR with their diffuse fraction (REST2), and incoming longwave |
| `radiation` | ray tracing of the PAR, NIR and longwave bands with periodic horizontal boundaries (GPU) |
| `boundarylayerconductance` | boundary-layer conductance, Pohlhausen equation for leaves and the ground model for the soil |
| `stomatalconductance` | stomatal conductance, Buckley-Mott-Farquhar model with the Helios default coefficients |
| `energybalance` | leaf and ground temperature from the surface energy balance (GPU) |
| `photosynthesis` | Farquhar-von Caemmerer-Berry photosynthesis of each sub-leaf element |

The radiation and energy-balance plugins run on an NVIDIA GPU through CUDA. In the runs for the
paper the radiation plugin used the NVIDIA OptiX ray-tracing back end on NVIDIA A40 GPUs.

## 3. Requirements

- Linux with an NVIDIA GPU and its driver
- CUDA toolkit (12.8.0 used)
- CMake 3.15 or later (3.29.5 used) and a C++ compiler with C++17 support
- The C runtime start files (`crt1.o`, `crti.o`, `crtn.o`) and `libc_nonshared.a` of the system
  glibc in `/usr/lib64`. On the cluster used for the runs these were complete on the GPU compute
  nodes but not on the login nodes, so the drivers were built on a compute node.
- The build and job scripts also put a user-level Vulkan SDK on the library path
  (`VULKAN_SDK`, default `$HOME/local`), as on the cluster used for the runs.

## 4. Build the drivers

Each driver folder has a standard Helios project file (`CMakeLists.txt`) that names the source
file, the executable and the plugins, and then includes `core/CMake_project.cmake` of the Helios
tree. The build scripts load the modules, set the library paths, empty `build/`, run CMake and
make, and check that the executable exists.

```bash
# main driver: build/helios_canopy
cd <project folder of the main runs>        # a copy of code/2_helios_simulation
bash scripts/01_build.sh

# mesh-test driver: build/helios_mesh_test
cd <project folder of the mesh test>        # a copy of code/3_mesh_test
bash scripts/02_build.sh
```

The settings at the top of the build scripts can be changed from the environment: `HELIOS_DIR`
(Helios tree), `VULKAN_SDK`, and `CRT_FALLBACK_DIR`, a directory searched for `crt1.o` when
`/usr/lib64` lacks it. The module names (`CMake/3.29.5-IGB-gcc-8.2.0`, `CUDA/12.8.0`) are those of
the cluster used for the runs. Replace them with the modules of your system.

Without the scripts, the build is the usual CMake sequence:

```bash
mkdir -p build && cd build
cmake -DBASE_DIRECTORY="$HOME/Helios" ..
make -j8
```

The compiler warns that the four-argument `SolarPosition::getDiffuseFraction()` call of the drivers
is to be replaced by `setAtmosphericConditions()` followed by `getDiffuseFraction()`. The call
compiles and runs in this release, and the drivers keep it so that they match the runs.

## 5. How a driver reads its inputs and writes its outputs

A driver runs one simulation per call. It must be started from `build/` in the project folder,
because it reads its inputs from `../inputs/` and writes its outputs to `outputs/` below the
working directory. The ground texture is read from `plugins/canopygenerator/textures/dirt.jpg`
below the working directory, where the Helios build places the plugin files.

### Main driver

```
./helios_canopy <SITE> <LOC_ID> <SPACING> <LEAF_TYPE> <DAP> [USE_CELL_MEAN_VCMAX]
./helios_canopy EF EF_1_5 30 Broad 49
```

`SITE` is `EF` (Energy Farm) or `SF` (SoyFACE), `LOC_ID` the plot identifier, `SPACING` the row
spacing code of the data (15 for 38-cm rows, 30 for 76-cm rows), `LEAF_TYPE` `Broad` or `Narrow`,
and `DAP` days after planting. The optional flag `USE_CELL_MEAN_VCMAX = 1` replaces both Vcmax25
and Jmax25 by class means. The runs for the paper left it at its default of 0.

Inputs (copies of `data/simulation_inputs/` in the package):

- `../inputs/canopy_inputs_per_plot_per_DAP_<SITE>.csv`, one row per plot and date. The driver
  keeps rows with `Line` = BC3, finds the row of the plot and date, and reads these columns by
  name: `Loc_ID`, `Spacing`, `Leaf_type`, `DAP`, `DOY`, `LAI_m2_m2_interp`, `height_m_interp`,
  `length_m`, `avwidth_m`, `vcmax`, `jmax`, `rd25`, `tp25`, `R_PAR_leaf`, `T_PAR_leaf`,
  `R_NIR_leaf`, `T_NIR_leaf`, `air_T_C`, `air_T_K`, `BP_Pa`, `RH_fraction` and `wind_m_s`.
- `../inputs/canopy_inputs_cell_mean_per_DAP_<SITE>.csv`, class-mean `Vcmax25`, `Jmax25`,
  `Vcmax_n` and `Jmax_n` by `Spacing` and `Leaf_type`. The driver stops when a plot has no
  Vcmax25 and uses the class mean when a plot has no Jmax25. In the inputs of the paper both
  values are present in every row, because plots without an A-Ci fit already carry the class
  fill values of Table S14 (columns `vcmax_source` and `jmax_source`). The class-mean file is
  therefore read but not used, and the output columns `Vcmax_n` and `Jmax_n` are 1 in every row.

Each call builds the canopy of the plot (leaflets of the plot's length and average width up to
its LAI and height, each leaflet divided into 3 x 3 sub-leaf elements), sets leaf optics and
biochemistry, solves radiation, stomata and energy balance in two passes, computes photosynthesis
of every element, and writes two files:

- `outputs/<SITE>/per_task/canopy_summary_<LOC_ID>_DAP<NNN>.csv`: one header line and one data
  row with the inputs used (`LAI_used`, `height_m_used`, `leaf_length_m_used`,
  `leaf_avwidth_m_used`, `Vcmax25_used`, `Jmax25_used`, `Vcmax_n`, `Jmax_n`, `air_T_C_used`,
  `RH_fraction_used`, `wind_m_s_used`, `BP_Pa_used`, `CO2_ppm_used`) and the results:
  `incident_PAR_W_m2` (clear-sky PAR of the run), `abs_PAR_W_m2` (canopy absorbed PAR per m2 of
  ground), `A_umol_m2_s` (canopy A), `frac_PAR_absorbed` (fAPAR),
  `inst_canopy_A_per_abs_PAR_umol_per_umol` (canopy LUE),
  `inst_canopy_A_per_incident_PAR_umol_per_umol` and `n_leaflets`, which counts sub-leaf elements
  (nine per leaflet).
- `outputs/<SITE>/per_leaf/<LOC_ID>_DAP<NNN>.csv`: one row per sub-leaf element with `UUID`,
  `z_m` (height of the element center, m), `leaf_area_m2`, `abs_PAR_W_m2` (absorbed PAR per unit
  element area), `A_umol_m2_s` (net photosynthesis) and `Vcmax_local` (Vcmax25 of the element).

`code/2_helios_simulation/scripts/04_combine_task_outputs.py` joins the per-task summaries into
`outputs/helios/helios_canopy_summary_SF.csv` and `..._EF.csv`. The per-element files are the
basis of the depth and within-layer distributions of absorbed PAR and canopy A (Figs 2D, 3C-D and
S7C-D, Methods S1.10).

### Mesh-test driver

```
./helios_mesh_test <SITE> <SPACING> <LEAF_TYPE> <DAP> <NX> <NY>
./helios_mesh_test EF 15 Broad 61 3 3
```

The simulation code is that of the main driver. It differs in five places:

1. Two global variables hold the sub-leaf grid NX x NY.
2. The arguments name a class-mean canopy and the grid. The driver builds the canopy
   identifier `<SITE>_<SPACING>_<LEAF_TYPE>_DAP<NNN>` (for example `EF_15_Broad_DAP061`), the
   `Loc_ID` of that canopy in the input file.
3. It reads one input file, `../inputs/mesh_test_inputs.csv` (the eight class-mean canopies,
   `data/simulation_inputs/mesh_test_inputs.csv`), which also serves as the class-mean lookup.
4. Each leaflet is divided into NX x NY elements instead of 3 x 3.
5. The summary file is `outputs/<SITE>/per_task/canopy_summary_<canopy identifier>_N<NX>x<NY>.csv`
   and has three more columns, `N_sub_x`, `N_sub_y` and `N_sub_total`.

The per-element file is `outputs/<SITE>/per_leaf/<canopy identifier>_DAP<NNN>.csv`. Its name
does not contain the grid, so the seven runs of one canopy write the same file and the run that
finished last is the one kept (section 5 of `docs/cluster_run.md`).
