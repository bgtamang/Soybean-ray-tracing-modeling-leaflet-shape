# Mean dark respiration (Rd25) for each site, row spacing and leaflet type
#
# Purpose
#   Averages the per-plant Rd25 estimates (RL_at_25 of the PhotoGEA fits, constrained to be
#   non-negative) within each site x row spacing x leaflet type combination, giving the eight
#   combination means that Helios applies to every plot of the combination (Rd25_used and
#   n_Rd25_used in Table S14, Methods S1.4). Before averaging, the fits from three instruments
#   with questionable calibration records (04_read_licor_calibration.R) are removed, as listed
#   below.
#     Ains2, all sites    most of its fits ended at the zero bound of Rd25
#     Ripe14, SoyFACE     no CO2 or H2O range match recorded before the SoyFACE measurements
#     Ripe8, all sites    last range match on 1 July 2024, 22-23 days before the Energy Farm and
#                         28-29 days before the SoyFACE measurements
#   The exclusions apply to Rd25 only. The remaining fits are matched to their plots, which gives
#   the leaflet type, and only fits with reliable Vcmax, J and Tp (PhotoGEA trust flags) are
#   averaged. By default the script reads the as-run fits shipped with the package and reproduces
#   the Rd25 values used in the simulations. Means from a refit (03_fit_aci_curves.R) differ by a
#   few percent, because the fitting optimizer is random.
#
# Inputs
#   outputs/leaf_inputs/aci_fits_per_plant.csv             as-run per-plant fits used for the
#                                                          simulations (shipped with the package)
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_SF.csv   plot position and leaflet type, SoyFACE
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_EF.csv   as above, Energy Farm
#                                                          (leaf_optics/07_build_canopy_inputs.py)
#
# Outputs
#   outputs/leaf_inputs/rd25_combination_means.csv   Site, Spacing, Leaf_type, Rd25_mean,
#                                                    Rd25_sd, Rd25_n (umol m-2 s-1)
#
# Usage
#   Rscript code/1_leaf_inputs/aci_respiration/05_rd25_combination_means.R   (run from the package root)
#   The optional environment variable ACI_FITS, a package-relative path, selects another fits
#   table in place of the as-run fits, for example
#   ACI_FITS=outputs/leaf_inputs/aci_fits_per_plant_refit.csv after a refit with
#   03_fit_aci_curves.R.
#
# Requirements
#   R (4.6.1 used); base R only

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
LEAF_IN <- file.path(ROOT, "outputs", "leaf_inputs")
OUT_DIR <- file.path(ROOT, "outputs", "leaf_inputs")

# Per-plant fits are the as-run fits unless ACI_FITS gives another package-relative path
FITS_REL <- Sys.getenv("ACI_FITS", unset = "")
if (!nzchar(FITS_REL)) FITS_REL <- file.path("outputs", "leaf_inputs", "aci_fits_per_plant.csv")

# Instruments excluded from the Rd25 means, each with "all" or the cells it is excluded from
EXCLUSIONS <- list(
    Ains2  = "all",                  # most fits at the zero bound of Rd25
    Ripe14 = c("SF_15","SF_30"),     # no range match recorded before the SoyFACE measurements
    Ripe8  = "all"                   # last range match 22-29 days before the measurements
)

# -------- Read the per-plant fits --------
fits <- read.csv(file.path(ROOT, FITS_REL),
                 stringsAsFactors = FALSE)
fits$Site    <- substr(fits$cell, 1, 2)
fits$Spacing <- as.integer(sub("^.._", "", fits$cell))
# The workbooks record the field Pass. In the plot identifiers the 38-cm plots (Spacing = 15)
# carry Pass + 10.
fits$Pass_canonical <- ifelse(fits$Spacing == 15, fits$Pass + 10, fits$Pass)
n_total <- nrow(fits)
cat(sprintf("Read %d per-plant fits from %s\n\n", n_total, FITS_REL))

# -------- Remove the excluded instruments --------
cat("Instrument exclusions\n")
for (m in names(EXCLUSIONS)) {
    cells <- EXCLUSIONS[[m]]
    if (identical(cells, "all")) {
        n_before <- nrow(fits)
        fits <- fits[fits$machine != m, ]
        cat(sprintf("  %s (all cells): %d fits removed\n", m, n_before - nrow(fits)))
    } else {
        n_before <- nrow(fits)
        fits <- fits[!(fits$machine == m & fits$cell %in% cells), ]
        cat(sprintf("  %s (cells %s): %d fits removed\n",
                    m, paste(cells, collapse=","), n_before - nrow(fits)))
    }
}
cat(sprintf("Remaining: %d of %d fits (%.0f%%)\n\n", nrow(fits), n_total,
            100*nrow(fits)/n_total))

# -------- Plot position and leaflet type --------
read_meta <- function(site) {
    fp <- file.path(LEAF_IN, sprintf("canopy_inputs_leaf_optics_%s.csv", site))
    d <- read.csv(fp, stringsAsFactors = FALSE)
    unique(d[, c("Location","Spacing","Pass","Range","Leaf_type","Loc_ID")])
}
meta <- rbind(read_meta("SF"), read_meta("EF"))
names(meta)[names(meta) == "Location"] <- "Site"

fj <- merge(fits, meta,
            by.x = c("Site","Spacing","Pass_canonical","Range"),
            by.y = c("Site","Spacing","Pass","Range"))

# -------- Keep fits with reliable Vcmax, J and Tp --------
fj_all <- fj
fj <- fj_all[fj_all$Vcmax_trust == "reliable" &
             fj_all$J_trust     == "reliable" &
             fj_all$Tp_trust    == "reliable", , drop = FALSE]
cat(sprintf("Fits with reliable Vcmax, J and Tp: %d of %d\n", nrow(fj), nrow(fj_all)))

# -------- Combination means --------
agg <- aggregate(RL_at_25 ~ Site + Spacing + Leaf_type, data = fj, FUN = function(x) {
    c(mean = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE), n = sum(!is.na(x)))
})
cell_means <- data.frame(
    Site      = agg$Site,
    Spacing   = agg$Spacing,
    Leaf_type = agg$Leaf_type,
    Rd25_mean = as.numeric(agg$RL_at_25[, "mean"]),
    Rd25_sd   = as.numeric(agg$RL_at_25[, "sd"]),
    Rd25_n    = as.integer(agg$RL_at_25[, "n"]),
    stringsAsFactors = FALSE
)
cell_means <- cell_means[order(cell_means$Site, cell_means$Spacing, cell_means$Leaf_type), ]

cat("\n=== Rd25 combination means (umol m-2 s-1) ===\n")
for (i in seq_len(nrow(cell_means))) {
    r <- cell_means[i, ]
    cat(sprintf("  %-6s %2d-cm rows  %-7s %7.3f  (sd=%.3f, n=%d)\n",
                r$Site, ifelse(r$Spacing == 15, 38, 76), r$Leaf_type,
                r$Rd25_mean, r$Rd25_sd, r$Rd25_n))
}

# -------- Write the combination means --------
out_csv <- file.path(OUT_DIR, "rd25_combination_means.csv")
write.csv(cell_means, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s\n", basename(out_csv)))
