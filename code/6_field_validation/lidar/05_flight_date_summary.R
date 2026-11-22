# LiDAR canopy structure by flight date, 76-cm rows at the Energy Farm
#
# Purpose
#   Assembles the class means and SE of the LiDAR metrics of broad- and narrow-leaflet BC3
#   near-isogenic lines in 76-cm rows (Spacing = 30) with the per-date Welch P values into one
#   table by flight date. Values are formatted as mean±SE. Return density is per cm2 of the
#   standardized 1.5 m2 plot footprint, canopy height is h99 (m), and median foliage height and
#   top-heaviness are fractions of canopy height. This table is the basis of Table S8.
#
# Inputs
#   outputs/field_validation/lidar/group_means_by_date.csv   class means and SE
#                                                             (04_leaflet_type_contrasts.R)
#   outputs/field_validation/lidar/welch_tests_by_date.csv   per-date Welch tests (same script)
#
# Outputs
#   outputs/field_validation/lidar/structure_by_flight_date_76cm.csv
#       one row per flight date with n per leaflet type, return density, canopy height, median
#       foliage height and top-heaviness (mean±SE by leaflet type) and their Welch P values
#
# Usage
#   Rscript code/6_field_validation/lidar/05_flight_date_summary.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

options(stringsAsFactors=FALSE, warn=1)

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
OUT_DIR <- file.path(ROOT, "outputs", "field_validation", "lidar")
ord <- c("June10","June11","June20","June27","July1","July5","July12","July15","July18","July22","July26","July30","Aug8","Aug13","Aug22")

G <- read.csv(file.path(OUT_DIR,"group_means_by_date.csv")); G$spacing <- as.character(G$spacing)
W <- read.csv(file.path(OUT_DIR,"welch_tests_by_date.csv")); W$spacing <- as.character(W$spacing)
G <- subset(G, spacing=="30"); W <- subset(W, spacing=="30")
pval <- function(dt, mtr){ v <- W$p[W$date==dt & W$metric==mtr]; if(length(v)) v[1] else NA }

dates <- ord[ord %in% G$date]
rows <- lapply(dates, function(dt){
  b <- G[G$date==dt & G$leaf=="Broad", ]; n <- G[G$date==dt & G$leaf=="Narrow", ]
  data.frame(
    Date = dt, DAP = b$DAP[1],
    n_Broad = b$n, n_Narrow = n$n,
    Density_Broad  = sprintf("%.2f±%.2f", b$density_ptscm2_mean, b$density_ptscm2_se),
    Density_Narrow = sprintf("%.2f±%.2f", n$density_ptscm2_mean, n$density_ptscm2_se),
    CanopyHt_Broad  = sprintf("%.3f±%.3f", b$h99_mean, b$h99_se),
    CanopyHt_Narrow = sprintf("%.3f±%.3f", n$h99_mean, n$h99_se),
    p_height = round(pval(dt,"h99"),3),
    MedFoliageHt_Broad  = sprintf("%.3f±%.3f", b$rel_median_mean, b$rel_median_se),
    MedFoliageHt_Narrow = sprintf("%.3f±%.3f", n$rel_median_mean, n$rel_median_se),
    p_medht = round(pval(dt,"rel_median"),3),
    TopHeavy_Broad  = sprintf("%.3f±%.3f", b$frac_top_mean, b$frac_top_se),
    TopHeavy_Narrow = sprintf("%.3f±%.3f", n$frac_top_mean, n$frac_top_se),
    p_topheavy = round(pval(dt,"frac_top"),3)
  )
})
tab <- do.call(rbind, rows)
write.csv(tab, file.path(OUT_DIR,"structure_by_flight_date_76cm.csv"), row.names=FALSE)

cat("Wrote structure_by_flight_date_76cm.csv  (", nrow(tab), "flight dates )\n\n")
cat("Column key: Density = returns/cm^2 (footprint 1.5 m^2); CanopyHt = h99 (m);",
    "MedFoliageHt = median foliage height (fraction of canopy ht); TopHeavy = frac_top.\n")
cat("Values are class mean +/- SE. p = Welch two-sample test, broad vs narrow, per date.\n\n")
# Rows of the late-season flights (26 July to 22 August)
print(tab[tab$Date %in% c("July26","July30","Aug8","Aug13","Aug22"),
          c("Date","DAP","n_Broad","Density_Broad","Density_Narrow","TopHeavy_Broad","TopHeavy_Narrow","p_topheavy")], row.names=FALSE)
