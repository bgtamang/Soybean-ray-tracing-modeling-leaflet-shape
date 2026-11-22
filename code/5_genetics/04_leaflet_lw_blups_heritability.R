# Line BLUPs and Cullis heritability of leaflet length-to-maximum-width ratio
#
# Purpose
#   Fits the Leaflet L:W model of Methods S1.7 to the per-plot leaflet length-to-maximum-width
#   ratio from the companion study (Tamang et al., 2026) and extracts line BLUPs and the Cullis
#   et al. (2006) heritability. The ratio was spatially adjusted in the companion study with a MAD
#   Type II adjustment (Lin & Poushinsky, 1985), applied to the ratio as a trait in its own right.
#   It is therefore used as supplied and is not recomputed from the adjusted length and width.
#   The model is fitted to all entries, including the checks, and the BLUPs of the BC3 lines are
#   the Leaflet L:W phenotype of the association scan (Fig. 7 and Tables S17 and S20). The
#   heritability is given in Fig. 7A and Table S18.
#
# Model (lme4, REML)
#   lr ~ 1 + Location*Spacing + gen_fix + (1|Gen) + (1|Gen:Env)
#   Gen is the entry (BC3 line or check, column BC3_ID) and Env the location x row spacing
#   combination. gen_fix gives the primary check (the recurrent parent LD11-2170) its own fixed
#   level, with "none" for every other entry. Entry types come from the Line column, which marks
#   the BC3 test lines, the primary check, the two secondary checks (the donor parents PI547745
#   and PI612713A) and one fill plot. Line BLUPs are the random effects of Gen, zero-centered
#   (no intercept added).
#
# Heritability columns
#   As in 02_canopy_blups_heritability.R, with E_eff the harmonic mean number of location x row
#   spacing combinations per entry. n_lines counts all fitted entries, checks included.
#
# Inputs
#   data/genetics/leaflet_shape_per_plot.csv   one row per plot of the companion study, with the
#                                              location, entry type (Line), entry (BC3_ID), row
#                                              spacing code and spatially adjusted leaflet
#                                              length-to-maximum-width ratio (lr)
#
# Outputs
#   outputs/genetics/heritability_leaflet_lw.csv  heritability and variance components. The
#                                                 dataset column is BOTH (both sites) and the
#                                                 model column is BOTH-all-entries (both sites,
#                                                 all entries including the checks).
#   outputs/genetics/blups_leaflet_lw.csv         line BLUPs of the BC3 lines (column leaf_ratio_LR)
#
# Trait codes
#   lr             per-plot leaflet length divided by maximum width, spatially adjusted (input)
#   leaf_ratio_LR  zero-centered line BLUP of lr (Leaflet L:W, named LW_ratio_maxwidth in Tables
#                  S17, S18 and S20)
#
# Usage
#   Rscript code/5_genetics/04_leaflet_lw_blups_heritability.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1; packages lme4, dplyr, readr, tidyr

suppressPackageStartupMessages({
  library(lme4); library(dplyr); library(readr); library(tidyr)
})
set.seed(42); options(stringsAsFactors = FALSE)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

PHENO_FILE <- file.path(ROOT, "data", "genetics", "leaflet_shape_per_plot.csv")
OUT_DIR    <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

harmonic_mean <- function(x) {
  x <- x[x > 0 & !is.na(x)]
  if (length(x) == 0) return(NA)
  1 / mean(1 / x)
}

# ---- Per-plot leaflet shape -------------------------------------------------
cat("Reading the per-plot leaflet shape table...\n")
dat_raw <- read_csv(PHENO_FILE, show_col_types = FALSE)
cat(sprintf("  rows: %d   columns: %d\n", nrow(dat_raw), ncol(dat_raw)))
cat(sprintf("  rows with non-NA lr: %d\n", sum(!is.na(dat_raw$lr))))

# Model frame: environment, entry, entry type and the primary-check fixed term.
dat <- dat_raw %>%
  filter(!is.na(lr), !is.na(Location), !is.na(Spacing), !is.na(BC3_ID)) %>%
  mutate(
    Location = as.factor(Location),
    Spacing  = as.factor(as.character(Spacing)),
    Env      = interaction(Location, Spacing, drop = TRUE),
    Line     = as.character(Line),
    Gen      = as.factor(BC3_ID),
    .line_lc = tolower(Line),
    type = case_when(
      grepl("bc3",       .line_lc) ~ "test",
      grepl("primary",   .line_lc) ~ "check_primary",
      grepl("secondary", .line_lc) ~ "check_secondary",
      TRUE                         ~ "unknown"
    ),
    gen_fix = factor(ifelse(type == "check_primary",
                            as.character(Gen), "none"))
  )

cat(sprintf("\nFrame for fit: %d rows | %d unique entries | %d environments\n",
            nrow(dat), n_distinct(dat$Gen), n_distinct(dat$Env)))
cat("Rows by entry type\n")
print(table(dat$type, useNA = "ifany"))

# ---- Fit the Leaflet L:W model ----------------------------------------------
formula_str <- "lr ~ 1 + Location*Spacing + gen_fix + (1|Gen) + (1|Gen:Env)"
cat(sprintf("\nFitting: %s\n", formula_str))

fit <- lmer(as.formula(formula_str), data = dat, REML = TRUE,
            control = lmerControl(optimizer = "bobyqa",
                                  optCtrl = list(maxfun = 1e6),
                                  check.conv.singular = "ignore",
                                  check.nobs.vs.nlev  = "ignore",
                                  check.nobs.vs.nRE   = "ignore"))

# Line BLUPs are the random effects of Gen, without the intercept.
re <- ranef(fit, condVar = TRUE)$Gen
blups <- as.numeric(re[, 1]); names(blups) <- rownames(re)

pev_array <- attr(re, "postVar")
pev <- if (!is.null(pev_array)) as.numeric(pev_array[1, 1, ]) else rep(NA, length(blups))

vc <- as.data.frame(VarCorr(fit))
var_geno  <- vc$vcov[vc$grp == "Gen"];        if (length(var_geno) == 0)  var_geno  <- 0
var_gxe   <- vc$vcov[vc$grp == "Gen:Env"];    if (length(var_gxe)  == 0)  var_gxe   <- 0
var_resid <- vc$vcov[vc$grp == "Residual"];   if (length(var_resid)== 0)  var_resid <- 0

env_per_gen <- dat %>% group_by(Gen) %>%
  summarize(n_env = n_distinct(Env), .groups = "drop")
E_eff <- harmonic_mean(env_per_gen$n_env)

h2_cullis <- if (var_geno > 0 && !all(is.na(pev)))
  max(0, min(1, 1 - mean(pev, na.rm = TRUE) / var_geno)) else NA
h2_line_mean <- if (var_geno > 0)
  var_geno / (var_geno + var_gxe / E_eff + var_resid / E_eff) else 0

cat(sprintf("\n========== Leaflet L:W (leaf_ratio_LR) ==========\n"))
cat(sprintf("  n_obs     = %d\n", nrow(dat)))
cat(sprintf("  n_lines   = %d\n", length(blups)))
cat(sprintf("  E_eff     = %.2f\n", E_eff))
cat(sprintf("  var_geno  = %.4g\n", var_geno))
cat(sprintf("  var_gxe   = %.4g\n", var_gxe))
cat(sprintf("  var_resid = %.4g\n", var_resid))
cat(sprintf("  H2_Cullis = %.3f\n", h2_cullis))
cat(sprintf("  H2_lineMean = %.3f\n", h2_line_mean))

# ---- Save outputs -----------------------------------------------------------
# Heritability summary. dataset BOTH = both sites. model BOTH-all-entries = the model fitted to
# both sites and all entries, checks included.
h2_summary <- data.frame(
  dataset = "BOTH", model = "BOTH-all-entries",
  response = "leaf_ratio_LR", formula = formula_str,
  n_obs = nrow(dat), n_lines = length(blups),
  H2_Cullis = h2_cullis, H2_lineMean = h2_line_mean,
  var_geno = var_geno, var_gxe = var_gxe, var_resid = var_resid,
  E_eff = E_eff, stringsAsFactors = FALSE
)
write.csv(h2_summary, file.path(OUT_DIR, "heritability_leaflet_lw.csv"),
          row.names = FALSE)

# Line BLUPs. Only the BC3 lines are kept, because the check entries are not in the genotype
# matrix.
blup_df <- data.frame(
  BC3_ID = names(blups),
  leaf_ratio_LR = unname(blups),
  stringsAsFactors = FALSE
)
blup_df <- blup_df %>%
  filter(grepl("^BC3_", BC3_ID))
cat(sprintf("\nBLUPs of BC3 lines: %d lines\n", nrow(blup_df)))

write.csv(blup_df, file.path(OUT_DIR, "blups_leaflet_lw.csv"),
          row.names = FALSE)

cat("\nWrote outputs/genetics/blups_leaflet_lw.csv\n")
cat("Wrote outputs/genetics/heritability_leaflet_lw.csv\n")
