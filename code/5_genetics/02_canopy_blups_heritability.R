# Line BLUPs and Cullis heritability of the Helios canopy traits
#
# Purpose
#   Fits linear mixed models to the per-plot canopy summaries of 01_per_plot_traits.R and extracts
#   best linear unbiased predictors (BLUPs) of the BC3 lines. Broad-sense heritability follows
#   Cullis et al. (2006). Ten traits are fitted with two models (below). The paper uses the
#   all-lines model for A_mean_repro (Canopy A) and L_mean_repro (Canopy LUE). Its BLUPs are the
#   phenotypes of the association scans (Fig. 7 and Tables S17 and S20), and its heritabilities
#   are given in Fig. 7A and Table S18.
#
# Models (lme4, REML). The label of each model in the model column of the heritability table is
# given in brackets.
#   single-site [single-loc]
#       y ~ Spacing + (1|BC3_ID), fitted to each site separately
#   all-lines [BOTH-all-lines]
#       y ~ Location + Spacing + (1|BC3_ID), both sites and all lines (the model of the paper)
#   The BLUP of a line is the model intercept plus the line random effect. The intercept is the
#   fitted value at the first level of each fixed effect (Energy Farm for Location, 38-cm rows
#   for Spacing).
#
# Heritability columns
#   H2_Cullis    1 - mean(PEV) / var_geno, bounded to [0, 1], where PEV is the prediction error
#                variance (conditional variance) of the line random effects
#   H2_lineMean  var_geno / (var_geno + var_gxe / E_eff + var_resid / E_eff)
#   var_geno, var_gxe, var_resid  variances of the line, line x environment and residual terms.
#                var_gxe is 0 here because neither model has a line x environment term. The
#                column is kept to match the heritability table of the Leaflet L:W model.
#   E_eff        harmonic mean number of environments per line, with the row spacings as the
#                environments in both models
#   n_obs, n_lines  number of plots and lines in the fit
#   dataset      SF or EF for the single-site fits, BOTH for the fit to both sites
#
# Trait codes
#   The ten traits are A_peak, A_peak_fit, A_mean_repro, A_AUC, F_peak, F_peak_fit, F_mean_repro,
#   L_peak, L_peak_fit and L_mean_repro. A_, F_ and L_ = canopy A, fAPAR and canopy LUE. _peak,
#   _peak_fit, _mean_repro and _AUC are the per-plot seasonal maximum, quadratic-fit peak,
#   reproductive-stage mean (45 < DAP <= 85) and area under the seasonal curve, as defined in
#   01_per_plot_traits.R.
#
# Inputs
#   outputs/genetics/per_plot_traits.csv      per-plot canopy summaries (01_per_plot_traits.R)
#
# Outputs
#   outputs/genetics/heritability_canopy.csv  heritability and variance components, one row per
#                                             dataset, model and trait
#   outputs/genetics/blups_canopy.csv         line BLUPs of the ten traits from the all-lines model
#                                             (BC3_ID is the line number)
#
# Usage
#   Rscript code/5_genetics/02_canopy_blups_heritability.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1; packages lme4, dplyr, readr, tidyr

suppressPackageStartupMessages({
  library(lme4); library(dplyr); library(readr); library(tidyr)
})
set.seed(42); options(stringsAsFactors = FALSE)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

INPUT_F <- file.path(ROOT, "outputs", "genetics", "per_plot_traits.csv")
OUT_DIR <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- Mixed-model fitter ------------------------------------------------------
harmonic_mean <- function(x) {
  x <- x[x > 0 & !is.na(x)]
  if (length(x) == 0) return(NA)
  1 / mean(1 / x)
}

# Fits one model by REML and returns the line BLUPs (intercept plus random effect), their
# prediction error variances, the variance components and both heritabilities.
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

# Single-site model. Spacing is dropped when only one spacing is present.
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

# All-lines model across both sites, without a line x environment term.
compute_blup_all <- function(df, value_col) {
  df <- df %>% filter(!is.na(.data[[value_col]]), !is.na(Spacing), Spacing != "NA") %>%
    mutate(BC3_ID = as.character(BC3_ID),
           Spacing = as.factor(as.character(Spacing)),
           Location = as.factor(Location), Env = Spacing)
  if (nrow(df) < 10 || n_distinct(df$Location) < 2) return(NULL)
  formula_str <- paste(value_col, "~ Location + Spacing + (1|BC3_ID)")
  fit_blup(df, formula_str)
}

# ---- Per-plot summaries ------------------------------------------------------
joined <- read_csv(INPUT_F, show_col_types = FALSE)
cat(sprintf("Loaded %d per-plot rows, %d unique BC3 lines\n",
            nrow(joined), n_distinct(joined$BC3_ID)))

responses <- c("A_peak","A_peak_fit","A_mean_repro","A_AUC",
               "F_peak","F_peak_fit","F_mean_repro",
               "L_peak","L_peak_fit","L_mean_repro")

collect_blups <- function(r, dataset_name, model_kind, resp) {
  if (is.null(r)) return(NULL)
  data.frame(BC3_ID   = names(r$blups),
             response = resp,
             dataset  = dataset_name,
             model    = model_kind,
             BLUP     = unname(r$blups),
             PEV      = unname(r$pev),
             stringsAsFactors = FALSE)
}

# Fits every trait with one model and returns the heritability rows and the line BLUPs.
run_one <- function(df, dataset_name, model_kind, responses) {
  cat(sprintf("\n-- %s | %s | n_plots=%d | n_lines=%d --\n",
              dataset_name, model_kind, nrow(df), n_distinct(df$BC3_ID)))
  summary_out <- data.frame()
  blup_out    <- data.frame()
  for (resp in responses) {
    r <- if (model_kind == "single-loc") {
      compute_blup_site(df, resp)
    } else if (model_kind == "BOTH-all-lines") {
      compute_blup_all(df, resp)
    }
    if (is.null(r)) {
      cat(sprintf("   %-14s  FIT FAILED\n", resp)); next
    }
    cat(sprintf("   %-14s  H2_Cullis=%.3f  var_g=%.4g  var_e=%.4g  n_lines_fit=%d\n",
                resp, r$h2_cullis, r$var_geno, r$var_resid, r$n_lines))
    summary_out <- rbind(summary_out, data.frame(
      dataset = dataset_name, model = model_kind, response = resp,
      formula = r$formula, n_obs = r$n_obs, n_lines = r$n_lines,
      H2_Cullis = r$h2_cullis, H2_lineMean = r$h2_line_mean,
      var_geno = r$var_geno, var_gxe = r$var_gxe, var_resid = r$var_resid,
      E_eff = r$E_eff, stringsAsFactors = FALSE
    ))
    blup_out <- rbind(blup_out, collect_blups(r, dataset_name, model_kind, resp))
  }
  list(summary = summary_out, blups = blup_out)
}

# ---- Fit all models ----------------------------------------------------------
all_summary <- data.frame()

cat("\n========== BLUPs and Cullis heritability by site and model ==========\n")
res_sf        <- run_one(joined %>% filter(Site == "SF"), "SF",   "single-loc",     responses)
res_ef        <- run_one(joined %>% filter(Site == "EF"), "EF",   "single-loc",     responses)
res_all_lines <- run_one(joined,                          "BOTH", "BOTH-all-lines", responses)

all_summary <- rbind(res_sf$summary, res_ef$summary, res_all_lines$summary)

write_csv(all_summary, file.path(OUT_DIR, "heritability_canopy.csv"))

# Line BLUPs in wide form, one column per trait.
write_blups_wide <- function(blups_long, out_path) {
  if (nrow(blups_long) == 0) return(invisible(NULL))
  wide <- blups_long %>%
    select(BC3_ID, response, BLUP) %>%
    pivot_wider(names_from = response, values_from = BLUP)
  write_csv(wide, out_path)
  cat(sprintf("  wrote outputs/genetics/%s  (%d lines x %d traits)\n",
              basename(out_path), nrow(wide), ncol(wide) - 1))
}

cat("\n========== Writing line BLUPs (all-lines model) ==========\n")
write_blups_wide(res_all_lines$blups, file.path(OUT_DIR, "blups_canopy.csv"))

cat("\n========== Cullis heritability (trait x site and model) ==========\n")
wide <- all_summary %>%
  mutate(col = paste(dataset, model, sep = " | ")) %>%
  select(response, col, H2_Cullis) %>%
  pivot_wider(names_from = col, values_from = H2_Cullis)
print(wide)

cat("\nWrote outputs/genetics/heritability_canopy.csv and outputs/genetics/blups_canopy.csv\n")
