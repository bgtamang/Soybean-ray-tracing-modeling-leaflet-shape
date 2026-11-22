# Per-plot canopy-structure metrics from the LiDAR height histograms
#
# Purpose
#   Computes canopy height and vertical foliage-distribution metrics for every Energy Farm LiDAR
#   plot and flight date from the 1-cm return-height histograms, and joins the leaflet-type
#   crosswalk. Canopy height is the 99th percentile of return height (h99). Foliage returns are
#   those 0.05 m or more above the ground, and their heights are divided by h99 to give
#   relative canopy height (Methods S1.11). The per-plot metrics are listed in Table S9 and
#   summarized by date in Table S8, and the relative-height profiles are drawn in Fig. 5C.
#
#   Metric definitions
#     h95, h99       95th and 99th percentiles of return height (m), h99 being canopy height
#     hmax           highest return (m)
#     lpi5, lpi10    share of returns below 0.05 m and below 0.10 m (gap fraction to the ground)
#     ht_p05         5th percentile of return height (m), the lowest height the beams sampled well
#     density        returns per cm2 of plot footprint (footprint = x extent x y extent)
#     rel_median     median relative height of the foliage returns ("median foliage height")
#     frac_above07   share of foliage returns at relative height 0.70 or above
#     frac_top       share of the foliage returns above relative height 0.50 that lie above 0.75
#                    ("top-heaviness")
#     d50_full       1 - rel_median
#   Relative heights are binned in 0.05 steps. Percentiles are read from the histogram at the
#   bin midpoints.
#
# Inputs
#   outputs/field_validation/lidar/plot_height_histograms.csv   return-height histograms
#                                                                (02_point_cloud_histograms.R)
#   outputs/field_validation/lidar/plot_leaftype_crosswalk.csv  plot -> leaflet type
#                                                                (01_plot_crosswalk.R)
#
# Outputs
#   outputs/field_validation/lidar/plot_metrics.csv
#       one row per plot and flight date with field position, leaflet type, genotype, line,
#       Helios flag, date, days after planting (DAP), point count, footprint and the metrics above
#   outputs/field_validation/lidar/plot_relative_height_profiles.csv
#       share of each plot's foliage returns in 20 relative-height bins (bin midpoints 0.025 to
#       0.975), per plot and flight date
#
# Usage
#   Rscript code/6_field_validation/lidar/03_canopy_structure_metrics.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

options(stringsAsFactors = FALSE, warn = 1)

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
OUT_DIR <- file.path(ROOT, "outputs", "field_validation", "lidar")
IN_HIST <- file.path(OUT_DIR, "plot_height_histograms.csv")
IN_CW   <- file.path(OUT_DIR, "plot_leaftype_crosswalk.csv")

NBIN <- 200L; BINW <- 0.01                           # 200 bins of 0.01 m (0 to 2 m)
PLANT <- as.Date("2024-05-30")                       # Energy Farm planting date
date_map <- c(June10="2024-06-10", June11="2024-06-11", June20="2024-06-20", June27="2024-06-27",
              July1="2024-07-01", July5="2024-07-05", July12="2024-07-12", July15="2024-07-15",
              July18="2024-07-18", July22="2024-07-22", July26="2024-07-26", July30="2024-07-30",
              Aug8="2024-08-08", Aug13="2024-08-13", Aug22="2024-08-22")

# Weighted percentile of return height from a histogram, read at the bin midpoint.
mids <- (seq_len(NBIN) - 0.5) * BINW
wpct <- function(counts, p) {
  tot <- sum(counts); if (tot == 0) return(NA_real_)
  mids[which(cumsum(counts) >= p * tot)[1]]
}

cw <- read.csv(IN_CW)
cw_key <- paste(cw$block, cw$plot, sep = "|")

H  <- read.csv(IN_HIST)
bcols <- paste0("b", 0:(NBIN-1))

fmt <- function(v, d=4) ifelse(is.na(v), "NA", formatC(v, format="f", digits=d))
cm <- file(file.path(OUT_DIR, "plot_metrics.csv"), "w")
writeLines("block,plot,spacing,pass,range,leaf_type,genoID,line,helios,date,DAP,npts,area_m2,density_ptscm2,h95,h99,hmax,lpi5,lpi10,ht_p05,rel_median,frac_above07,frac_top,d50_full", cm)
cr <- file(file.path(OUT_DIR, "plot_relative_height_profiles.csv"), "w")
writeLines("block,plot,spacing,leaf_type,date,DAP,relbin,share", cr)

Hmat <- as.matrix(H[, bcols])
nrw <- nrow(H); nskip <- 0
for (i in seq_len(nrw)) {
  block <- H$block[i]; plot <- H$plot[i]; date <- H$date[i]; npts <- H$npts[i]
  mrow <- match(paste(block, plot, sep="|"), cw_key)
  if (is.na(mrow)) { nskip <- nskip + 1; next }
  leaf <- cw$leaf_type[mrow]; spacing <- cw$spacing[mrow]
  pass <- cw$pass[mrow]; range <- cw$range[mrow]; geno <- cw$genoID[mrow]
  line <- cw$line[mrow]; helios <- cw$helios[mrow]
  dstr <- date_map[[date]]; dap <- if (!is.null(dstr)) as.integer(as.Date(dstr) - PLANT) else -1L

  # Height percentiles, gap fractions and return density.
  h <- as.numeric(Hmat[i, ]); zmax <- H$zmax[i]
  h95 <- wpct(h, 0.95); h99 <- wpct(h, 0.99)
  lpi5  <- if (npts) sum(h[1:5]) / npts else 0
  lpi10 <- if (npts) sum(h[1:10]) / npts else 0
  htp05 <- wpct(h, 0.05)
  area  <- max((H$xmax[i]-H$xmin[i])*(H$ymax[i]-H$ymin[i]), 1e-6)
  dens  <- npts / (area * 10000)

  # Relative-height profile of the foliage returns (bins b5 and above, z >= 0.05 m). Heights are
  # divided by h99 (by the highest return while h99 is 0.2 m or less) and capped at 1.
  ztop <- if (!is.na(h99) && h99 > 0.2) h99 else zmax
  rel <- numeric(20); foltot <- 0
  idx <- 6:NBIN
  cnt <- h[idx]
  if (any(cnt > 0)) {
    zr <- pmin(pmax(mids[idx] / ztop, 0), 1)
    rb <- pmin(floor(zr / 0.05), 19)
    rel <- as.numeric(tapply(cnt, factor(rb, levels=0:19), sum)); rel[is.na(rel)] <- 0
    foltot <- sum(rel)
  }
  relMedian <- frac_above07 <- frac_top <- d50 <- NA_real_
  # The median is the midpoint of the bin in which the cumulative share from the ground reaches 0.5.
  if (foltot > 0) {
    cumsh <- cumsum(rel)
    relMedian <- ((which(cumsh >= 0.5 * foltot)[1] - 1) + 0.5) * 0.05
    d50 <- 1 - relMedian
    frac_above07 <- sum(rel[15:20]) / foltot           # relative-height bins 14-19, zr >= 0.70
    t50 <- sum(rel[11:20]); t75 <- sum(rel[16:20])      # zr >= 0.50 and zr >= 0.75
    frac_top <- if (t50 > 0) t75 / t50 else NA_real_
    for (rbn in 0:19)
      writeLines(sprintf("%s,%d,%s,%s,%s,%d,%.3f,%.5f", block, plot, spacing, leaf, date, dap,
                         (rbn + 0.5) * 0.05, rel[rbn + 1] / foltot), cr)
  }

  writeLines(paste(block, plot, spacing, pass, range, leaf, geno, line, helios, date, dap, npts,
                   formatC(area, format="f", digits=5), formatC(dens, format="f", digits=2),
                   fmt(h95), fmt(h99), formatC(zmax, format="f", digits=3),
                   formatC(lpi5, format="f", digits=5), formatC(lpi10, format="f", digits=5),
                   fmt(htp05), fmt(relMedian), fmt(frac_above07), fmt(frac_top), fmt(d50),
                   sep = ","), cm)
}
close(cm); close(cr)
cat(sprintf("Canopy-structure metrics: %d plot x date rows, %d histogram rows without a crosswalk entry\n",
            nrw - nskip, nskip))
