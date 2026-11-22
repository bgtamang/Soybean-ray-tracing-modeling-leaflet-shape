# Running the Helios simulations on a SLURM cluster

The Helios drivers (`docs/helios_build.md`) run one simulation per call, so the 5,299 plot-dates
of the paper and the 56 runs of the sub-leaf mesh test were run as SLURM job arrays on a cluster
with NVIDIA A40 GPUs. This page describes the project folder each driver expects, the task lists,
the job-array scripts, how the per-task outputs are combined, and the mesh test. The cluster
settings in the scripts (partition, GPU type, modules, memory and time limits) are examples to
adapt.

## 1. Workflow

Main runs (`code/2_helios_simulation/`):

1. Set up a project folder on the cluster with the code and the inputs (section 2).
2. Build `build/helios_canopy` on a GPU compute node: `bash scripts/01_build.sh`.
3. Write the task list: `bash scripts/02_make_task_list.sh`.
4. Submit the job array: `mkdir -p logs && sbatch scripts/03_submit_array.sh`.
5. Copy `build/outputs/SF/` and `build/outputs/EF/` into `outputs/helios/` of the package.
6. Combine the per-task summaries, from the package root:
   `python code/2_helios_simulation/scripts/04_combine_task_outputs.py`.

The mesh test (`code/3_mesh_test/`) follows the same steps with its own inputs (section 5).

## 2. Project folder of the main runs

The driver reads `../inputs/` and writes `outputs/` relative to its working directory, and the
job script runs it from `build/`. The project folder must therefore look like this (the folder
name and location are free):

```
helios_canopy/                      project folder
|-- helios_main.cpp
|-- CMakeLists.txt
|-- scripts/
|   |-- 01_build.sh
|   |-- 02_make_task_list.sh
|   |-- 03_submit_array.sh
|   |-- 04_combine_task_outputs.py
|   `-- task_list.txt               written by 02_make_task_list.sh
|-- inputs/
|   |-- canopy_inputs_per_plot_per_DAP_SF.csv
|   |-- canopy_inputs_per_plot_per_DAP_EF.csv
|   |-- canopy_inputs_cell_mean_per_DAP_SF.csv
|   `-- canopy_inputs_cell_mean_per_DAP_EF.csv
|-- build/                          made by 01_build.sh, the driver runs here
|   |-- helios_canopy
|   `-- outputs/                    made by the driver
|       |-- SF/per_task/   SF/per_leaf/
|       `-- EF/per_task/   EF/per_leaf/
`-- logs/                           SLURM output and error files
```

To set it up from the package:

```bash
PKG=/path/to/package
cp -r "$PKG/code/2_helios_simulation" helios_canopy
mkdir -p helios_canopy/inputs helios_canopy/logs
cp "$PKG"/data/simulation_inputs/canopy_inputs_*_per_DAP_*.csv helios_canopy/inputs/
```

The input files are the ones the runs read. Their MD5 checksums are:

| File | MD5 |
|---|---|
| `canopy_inputs_per_plot_per_DAP_SF.csv` | `c18416f22741e73cb703e36752960ed6` |
| `canopy_inputs_per_plot_per_DAP_EF.csv` | `cb57943e6a9ce325aedd6a1693a35886` |
| `canopy_inputs_cell_mean_per_DAP_SF.csv` | `f0bd870e881916052adaf22e73bdec51` |
| `canopy_inputs_cell_mean_per_DAP_EF.csv` | `57d321ccc7e20ec94aa134219c2390e6` |
| `task_list.txt` | `3281a772c895de1c65898d9b8af6cfc0` |
| `mesh_test_inputs.csv` | `f02f21b2955cf6ae2bec99cfbc1ca2c9` |
| `mesh_test_task_list.txt` | `70bf4cd237d9370b8e6092bf132e6f34` |

The per-plot files hold every input of a run: LAI and plant height on the date, leaflet length
and average width, weather means of 11:00-15:00 CST, Vcmax25, Jmax25, Rd25 and Tp25, and the
PROSPECT-D leaf optics. For plots without an A-Ci fit, Vcmax25, Jmax25 and Tp25 already hold one
fill value per location x row spacing x leaflet type (the `*_fill_used` values of Table S14,
with source columns `vcmax_source`, `jmax_source` and `tp25_source`), and Rd25 is the class value of
Table S14 for every plot. The class-mean files are the driver's fallback for a missing Vcmax25 or
Jmax25. No run needed them, and their class means differ slightly from the fill values.

## 3. Task list and job array

`scripts/02_make_task_list.sh` writes one line per plot-date, `<SITE> <LOC_ID> <SPACING>
<LEAF_TYPE> <DAP>`, for example `EF EF_1_1 30 Broad 31`. Energy Farm lines come first and
SoyFACE lines second, each sorted by DAP, Pass and Range. The list has 5,299 lines (2,240 Energy
Farm, 3,059 SoyFACE) and equals `data/simulation_inputs/task_list.txt`. `INPUT_DIR` and
`TASK_LIST` set other input and output locations.

`scripts/03_submit_array.sh` is the SLURM job. Each array task runs six consecutive lines of the
task list, because the cluster allowed at most 1,001 tasks per array. Array task i runs lines
6i - 5 to 6i, so the 884 array tasks cover the 5,299 lines. A failed run is reported in the log
and the chunk goes on. The settings in the script:

| Setting | Value |
|---|---|
| partition | `gpu` |
| GPU | `--gres=gpu:A40:1` |
| CPUs per task | 4 |
| memory | 16 GB |
| time limit per array task | 1 hour |
| array | `1-884%6` (at most six array tasks at a time) |
| logs | `logs/helios_canopy_<job>_<array task>.out` and `.err` |

Submit from the project folder, which the script takes from `SLURM_SUBMIT_DIR` unless
`PROJECT_DIR` is set:

```bash
cd helios_canopy
mkdir -p logs
sbatch scripts/03_submit_array.sh
squeue -u $USER
sacct -j <job ID> --format=JobID,State,Elapsed,MaxRSS,ExitCode -P
ls build/outputs/EF/per_task | wc -l      # 2,240 when the Energy Farm runs are complete
ls build/outputs/SF/per_task | wc -l      # 3,059 when the SoyFACE runs are complete
```

A run takes a few seconds at low LAI (about 5 s on an A40 for an early-season plot) and longer
as the canopy fills. To repeat failed lines, resubmit their array tasks, for example
`sbatch --array=17,203 scripts/03_submit_array.sh` for lines 97-102 and 1,213-1,218.

## 4. Combining the outputs

Copy the two site folders of `build/outputs/` into the package so that the per-task summaries
are in `outputs/helios/<SITE>/per_task/` and the per-element files in
`outputs/helios/<SITE>/per_leaf/`. The per-element files are large (about 15 GB for SoyFACE).
Then, from the package root:

```bash
python code/2_helios_simulation/scripts/04_combine_task_outputs.py
```

The script writes `outputs/helios/helios_canopy_summary_SF.csv` and
`outputs/helios/helios_canopy_summary_EF.csv`, one row per plot-date, and reports `OK` when the
row counts are 3,059 and 2,240. It also runs in the project folder on the cluster, with the
output folder as argument: `python scripts/04_combine_task_outputs.py build/outputs`.

## 5. Sub-leaf mesh test

The mesh test repeats the simulation of the class-mean canopy of each location x row spacing x
leaflet type combination on its peak-LAI date with 1, 4, 9, 25, 64, 144 and 225 sub-leaf
elements per leaflet (Fig S8B-C, Table S12). The driver differs from the main driver only in the
points listed in `docs/helios_build.md`.

Project folder:

```
helios_mesh_test/                   project folder
|-- mesh_test_main.cpp
|-- CMakeLists.txt
|-- scripts/
|   |-- 01_make_mesh_test_inputs.py  run in the package (step 1 below)
|   |-- 02_build.sh
|   |-- 03_make_task_list.sh
|   |-- 04_submit_array.sh
|   |-- 05_combine_outputs.sh
|   `-- task_list.txt               written by 03_make_task_list.sh
|-- inputs/
|   `-- mesh_test_inputs.csv
|-- build/                          made by 02_build.sh, the driver runs here
|   |-- helios_mesh_test
|   `-- outputs/
|       |-- EF/per_task/   EF/per_leaf/
|       `-- SF/per_task/   SF/per_leaf/
`-- logs/
```

Steps:

1. Inputs. From the package root, `python code/3_mesh_test/scripts/01_make_mesh_test_inputs.py`
   writes `outputs/mesh_test/mesh_test_inputs.csv`, the eight class-mean canopies. For each
   class it takes the date of the highest class-mean LAI and averages the per-plot inputs of
   that date. The file equals `data/simulation_inputs/mesh_test_inputs.csv`. Copy either one to
   `inputs/mesh_test_inputs.csv` of the project folder:

   ```bash
   cp -r "$PKG/code/3_mesh_test" helios_mesh_test
   mkdir -p helios_mesh_test/inputs helios_mesh_test/logs
   cp "$PKG/data/simulation_inputs/mesh_test_inputs.csv" helios_mesh_test/inputs/
   ```

2. Build on a GPU compute node, for example in an interactive job:

   ```bash
   srun --pty -p gpu --gres=gpu:A40:1 --cpus-per-task=4 --mem=16G --time=01:00:00 bash
   cd helios_mesh_test && bash scripts/02_build.sh
   exit
   ```

3. Task list: `bash scripts/03_make_task_list.sh` writes 56 lines,
   `<SITE> <SPACING> <LEAF_TYPE> <DAP> <NX> <NY>`, the eight canopies on their peak-LAI dates
   (Energy Farm 38-cm rows DAP 61, Energy Farm 76-cm rows DAP 68 for broad and 75 for narrow,
   SoyFACE DAP 76) times NX = NY = 1, 2, 3, 5, 8, 12 and 15. It equals
   `data/simulation_inputs/mesh_test_task_list.txt`.

4. Job array: `mkdir -p logs && sbatch scripts/04_submit_array.sh` runs one line per array task
   (`--array=1-56%6`, other settings as in section 3). Runs with 144 or 225 elements per leaflet
   at peak LAI can take more than one hour. Allow up to three hours for them (`--time=03:00:00`).

5. Combine. Copy `build/outputs/EF/` and `build/outputs/SF/` to `outputs/mesh_test/` of the
   package, then from the package root:

   ```bash
   bash code/3_mesh_test/scripts/05_combine_outputs.sh
   ```

   The script writes `outputs/mesh_test/mesh_test_summary.csv`, 56 rows with the columns of the
   per-task summaries, and warns when a run is missing. In the project folder on the cluster the
   same script runs with `MESH_TEST_DIR=build/outputs`.

Table S12 holds these values with renamed columns: `Task_ID` = `Loc_ID`, `anchor_DAP` = `DAP`,
`anchor_date` = `date`, `LAI` = `LAI_used`, `canopy_A_umol_m2_s` = `A_umol_m2_s`, `fAPAR` =
`frac_PAR_absorbed`, `canopy_LUE` = `inst_canopy_A_per_abs_PAR_umol_per_umol` and
`n_subleaf_elements` = `n_leaflets`. The table gives sites by name and row spacing in cm, while
the run identifiers keep the spacing code of the data (15 = 38 cm, 30 = 76 cm).

The per-element file of a mesh-test run is named by canopy and date only, so the seven runs of a
canopy write the same file, and the file kept is that of the run that finished last. The files in
`outputs/mesh_test/<SITE>/per_leaf/` hold these grids (identified by their number of rows, which
equals `n_leaflets` of one run):

| Per-element file | Elements per leaflet |
|---|---|
| `EF_15_Broad_DAP061_DAP061.csv` | 144 |
| `EF_15_Narrow_DAP061_DAP061.csv` | 64 |
| `EF_30_Broad_DAP068_DAP068.csv` | 144 |
| `EF_30_Narrow_DAP075_DAP075.csv` | 144 |
| `SF_15_Broad_DAP076_DAP076.csv` | 144 |
| `SF_15_Narrow_DAP076_DAP076.csv` | 64 |
| `SF_30_Broad_DAP076_DAP076.csv` | 144 |
| `SF_30_Narrow_DAP076_DAP076.csv` | 64 |

Only the Energy Farm 76-cm rows have both leaflet types at the same grid, which is why Methods
S1.10 compares element-level outputs there only.

## 6. Adapting the scripts to another cluster

- Modules. The scripts load `CMake/3.29.5-IGB-gcc-8.2.0` and `CUDA/12.8.0`. Load the CMake
  (3.15 or later) and CUDA modules of your system instead.
- GPU resources. Change `--partition` and `--gres` to the GPU partition and GPU type of your
  cluster, and the throttle (`%6`) to the number of GPUs you may use at once.
- Array size. If your cluster allows larger arrays, `CHUNK_SIZE` in `03_submit_array.sh` can be
  lowered together with `--array` (the number of array tasks must be at least 5,299 divided by
  `CHUNK_SIZE`, rounded up).
- Paths. `HELIOS_DIR`, `VULKAN_SDK`, `CRT_FALLBACK_DIR`, `PROJECT_DIR`, `INPUT_DIR`, `TASK_LIST`
  and `MESH_TEST_DIR` can be set in the environment. The defaults are generic (`$HOME/Helios`,
  `$HOME/local`, the submit folder), except `CRT_FALLBACK_DIR`, whose default is a path on the
  cluster used for the runs.
