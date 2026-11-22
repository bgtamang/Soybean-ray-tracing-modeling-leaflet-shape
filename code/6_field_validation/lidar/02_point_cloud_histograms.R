# Height histograms of the Energy Farm SpiderCam LiDAR point clouds
#
# Purpose
#   Reads every per-plot point cloud (PLY) of the Energy Farm SpiderCam LiDAR in the package and
#   reduces it to a 1-cm histogram of return heights, with the point count and the x, y and z
#   extent of the cloud. The package holds the point clouds of the 224 plots simulated with Helios
#   (the BC3 near-isogenic line plots), 2,700 files and 3.8 GB in all. All canopy-structure
#   metrics (03_canopy_structure_metrics.R) are computed from these histograms, so the point
#   clouds are read only once. The histograms support Fig. 5C and Tables S8 and S9.
#
# Inputs
#   data/lidar/point_clouds/<block>/<flight date>/<file>.ply
#       per-plot point clouds, one ASCII PLY file per plot and flight date. The block and the
#       flight date are read from the folder names and the pass and plot number from the file name
#       (<block>_Pass_<pass>_<date and time>_Plot_<plot>.ply)
#
# Outputs
#   outputs/field_validation/lidar/plot_height_histograms.csv
#       one row per plot and flight date with columns block, plot, pass, date, npts, xmin, xmax,
#       ymin, ymax, zmin, zmax and b0 to b199, where b_i is the number of returns with height z in
#       [i x 0.01, (i + 1) x 0.01) m. Returns below 0 m are counted in b0 and returns at or above
#       2 m in b199.
#
# Usage
#   Rscript code/6_field_validation/lidar/02_point_cloud_histograms.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

options(stringsAsFactors = FALSE, warn = 1)

ROOT      <- Sys.getenv("PACKAGE_ROOT", unset = ".")
IN_CLOUDS <- file.path(ROOT, "data", "lidar", "point_clouds")
OUT_DIR   <- file.path(ROOT, "outputs", "field_validation", "lidar")
OUT       <- file.path(OUT_DIR, "plot_height_histograms.csv")

if (!dir.exists(IN_CLOUDS))
  stop("The point clouds were not found at data/lidar/point_clouds/. ",
       "Unzip lidar_point_clouds_ef.zip into the package root.")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

NBIN <- 200L; BINW <- 0.01                           # 200 bins of 0.01 m (0 to 2 m)

# The files are processed in the order of their paths, sorted byte by byte, so the rows of the
# output come in the same order on every system.
ply <- sort(list.files(IN_CLOUDS, pattern = "\\.ply$", recursive = TRUE), method = "radix")
total <- length(ply)
if (total == 0 || any(lengths(strsplit(ply, "/")) != 3))
  stop("Expected point clouds as data/lidar/point_clouds/<block>/<flight date>/<file>.ply.")
cat(sprintf("Reducing %d PLY clouds -> %s\n", total, basename(OUT)))

con_out <- file(OUT, "w")
writeLines(paste(c("block","plot","pass","date","npts","xmin","xmax","ymin","ymax","zmin","zmax",
                   paste0("b", 0:(NBIN-1))), collapse = ","), con_out)

# Each file is <block>/<flight date>/<file>.ply below data/lidar/point_clouds/. The PLY body holds
# seven values per point, of which the first three are x, y and z (m).
t0 <- Sys.time()
for (i in seq_len(total)) {
  name  <- ply[i]
  parts <- strsplit(name, "/")[[1]]
  block <- parts[1]; date <- parts[2]; fn <- basename(name)
  pass  <- if (grepl("Pass_(\\d+)", fn)) as.integer(sub(".*Pass_(\\d+).*", "\\1", fn)) else -1L
  plot  <- as.integer(sub(".*Plot_?(\\d+)\\.ply$", "\\1", fn))

  raw <- readLines(file.path(IN_CLOUDS, name), warn = FALSE)
  h <- which(raw == "end_header")[1]
  v <- scan(text = raw[(h + 1):length(raw)], what = double(), quiet = TRUE)
  m <- matrix(v, ncol = 7, byrow = TRUE)
  x <- m[, 1]; y <- m[, 2]; z <- m[, 3]

  bins <- floor(z / BINW); bins[bins < 0] <- 0L; bins[bins >= NBIN] <- NBIN - 1L
  hcount <- tabulate(bins + 1L, nbins = NBIN)

  row <- c(block, plot, pass, date, length(z),
           sprintf("%.4f", c(min(x), max(x), min(y), max(y), min(z), max(z))),
           hcount)
  writeLines(paste(row, collapse = ","), con_out)

  if (i %% 100 == 0) {
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("  %d/%d  %.1f/s  eta %.1f min\n", i, total, i/el, (total-i)/(i/el)/60))
  }
}
close(con_out)
cat(sprintf("Done: %d rows in %.1f min -> %s\n", total,
            as.numeric(difftime(Sys.time(), t0, units="mins")), basename(OUT)))
