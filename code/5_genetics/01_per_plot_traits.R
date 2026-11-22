# Per-plot seasonal summaries of the Helios canopy traits
#
# Purpose
#   Reduces the Helios simulations of each plot (one per measurement date) to one value per plot
#   for canopy net photosynthesis (canopy A), the fraction of incident PAR absorbed (fAPAR) and
#   canopy light-use efficiency (canopy LUE), and attaches the BC3 line of each plot. Dates with
#   LAI below 3 are excluded before the summaries are taken. The reproductive-stage means of
#   canopy A and canopy LUE (A_mean_repro and L_mean_repro) are the per-plot phenotypes of the
#   Canopy A and Canopy LUE BLUPs (Fig. 7 and Tables S17, S18 and S20). The other summaries enter
#   the heritability table of 02_canopy_blups_heritability.R.
#
# Inputs
#   outputs/helios/helios_canopy_summary_SF.csv   Helios canopy outputs, one row per plot and date
#                                                 (SoyFACE)
#   outputs/helios/helios_canopy_summary_EF.csv   as above, Energy Farm
#   data/genetics/plot_line_key_SF.csv            plot identifier (Loc_ID) and BC3 line (BC3_ID) of
#                                                 the SoyFACE plots, from the companion study
#   data/genetics/plot_line_key_EF.csv            as above, Energy Farm
#
# Outputs
#   outputs/genetics/per_plot_traits.csv          one row per plot with its BC3 line and the
#                                                 seasonal summaries described below
#
# Columns of the output
#   Trait prefix  A = canopy A (umol CO2 m-2 s-1, Helios column A_umol_m2_s)
#                 F = fAPAR (Helios column frac_PAR_absorbed)
#                 L = canopy LUE, canopy A per unit absorbed PAR (mol CO2 per mol absorbed photons,
#                     Helios column inst_canopy_A_per_abs_PAR_umol_per_umol)
#   Suffix        _peak       = maximum over the retained dates
#                 _peak_fit   = height of the vertex of a quadratic fit against DAP (the maximum
#                               when the fit is not concave or its vertex lies outside the dates)
#                 _mean_repro = mean over the reproductive stage, 45 < DAP <= 85
#                 _AUC        = trapezoidal area under the seasonal curve (trait units x days)
#   n_DAP         number of dates retained after the LAI floor
#   Site, Location  site code (SF = SoyFACE, EF = Energy Farm). Location repeats Site for the models.
#   Spacing       row spacing code in inches (15 = 38-cm rows, 30 = 76-cm rows)
#   Leaf_type     leaflet type of the line (Broad or Narrow)
#
# Usage
#   Rscript code/5_genetics/01_per_plot_traits.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1; packages dplyr, readr, tidyr

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr)
})
set.seed(42); options(stringsAsFactors = FALSE)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

HELIOS_DIR <- file.path(ROOT, "outputs", "helios")
SF_KEY     <- file.path(ROOT, "data", "genetics", "plot_line_key_SF.csv")
EF_KEY     <- file.path(ROOT, "data", "genetics", "plot_line_key_EF.csv")
OUT_DIR    <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# The reproductive stage is 45 < DAP <= 85. Dates with LAI below 3 are dropped because they
# precede canopy closure.
DAP_VEG_MAX   <- 45
DAP_REPRO_MAX <- 85
LAI_FLOOR     <- 3

# ---- Seasonal summary functions ---------------------------------------------

# Height of the vertex of a quadratic fit of y on DAP. Returns NA with fewer than three distinct
# dates or a failed fit, and the observed maximum when the fit is concave-up or the vertex falls
# outside the sampled dates.
fit_quad_peak <- function(dap, y) {
  ok <- !is.na(dap) & !is.na(y); d <- dap[ok]; v <- y[ok]
  if (length(d) < 3 || length(unique(d)) < 3) return(NA)
  fit <- tryCatch(lm(v ~ d + I(d^2)), error = function(e) NULL)
  if (is.null(fit) || any(is.na(coef(fit)))) return(NA)
  cf <- coef(fit); a <- cf[1]; b <- cf[2]; c2 <- cf[3]
  if (is.na(c2) || c2 >= 0) return(max(v))
  dap_peak <- as.numeric(-b / (2 * c2))
  if (dap_peak < min(d) || dap_peak > max(d)) return(max(v))
  as.numeric(a - b^2 / (4 * c2))
}

# Trapezoidal integral of y over DAP, after sorting by DAP.
trapz <- function(x, y) {
  ok <- !is.na(x) & !is.na(y); x <- x[ok]; y <- y[ok]
  if (length(x) < 2) return(NA)
  ord <- order(x); x <- x[ord]; y <- y[ord]
  sum(diff(x) * (head(y, -1) + tail(y, -1)) / 2)
}

# Mean of y over the dates with lo < DAP <= hi.
stage_mean <- function(dap, y, lo, hi) {
  ok <- !is.na(dap) & !is.na(y) & dap > lo & dap <= hi
  if (sum(ok) == 0) return(NA)
  mean(y[ok])
}

# ---- Helios outputs and plot-to-line map ------------------------------------

# Combine the two sites and keep the dates with LAI >= 3.
cat("\n== Helios canopy outputs ==\n")
ef <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_EF.csv"), show_col_types = FALSE)
sf <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_SF.csv"), show_col_types = FALSE)
canopy <- bind_rows(ef, sf)
cat(sprintf("  EF rows: %d, SF rows: %d, combined: %d\n", nrow(ef), nrow(sf), nrow(canopy)))
cat(sprintf("  unique plots (Loc_ID): %d\n", n_distinct(canopy$Loc_ID)))
cat(sprintf("  rows with LAI_used >= %d: %d\n",
            LAI_FLOOR, sum(canopy$LAI_used >= LAI_FLOOR, na.rm = TRUE)))

canopy_filt <- canopy %>% filter(LAI_used >= LAI_FLOOR)
cat(sprintf("  unique plots after LAI floor: %d\n",
            n_distinct(canopy_filt$Loc_ID)))

# BC3 line of each plot, from the plot-to-line keys of the companion study (one row per plot).
load_map <- function(fp) read_csv(fp, show_col_types = FALSE) %>%
  select(any_of(c("Loc_ID", "BC3_ID"))) %>%
  distinct(Loc_ID, .keep_all = TRUE)
map_all <- bind_rows(load_map(SF_KEY), load_map(EF_KEY)) %>%
  distinct(Loc_ID, .keep_all = TRUE)
cat(sprintf("  plot-to-line map: %d plots with BC3_ID\n", nrow(map_all)))

# ---- Per-plot summary statistics --------------------------------------------
per_plot <- canopy_filt %>% arrange(Loc_ID, DAP) %>%
  group_by(Loc_ID, Site, Spacing, Leaf_type) %>%
  summarize(
    n_DAP = dplyr::n(),
    A_peak       = max(A_umol_m2_s, na.rm = TRUE),
    A_peak_fit   = fit_quad_peak(DAP, A_umol_m2_s),
    A_mean_repro = stage_mean(DAP, A_umol_m2_s, DAP_VEG_MAX, DAP_REPRO_MAX),
    A_AUC        = trapz(DAP, A_umol_m2_s),
    F_peak       = max(frac_PAR_absorbed, na.rm = TRUE),
    F_peak_fit   = fit_quad_peak(DAP, frac_PAR_absorbed),
    F_mean_repro = stage_mean(DAP, frac_PAR_absorbed, DAP_VEG_MAX, DAP_REPRO_MAX),
    F_AUC        = trapz(DAP, frac_PAR_absorbed),
    L_peak       = max(inst_canopy_A_per_abs_PAR_umol_per_umol, na.rm = TRUE),
    L_peak_fit   = fit_quad_peak(DAP, inst_canopy_A_per_abs_PAR_umol_per_umol),
    L_mean_repro = stage_mean(DAP, inst_canopy_A_per_abs_PAR_umol_per_umol, DAP_VEG_MAX, DAP_REPRO_MAX),
    L_AUC        = trapz(DAP, inst_canopy_A_per_abs_PAR_umol_per_umol),
    .groups = "drop"
  )

# A maximum over no values is -Inf. Infinite values are set to NA.
per_plot <- per_plot %>%
  mutate(across(where(is.numeric),
                ~ ifelse(is.infinite(.x), NA_real_, .x)))

cat(sprintf("\n== Per-plot summary ==\n"))
cat(sprintf("  plot rows: %d, unique plots: %d\n", nrow(per_plot), n_distinct(per_plot$Loc_ID)))

# Attach the BC3 line. Plots without a line in the map are dropped.
joined <- per_plot %>%
  inner_join(map_all %>% select(Loc_ID, BC3_ID), by = "Loc_ID") %>%
  mutate(Location = Site)

cat(sprintf("\n== Per-plot summary with BC3 line ==\n"))
cat(sprintf("  plots with a line: %d (of %d simulated plots)\n",
            nrow(joined), nrow(per_plot)))
cat(sprintf("  unique BC3 lines (BC3_ID): %d\n", n_distinct(joined$BC3_ID)))

cat("\n  plots per Site x Spacing x Leaf_type (Spacing 15 = 38-cm rows, 30 = 76-cm rows):\n")
print(joined %>% count(Site, Spacing, Leaf_type) %>%
        pivot_wider(names_from = Leaf_type, values_from = n, values_fill = 0) %>%
        arrange(Site, Spacing))

cat("\n  lines by number of environments (Site x Spacing):\n")
print(joined %>% mutate(Env = paste(Site, Spacing, sep = "-")) %>%
        group_by(BC3_ID) %>% summarize(n_envs = n_distinct(Env), .groups = "drop") %>%
        count(n_envs) %>% arrange(n_envs))

cat("\n== Trait distributions (per-plot summaries) ==\n")
for (trait in c("A_peak", "A_mean_repro", "A_AUC", "F_mean_repro", "L_mean_repro")) {
  v <- joined[[trait]]
  cat(sprintf("  %-15s  n=%4d  mean=%8.3f  sd=%6.3f  min=%8.3f  max=%8.3f\n",
              trait, sum(!is.na(v)),
              mean(v, na.rm = TRUE), sd(v, na.rm = TRUE),
              min(v, na.rm = TRUE), max(v, na.rm = TRUE)))
}

OUT_F <- file.path(OUT_DIR, "per_plot_traits.csv")
write_csv(joined, OUT_F)
cat(sprintf("\nWrote outputs/genetics/per_plot_traits.csv\n"))
cat(sprintf("  rows: %d, columns: %d\n", nrow(joined), ncol(joined)))
