# Sensitivity of the architectural residual to the longwave and NIR choices of the 1D model
#
# Purpose
#   Compares the run of the one-dimensional sun-shade model used in the paper with two
#   sensitivity runs. Each changes one choice that Helios does not define for a
#   one-dimensional canopy (Methods S1.6). In the longwave-off run the net longwave exchange
#   of leaves is zero. In the NIR-equals-PAR run incident NIR equals incident PAR instead of
#   station shortwave minus PAR. The architectural residual of each run is computed as for
#   Table S19 and Fig 4B. Canopy A is averaged per location x row spacing x leaflet type x DAP
#   and then over the 10 dates, the gap is narrow minus broad, and the residual is the Helios
#   gap minus the 1D gap. The script stops unless the three runs share the same 5,299
#   plot-dates and Helios values, the published run gives the residuals of the text (+1.75 to
#   +2.17 umol CO2 m-2 s-1), and the largest change rounds to 0.07 or less, the bound stated
#   in Methods S1.6.
#
# Inputs (all written by 01_sun_shade_model.py)
#   outputs/one_dimensional_model/helios_vs_1D_per_plot.csv                 published run
#   outputs/one_dimensional_model/helios_vs_1D_per_plot_longwave_off.csv    longwave off
#   outputs/one_dimensional_model/helios_vs_1D_per_plot_nir_equals_par.csv  NIR = PAR
#
# Outputs
#   outputs/one_dimensional_model/sensitivity_longwave_nir_summary.txt   residual of each run
#       and location x row spacing, its change from the published run, and the r and RMSE of
#       Helios against 1D canopy A for each run
#
# Usage
#   Rscript code/4_one_dimensional_model/02_sensitivity_longwave_nir.R   (from the package root)
#
# Requirements
#   R (4.6.1 used), base R only

options(stringsAsFactors = FALSE, warn = 1)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")
DIR  <- file.path(ROOT, "outputs", "one_dimensional_model")
RUNS <- c(published      = "helios_vs_1D_per_plot.csv",
          longwave_off   = "helios_vs_1D_per_plot_longwave_off.csv",
          nir_equals_par = "helios_vs_1D_per_plot_nir_equals_par.csv")
OUT  <- file.path(DIR, "sensitivity_longwave_nir_summary.txt")

## ---- 1. the three runs share plot-dates and Helios values ----
d   <- lapply(RUNS, function(f) read.csv(file.path(DIR, f)))
key <- function(x) paste(x$Loc_ID, x$DAP)
p   <- d$published
stopifnot(nrow(p) == 5299, !anyDuplicated(key(p)))
for (v in names(RUNS)[-1]) {
  k <- match(key(p), key(d[[v]]))
  stopifnot(nrow(d[[v]]) == 5299, !anyNA(k), max(abs(d[[v]]$A_umol_m2_s[k] - p$A_umol_m2_s)) < 1e-9)
}

## ---- 2. residual per location x row spacing combination, as for Table S19 ----
# Means per Site x Spacing x Leaf_type x DAP, then over dates. Spacing codes 15 and 30 are the
# 38-cm and 76-cm rows.
resid <- function(x) {
  cd <- aggregate(cbind(H = A_umol_m2_s, D = canopy_A_DePuryEB) ~ Site + Spacing + Leaf_type + DAP, x, mean)
  cm <- aggregate(cbind(H, D) ~ Site + Spacing + Leaf_type, cd, mean)
  n  <- cm[cm$Leaf_type == "Narrow", ]; b <- cm[cm$Leaf_type == "Broad", ]
  stopifnot(nrow(n) == 4, identical(paste(n$Site, n$Spacing), paste(b$Site, b$Spacing)))
  v <- setNames((n$H - b$H) - (n$D - b$D), paste(n$Site, c(`15` = "38 cm", `30` = "76 cm")[as.character(n$Spacing)]))
  v[order(names(v))]
}
res <- t(sapply(d, resid))
chg <- sweep(res[-1, , drop = FALSE], 2, res["published", ])
big <- max(abs(chg)); w <- which(abs(chg) == big, arr.ind = TRUE)[1, ]
fit <- sapply(d, function(x) c(r = cor(x$A_umol_m2_s, x$canopy_A_DePuryEB),
                               RMSE = sqrt(mean((x$A_umol_m2_s - x$canopy_A_DePuryEB)^2))))
stopifnot(identical(sprintf("%.2f", range(res["published", ])), c("1.75", "2.17")), round(big, 2) <= 0.07)

## ---- 3. summary ----
line <- function(lab, v) paste0(formatC(lab, width = -15), paste(sprintf("%+9.3f", v), collapse = " "))
txt <- c("Sensitivity of the architectural residual to the 1D longwave and NIR choices (Methods S1.6)",
         "Residual = Helios narrow-minus-broad gap - 1D gap, \u00b5mol CO2 m-2 s-1 (as in Table S19 and Fig 4B)",
         "",
         paste0(formatC("", width = -15), paste(formatC(colnames(res), width = 9), collapse = " ")),
         vapply(rownames(res), function(n) line(n, res[n, ]), ""),
         "",
         "Change from the published run",
         vapply(rownames(chg), function(n) line(n, chg[n, ]), ""),
         "",
         sprintf("Largest change: %.3f (%s, %s), %.2f when rounded; Methods S1.6 states <= 0.07",
                 big, rownames(chg)[w[1]], colnames(chg)[w[2]], big),
         "",
         "Helios vs 1D canopy A over the 5,299 plot-dates",
         vapply(colnames(fit), function(n) sprintf("%-15s r = %.4f, RMSE = %.3f", n, fit["r", n], fit["RMSE", n]), ""))
con <- file(OUT, open = "w", encoding = "UTF-8"); writeLines(txt, con); close(con)
cat(txt, sep = "\n")
cat("\nWrote:", OUT, "\n")
