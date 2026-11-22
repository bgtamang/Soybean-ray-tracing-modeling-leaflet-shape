# Leaflet-type crosswalk for the Energy Farm SpiderCam LiDAR plots
#
# Purpose
#   Assigns a field position, leaflet type (Broad or Narrow), genotype and line to every plot with
#   a SpiderCam LiDAR point cloud in the package. The point clouds are named by a plot number
#   within a SpiderCam block, so the field grid is decoded from that number (a 12-column module)
#   and matched to the field plot metadata by row spacing, pass and range. The package holds the
#   point clouds of the 224 plots simulated with Helios (the BC3 near-isogenic line plots, 112 per
#   row spacing). The 31 check plots of the trial, which are the parents of the population, were
#   not simulated and their point clouds are not included. Every plot is flagged as simulated
#   with Helios, and the flag is checked against the simulation inputs and the field metadata.
#   The crosswalk is used by all later LiDAR steps (Fig. 5C, Tables S8 and S9).
#
# Inputs
#   data/lidar/point_clouds/<block>/<flight date>/<file>.ply
#                                                        per-plot point clouds, one PLY file per
#                                                        plot and flight date. Only the folder and
#                                                        file names are read here
#   data/lidar/field_plot_metadata.csv                  field plot metadata of the Energy Farm
#                                                        (all 255 plots, including the check plots)
#                                                        with Location, Spacing, Pass, Range,
#                                                        Leaf_type, ID and Line
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_EF.csv per-plot simulation inputs, Energy Farm
#                                                        (leaf-inputs step), which define the plots
#                                                        simulated with Helios
#
# Outputs
#   outputs/field_validation/lidar/plot_leaftype_crosswalk.csv
#                                                        one row per LiDAR plot with SpiderCam block
#                                                        and plot number, spacing, pass, range,
#                                                        leaflet type, genotype ID, line and Helios
#                                                        flag (TRUE for every plot)
#
# Usage
#   Rscript code/6_field_validation/lidar/01_plot_crosswalk.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

options(stringsAsFactors = FALSE, warn = 1)

ROOT      <- Sys.getenv("PACKAGE_ROOT", unset = ".")
IN_CLOUDS <- file.path(ROOT, "data", "lidar", "point_clouds")
IN_META   <- file.path(ROOT, "data", "lidar", "field_plot_metadata.csv")
IN_HELIOS <- file.path(ROOT, "outputs", "leaf_inputs", "canopy_inputs_leaf_optics_EF.csv")
OUT_DIR   <- file.path(ROOT, "outputs", "field_validation", "lidar")
OUT       <- file.path(OUT_DIR, "plot_leaftype_crosswalk.csv")

if (!dir.exists(IN_CLOUDS))
  stop("The point clouds were not found at data/lidar/point_clouds/. ",
       "Unzip lidar_point_clouds_ef.zip into the package root.")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

## ---- 1. Field metadata: (Spacing, Pass, Range) -> leaflet type, genotype ID and line ----
md <- read.csv(IN_META)
ef <- md[md$Location == "EF", ]
key <- paste(ef$Spacing, ef$Pass, ef$Range, sep = "|")
leaf_lk <- setNames(ef$Leaf_type, key)
id_lk   <- setNames(ef$ID,        key)
line_lk <- setNames(ef$Line,      key)                   # BC3 (NIL) or a check line

## ---- 1b. Plots simulated with Helios at the Energy Farm (224 BC3 NILs, no checks) ----
## The LiDAR contrast uses this plot set, so it is a comparison between near-isogenic lines.
## The check entries are the parents of the population, which are not near-isogenic.
hz <- read.csv(IN_HELIOS)
helios_set <- unique(paste(hz$Spacing, hz$Pass, hz$Range, sep = "|"))

## ---- 2. Plot inventory: the plots with a point cloud in the package ----
## Each file is <block>/<flight date>/<file>.ply below data/lidar/point_clouds/.
ply <- list.files(IN_CLOUDS, pattern = "\\.ply$", recursive = TRUE)
parts <- strsplit(ply, "/")
if (length(ply) == 0 || any(lengths(parts) != 3))
  stop("Expected point clouds as data/lidar/point_clouds/<block>/<flight date>/<file>.ply.")
block <- vapply(parts, `[`, "", 1)                     # SpiderCam block Soybean_1, _2 or _3
plot  <- as.integer(sub(".*Plot_?(\\d+)\\.ply$", "\\1", basename(ply)))
inv <- unique(data.frame(block = block, plot = plot))
inv$spacing <- ifelse(inv$block == "Soybean_3", "15", "30")   # 38-cm rows (15) or 76-cm rows (30)

## ---- 3. Decode the field grid and look up the leaflet type ----
## The SpiderCam plot number N runs through a 12-column module:
##   Range = floor((N - 1) / 12) + 1 and Col = ((N - 1) %% 12) + 1.
## In 76-cm rows, columns 1-5 are block Soybean_1 (passes 1-5) and columns 7-11 are block
## Soybean_2 (passes 6-10, Pass = Col - 1). In 38-cm rows, columns 1-10 are block Soybean_3
## (passes 11-20, Pass = Col + 10).
decode_pass <- function(plot, spacing) {
  col <- ((plot - 1) %% 12) + 1
  if (spacing == "30") {
    ifelse(col <= 5, col, ifelse(col >= 7 & col <= 11, col - 1, NA_integer_))
  } else {
    ifelse(col <= 10, col + 10, NA_integer_)
  }
}
inv$range <- floor((inv$plot - 1) / 12) + 1
inv$col   <- ((inv$plot - 1) %% 12) + 1
inv$pass  <- mapply(decode_pass, inv$plot, inv$spacing)
k <- paste(inv$spacing, inv$pass, inv$range, sep = "|")
inv$leaf_type <- unname(leaf_lk[k])
inv$genoID    <- unname(id_lk[k])
inv$line      <- unname(line_lk[k])                   # BC3 = NIL, otherwise a check line
inv$helios    <- k %in% helios_set                    # TRUE = plot simulated with Helios

inv <- inv[order(inv$block, inv$plot), ]

## ---- 4. Checks ----
## Every plot must be mapped, and four plots whose leaflet type was confirmed independently
## (plots 2 and 76 of Soybean_1 are Narrow, plots 22 and 32 of Soybean_2 are Broad) must agree.
stopifnot(sum(is.na(inv$leaf_type)) == 0)
anchors <- c("Soybean_1|2" = "Narrow", "Soybean_1|76" = "Narrow",
             "Soybean_2|22" = "Broad", "Soybean_2|32" = "Broad")
akey <- paste(inv$block, inv$plot, sep = "|")
for (a in names(anchors)) {
  got <- inv$leaf_type[match(a, akey)]
  if (!identical(got, unname(anchors[a]))) stop(sprintf("Reference plot %s: got %s", a, got))
}
cat("Reference plots agree (plots 2 and 76 Narrow, plots 22 and 32 Broad).\n")
cat("Plot counts by row spacing (15 = 38 cm, 30 = 76 cm) x leaflet type (all plots with a point cloud):\n")
print(table(inv$spacing, inv$leaf_type))
h <- inv[inv$helios, ]
cat(sprintf("\nPlots simulated with Helios (BC3 NILs): %d (expected 224)\n", nrow(h)))
cat("Simulated plots by spacing x leaflet type (expected 56 Broad and 56 Narrow per spacing):\n")
print(table(h$spacing, h$leaf_type))
# Every simulated plot must have a point cloud in the package.
no_cloud <- setdiff(helios_set, k)
if (length(no_cloud) > 0)
  stop(sprintf("%d plots simulated with Helios have no point cloud in data/lidar/point_clouds/.",
               length(no_cloud)))
# The Helios flag must coincide with the BC3 line label of the field metadata. The package holds
# the point clouds of the simulated plots only, so both are TRUE for every plot.
stopifnot(all((inv$line == "BC3") == inv$helios))
cat(sprintf("Helios flag equals (Line == BC3) for all %d plots.\n", nrow(inv)))

write.csv(inv[, c("block","plot","spacing","pass","range","leaf_type","genoID","line","helios")],
          OUT, row.names = FALSE)
cat(sprintf("\nWrote %d rows to outputs/field_validation/lidar/plot_leaftype_crosswalk.csv\n", nrow(inv)))
