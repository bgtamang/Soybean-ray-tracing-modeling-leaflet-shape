# Line BLUPs and Cullis heritability of grain yield per unit peak LAI
#
# Purpose
#   Computes yield per LAI for each plot as grain yield divided by the plot's peak leaf area index
#   and fits it with the mixed models and the Cullis et al. (2006) heritability of
#   02_canopy_blups_heritability.R. Plots of broad- and narrow-leaflet lines with both yield and
#   peak LAI are used. The paper uses the all-lines model (column yield_per_LAI_BOTH_all_lines).
#   Its BLUPs are the Yield per LAI phenotype of the association scan (Fig. 7 and Tables S17 and
#   S20), and its heritability is given in Fig. 7A and Table S18.
#
# Models (lme4, REML), as defined in 02_canopy_blups_heritability.R. Each fit is a dataset, and
# the dataset name and model label are listed in brackets.
#   single-site  [SF and EF, single-loc]            y ~ Spacing + (1|BC3_ID), one site at a time
#   all-lines    [BOTH_all_lines, BOTH-all-lines]   y ~ Location + Spacing + (1|BC3_ID), both
#                                                   sites and all lines (the paper's model)
#   The BLUP of a line is the model intercept plus the line random effect. Heritability columns
#   are defined in 02_canopy_blups_heritability.R.
#
# Inputs
#   data/canopy_inputs_base/canopy_inputs_base_SF.csv  per-plot, per-date inputs of the SoyFACE
#        plots. Read for Loc_ID, Location, Spacing, Leaf_type, grain yield (yield_bu_ac, bu ac-1)
#        and peak LAI (max_LAI_m2_m2), which repeat on every date of a plot. Plots enter the
#        models in the order of this file.
#   data/canopy_inputs_base/canopy_inputs_base_EF.csv  as above, Energy Farm
#   data/genetics/plot_line_key_SF.csv  plot identifier and BC3 line of the SoyFACE plots
#                                       (companion study, as in 01_per_plot_traits.R)
#   data/genetics/plot_line_key_EF.csv  as above, Energy Farm
#
# Outputs
#   outputs/genetics/heritability_yield_per_lai.csv  heritability and variance components, one
#                                                    row per dataset (dataset column SF, EF or
#                                                    BOTH, model column as above)
#   outputs/genetics/blups_yield_per_lai.csv         line BLUPs (BC3_ID is the line number) in
#                                                    the columns yield_per_LAI_SF,
#                                                    yield_per_LAI_EF and
#                                                    yield_per_LAI_BOTH_all_lines
#
# Trait code
#   yield_per_LAI = yield_bu_ac / max_LAI_m2_m2, in bu ac-1 per unit LAI (1 bu ac-1 = 67.25 kg ha-1).
#   max_LAI_m2_m2 is the maximum of a LOWESS fit to the plot's LAI time course, spatially adjusted
#   as in the companion study (peak_LAI in Table S6).
#
# Usage
#   Rscript code/5_genetics/03_yield_per_lai_blups_heritability.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1; packages lme4, dplyr, readr, tidyr

suppressPackageStartupMessages({
  library(lme4); library(dplyr); library(readr); library(tidyr)
})
set.seed(42); options(stringsAsFactors = FALSE)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

SF_PER_PLOT <- file.path(ROOT, "data", "canopy_inputs_base", "canopy_inputs_base_SF.csv")
EF_PER_PLOT <- file.path(ROOT, "data", "canopy_inputs_base", "canopy_inputs_base_EF.csv")
SF_KEY  <- file.path(ROOT, "data", "genetics", "plot_line_key_SF.csv")
EF_KEY  <- file.path(ROOT, "data", "genetics", "plot_line_key_EF.csv")
OUT_DIR <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- Mixed-model fitter (as in 02_canopy_blups_heritability.R) ---------------
harmonic_mean <- function(x) {
  x <- x[x > 0 & !is.na(x)]
  if (length(x) == 0) return(NA)
  1 / mean(1 / x)
}

fit_blup <- function(df, formula_str) {
  fit <- tryCatch(suppressWarnings(
    lmer(as.formula(formula_str), data = df, REML = TRUE,
         control = lmerControl(optimizer = "bobyqa",
                               optCtrl = list(maxfun = 1e5),
                               check.conv.singular = "ignore",
                               check.nobs.vs.nlev  = "ignore",
                               check.nobs.vs.nRE   = "ignore"))),
    error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  re <- ranef(fit, condVar = TRUE)$BC3_ID
  intercept <- fixef(fit)[1]
  blups <- intercept + re[, 1]; names(blups) <- rownames(re)
  pev_array <- attr(re, "postVar")
  pev <- if (!is.null(pev_array))
    setNames(as.numeric(pev_array[1, 1, ]), rownames(re))
  else setNames(rep(NA, length(blups)), names(blups))
  vc <- as.data.frame(VarCorr(fit))
  var_geno  <- vc$vcov[vc$grp == "BC3_ID"]; if (length(var_geno) == 0)  var_geno  <- 0
  var_gxe   <- if ("BC3_ID:Env" %in% vc$grp) vc$vcov[vc$grp == "BC3_ID:Env"] else 0
  var_resid <- vc$vcov[vc$grp == "Residual"]; if (length(var_resid) == 0) var_resid <- 0
  E_eff <- if ("Env" %in% names(df))
    harmonic_mean((df %>% group_by(BC3_ID) %>%
                     summarize(n_env = n_distinct(Env), .groups = "drop"))$n_env) else 1
  h2_cullis <- if (var_geno > 0 && !all(is.na(pev)))
    max(0, min(1, 1 - mean(pev, na.rm = TRUE) / var_geno)) else NA
  h2_line_mean <- if (var_geno > 0)
    var_geno / (var_geno + var_gxe / E_eff + var_resid / E_eff) else 0
  list(h2_cullis = h2_cullis, h2_line_mean = h2_line_mean,
       var_geno = var_geno, var_gxe = var_gxe, var_resid = var_resid,
       E_eff = E_eff, formula = formula_str,
       n_obs = nrow(df), n_lines = length(blups), blups = blups, pev = pev)
}

compute_blup_site <- function(df, value_col) {
  df <- df %>% filter(!is.na(.data[[value_col]]), !is.na(Spacing), Spacing != "NA") %>%
    mutate(BC3_ID = as.character(BC3_ID), Spacing = as.factor(as.character(Spacing)))
  if (nrow(df) < 10) return(NULL)
  n_spacings <- n_distinct(df$Spacing)
  df <- df %>% mutate(Env = Spacing)
  formula_str <- if (n_spacings > 1)
    paste(value_col, "~ Spacing + (1|BC3_ID)") else
    paste(value_col, "~ 1 + (1|BC3_ID)")
  fit_blup(df, formula_str)
}

compute_blup_all <- function(df, value_col) {
  df <- df %>% filter(!is.na(.data[[value_col]]), !is.na(Spacing), Spacing != "NA") %>%
    mutate(BC3_ID = as.character(BC3_ID),
           Spacing = as.factor(as.character(Spacing)),
           Location = as.factor(Location), Env = Spacing)
  if (nrow(df) < 10 || n_distinct(df$Location) < 2) return(NULL)
  formula_str <- paste(value_col, "~ Location + Spacing + (1|BC3_ID)")
  fit_blup(df, formula_str)
}

# ---- Per-plot yield per LAI ---------------------------------------------------
# Yield and peak LAI repeat on every date of a plot, so the first row of each plot is kept.
cat("Reading the per-plot inputs and computing yield_per_LAI...\n")
keep_cols <- c("Loc_ID", "Location", "Spacing", "Leaf_type",
               "yield_bu_ac", "max_LAI_m2_m2")
sf <- read_csv(SF_PER_PLOT, show_col_types = FALSE)[, keep_cols]
ef <- read_csv(EF_PER_PLOT, show_col_types = FALSE)[, keep_cols]

plots <- bind_rows(sf, ef) %>%
  distinct(Loc_ID, .keep_all = TRUE) %>%
  filter(Leaf_type %in% c("Broad", "Narrow"),
         !is.na(yield_bu_ac), !is.na(max_LAI_m2_m2)) %>%
  mutate(yield_per_LAI = yield_bu_ac / max_LAI_m2_m2)

cat(sprintf("  NIL plots with yield and LAI: %d\n", nrow(plots)))

# Attach the BC3 line of each plot from the plot-to-line keys of the companion study.
load_map <- function(fp) read_csv(fp, show_col_types = FALSE) %>%
  select(any_of(c("Loc_ID", "BC3_ID"))) %>%
  distinct(Loc_ID, .keep_all = TRUE)
map_all <- bind_rows(load_map(SF_KEY), load_map(EF_KEY)) %>%
  distinct(Loc_ID, .keep_all = TRUE)

joined <- plots %>%
  inner_join(map_all, by = "Loc_ID") %>%
  mutate(Site = Location)

cat(sprintf("  plots with a BC3 line: %d, unique lines: %d\n",
            nrow(joined), n_distinct(joined$BC3_ID)))

# ---- BLUPs and Cullis heritability for the three datasets ---------------------
datasets <- list(
  list(name = "SF",              df = joined %>% filter(Site == "SF"), model_kind = "single-loc"),
  list(name = "EF",              df = joined %>% filter(Site == "EF"), model_kind = "single-loc"),
  list(name = "BOTH_all_lines",  df = joined,                          model_kind = "BOTH-all-lines")
)

cat("\n========== yield_per_LAI BLUPs and Cullis heritability ==========\n")

h2_summary <- data.frame()
all_blups <- data.frame(BC3_ID = sort(unique(joined$BC3_ID)),
                        stringsAsFactors = FALSE)

for (ds in datasets) {
  cat(sprintf("\n-- %s | %s | n_plots=%d | n_lines=%d --\n",
              ds$name, ds$model_kind, nrow(ds$df), n_distinct(ds$df$BC3_ID)))
  r <- if (ds$model_kind == "single-loc") {
         compute_blup_site(ds$df, "yield_per_LAI")
       } else {
         compute_blup_all(ds$df, "yield_per_LAI")
       }
  if (is.null(r)) {
    cat("   FIT FAILED\n"); next
  }
  cat(sprintf("   yield_per_LAI  H2_Cullis=%.3f  var_g=%.4g  var_e=%.4g  n_lines_fit=%d\n",
              r$h2_cullis, r$var_geno, r$var_resid, r$n_lines))

  h2_summary <- rbind(h2_summary, data.frame(
    dataset = ifelse(ds$name %in% c("SF","EF"), ds$name, "BOTH"),
    model = ds$model_kind,
    response = "yield_per_LAI",
    formula = r$formula, n_obs = r$n_obs, n_lines = r$n_lines,
    H2_Cullis = r$h2_cullis, H2_lineMean = r$h2_line_mean,
    var_geno = r$var_geno, var_gxe = r$var_gxe, var_resid = r$var_resid,
    E_eff = r$E_eff,
    stringsAsFactors = FALSE
  ))

  # Add this dataset's BLUPs as a column of the line table.
  bdf <- data.frame(BC3_ID = names(r$blups), blup = unname(r$blups),
                    stringsAsFactors = FALSE)
  names(bdf)[2] <- paste0("yield_per_LAI_", ds$name)
  all_blups <- merge(all_blups, bdf, by = "BC3_ID", all.x = TRUE)
}

# ---- Save outputs -------------------------------------------------------------
write.csv(h2_summary,
          file.path(OUT_DIR, "heritability_yield_per_lai.csv"),
          row.names = FALSE)
write.csv(all_blups,
          file.path(OUT_DIR, "blups_yield_per_lai.csv"),
          row.names = FALSE)

cat("\n========== Heritability summary ==========\n")
print(h2_summary %>% select(dataset, model, n_lines, H2_Cullis, var_geno, var_resid))

cat("\nWrote outputs/genetics/heritability_yield_per_lai.csv and outputs/genetics/blups_yield_per_lai.csv\n")
