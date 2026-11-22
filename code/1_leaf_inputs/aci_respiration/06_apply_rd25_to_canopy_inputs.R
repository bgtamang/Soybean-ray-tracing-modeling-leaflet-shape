# Write the per-plot simulation inputs with combination-mean Rd25
#
# Purpose
#   Replaces the per-plot rd25 column of the canopy inputs with the Rd25 mean of each plot's
#   site x row spacing x leaflet type combination (05_rd25_combination_means.R), so that every
#   plot of a combination uses the same Rd25 (Methods, Table S14). Plots without a matching
#   combination would keep their own value. The result is the per-plot input table of the
#   Helios runs, one row per plot and date. The leaf optics (PAR and NIR reflectance,
#   transmittance and absorptance, SPAD and LMA) come from the leaf-optics step. The per-plot
#   Vcmax25, Jmax25 and Tp25, LAI, plant height and weather columns come from
#   data/canopy_inputs_base/ and pass through unchanged. When the Rd25 means come from the as-run
#   fits (the default of 05_rd25_combination_means.R), the written files equal the as-run inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_{SF,EF}.csv.
#
# Inputs
#   outputs/leaf_inputs/rd25_combination_means.csv         Rd25 means (05_rd25_combination_means.R)
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_SF.csv   inputs with leaf optics, SoyFACE
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_EF.csv   as above, Energy Farm
#                                                          (leaf_optics/07_build_canopy_inputs.py)
#
# Outputs
#   outputs/leaf_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   Helios per-plot inputs, SoyFACE
#   outputs/leaf_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   Helios per-plot inputs, Energy Farm
#
# Usage
#   Rscript code/1_leaf_inputs/aci_respiration/06_apply_rd25_to_canopy_inputs.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
LEAF_IN <- file.path(ROOT, "outputs", "leaf_inputs")
OUT_DIR <- file.path(ROOT, "outputs", "leaf_inputs")

# -------- Read the Rd25 combination means --------
cm <- read.csv(file.path(LEAF_IN, "rd25_combination_means.csv"), stringsAsFactors = FALSE)
cat(sprintf("Rd25 combination means: %d rows\n", nrow(cm)))
print(cm[, c("Site","Spacing","Leaf_type","Rd25_mean","Rd25_n")])

# -------- Process each site --------
process_site <- function(site) {
    in_fp <- file.path(LEAF_IN, sprintf("canopy_inputs_leaf_optics_%s.csv", site))
    d <- read.csv(in_fp, stringsAsFactors = FALSE)
    cat(sprintf("\n[%s] %d rows; per-plot rd25: mean=%.3f, range=[%.3f, %.3f]\n",
                site, nrow(d),
                mean(d$rd25, na.rm = TRUE),
                min(d$rd25, na.rm = TRUE), max(d$rd25, na.rm = TRUE)))

    # Keep the per-plot value as the fallback for plots without a combination mean.
    d$rd25_orig <- d$rd25

    # Join the combination mean of this site by (Spacing, Leaf_type).
    cm_site <- cm[cm$Site == site, c("Spacing","Leaf_type","Rd25_mean")]
    names(cm_site)[names(cm_site) == "Rd25_mean"] <- "rd25_cellmean"
    d <- merge(d, cm_site, by = c("Spacing","Leaf_type"), all.x = TRUE)

    # Every plot has a Broad or Narrow leaflet type, so all plots are expected to match.
    n_no_match <- sum(is.na(d$rd25_cellmean))
    if (n_no_match > 0) {
        cat(sprintf("  WARNING: %d rows have no combination mean and keep their per-plot rd25\n",
                    n_no_match))
    }
    d$rd25 <- ifelse(is.na(d$rd25_cellmean), d$rd25_orig, d$rd25_cellmean)

    cat(sprintf("[%s] rd25 by (Spacing, Leaf_type):\n", site))
    s <- aggregate(rd25 ~ Spacing + Leaf_type, data = d, FUN = function(x) c(mean = mean(x), n = length(x)))
    for (i in seq_len(nrow(s))) {
        cat(sprintf("  %d-cm rows  %-7s rd25=%.3f  (n=%d rows)\n",
                    ifelse(s$Spacing[i] == 15, 38, 76), s$Leaf_type[i],
                    as.numeric(s$rd25[i, "mean"]), as.integer(s$rd25[i, "n"])))
    }

    # The join column, the per-plot fallback and the per-plot rd25_source flag are not simulation
    # inputs and are removed.
    d$rd25_cellmean <- NULL
    d$rd25_orig     <- NULL
    d$rd25_source   <- NULL

    out_fp <- file.path(OUT_DIR, sprintf("canopy_inputs_per_plot_per_DAP_%s.csv", site))
    write.csv(d, out_fp, row.names = FALSE)
    h <- substr(tools::md5sum(out_fp), 1, 12)
    cat(sprintf("[%s] wrote %s  md5=%s\n", site, basename(out_fp), h))

    invisible(list(site = site, n_rows = nrow(d), md5 = h))
}

results <- lapply(c("SF","EF"), process_site)

cat("\n=== Summary ===\n")
for (r in results) {
    cat(sprintf("  %s: %d rows, md5=%s\n", r$site, r$n_rows, r$md5))
}
