# Measured (LITES) and modeled (Helios) light profiles at SoyFACE, plot by plot
#
# Purpose
#   Pairs the LITES interception profile of each BC3 near-isogenic line plot at SoyFACE (76-cm
#   rows, scans 20-22 August 2024, DAP 77-79) with the Helios simulation of the same plot on
#   DAP 76 (19 August 2024), matched by Loc_ID = SF_<Pass>_<Range>. Of the 33 scanned BC3 plots,
#   31 have a Helios run. For each pair and each of the eight sensor heights z, the script
#   computes the measured fIPAR(z) = 1 - PAR(z)/PAR(140 cm) (mean of the scans) and the modeled
#   fAPAR(z), the PAR absorbed by all sub-leaf elements at or above z divided by the PAR incident
#   on the simulated ground area. Their difference, R_sky(z) = fIPAR(z) - fAPAR(z), is the canopy
#   reflectance term of the PAR mass balance.
#   It also writes each plot's Helios cumulative fAPAR against cumulative LAI from the canopy top
#   (0.05-LAI bins). A Mitscherlich curve, f = A(1 - exp(-k L)), is fitted by nonlinear least
#   squares to the measured profile, which pairs LITES fIPAR with the SunScan cumulative LAI above
#   each of the six within-canopy heights in all 33 plots, and to the per-bin median of the Helios
#   curves in bins with at least five plots (Methods S1.9). The paired profiles are listed in
#   Table S7, the results are reported in the Results and Methods S1.9, and the curves are drawn
#   in Fig. 5A.
#
# Inputs
#   data/lites_sunscan/lites_sunscan_SF.xlsx                sheets plots, LITE and LAI
#   outputs/field_validation/lites_sunscan/plot_inventory.csv
#                                                            scanned plots with field position
#                                                            (01_plot_inventory.R)
#   outputs/helios/SF/per_task/canopy_summary_<Loc_ID>_DAP076.csv
#                                                            Helios canopy summary per run
#                                                            (simulation step)
#   outputs/helios/SF/per_leaf/<Loc_ID>_DAP076.csv           Helios output per sub-leaf element
#                                                            (height, area, absorbed PAR)
#
# Outputs
#   outputs/field_validation/lites_sunscan/lites_helios_profiles_by_height.csv
#       per plot and sensor height, the leaflet type, fIPAR, Helios fAPAR, Helios LAI and canopy
#       height, and gap = R_sky
#   outputs/field_validation/lites_sunscan/helios_depth_curves_DAP076.csv
#       per plot, Helios cumulative fAPAR against cumulative LAI from the canopy top (0.05 bins)
#   outputs/field_validation/lites_sunscan/lites_helios_depth_results.txt
#       paired plots, R_sky at the canopy floor, the gap at each sensor height, the two fits and
#       the gap between the fitted curves
#
# Usage
#   Rscript code/6_field_validation/lites_sunscan/03_lites_helios_pairing.R
#   (run from the package root)
#
# Requirements
#   R (4.6.1 used); package openxlsx

options(stringsAsFactors = FALSE, warn = 1)
suppressPackageStartupMessages(library(openxlsx))

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
XL      <- file.path(ROOT, "data", "lites_sunscan", "lites_sunscan_SF.xlsx")
OUT_DIR <- file.path(ROOT, "outputs", "field_validation", "lites_sunscan")
IN_INV  <- file.path(OUT_DIR, "plot_inventory.csv")
HT      <- file.path(ROOT, "outputs", "helios", "SF", "per_task")
HL      <- file.path(ROOT, "outputs", "helios", "SF", "per_leaf")
DAP  <- "DAP076"                                     # Helios run nearest the LITES scans
H_CM  <- c(H1 = 5, H2 = 20, H3 = 40, H4 = 60, H5 = 80, H6 = 100, H7 = 120, H8 = 140)  # sensor heights (cm)
REP_H <- c(`1` = 5, `2` = 20, `3` = 40, `4` = 60, `5` = 80, `6` = 100)              # SunScan heights (cm)

## ---- 1. LITES fIPAR profile per BC3 NIL plot (mean of 3 scans, H8 = incident PAR) ----
plots <- read.xlsx(XL, sheet = "plots"); plots$plot <- as.character(plots$ID)
inv   <- read.csv(IN_INV); inv$plot <- as.character(inv$plot)
inv$Loc_ID <- paste0("SF_", inv$Pass, "_", inv$Range)
lite <- read.xlsx(XL, sheet = "LITE"); lite$plot <- as.character(lite$plot)
lite <- lite[grepl("^[0-9]+$", lite$plot), ]          # BC3 NILs only (no LD11, donors or dark scans)
fip <- do.call(rbind, lapply(1:8, function(i) data.frame(
  plot = lite$plot, sensor = names(H_CM)[i], height_cm = unname(H_CM[i]),
  fIPAR = pmin(pmax(1 - lite[[paste0("PAR_Den_H", i, "_Avg")]] / lite$PAR_Den_H8_Avg, 0), 1))))
prof <- aggregate(fIPAR ~ plot + sensor + height_cm, fip, mean)
prof$Leaf_type <- plots$Leaf_type[match(prof$plot, plots$plot)]
prof <- prof[!is.na(prof$Leaf_type), ]
prof$Loc_ID <- inv$Loc_ID[match(prof$plot, inv$plot)]
pl <- unique(prof[c("plot", "Loc_ID", "Leaf_type")])
ip <- match(pl$plot, plots$plot); ii <- match(pl$plot, inv$plot)
stopifnot(!anyNA(pl$Loc_ID), !anyDuplicated(pl$Loc_ID), !anyDuplicated(pl$plot),
          all(plots$Range[ip] == inv$Range[ii]), all(plots$Pass[ip] == inv$Pass[ii]))

## ---- 2. Helios: fAPAR above each sensor height, and the cumulative curve ----
has <- file.exists(file.path(HT, sprintf("canopy_summary_%s_%s.csv", pl$Loc_ID, DAP))) &
       file.exists(file.path(HL, sprintf("%s_%s.csv", pl$Loc_ID, DAP)))
cat(sprintf("LITES BC3 plots: %d (Narrow %d, Broad %d); with a Helios %s run: %d; without: %s\n",
            nrow(pl), sum(pl$Leaf_type == "Narrow"), sum(pl$Leaf_type == "Broad"), DAP,
            sum(has), paste(pl$Loc_ID[!has], collapse = ", ")))
pp <- pl[has, ]
# The simulated ground area is the total leaf area divided by the simulated LAI, and incident PAR
# on that area is the per-ground-area incident PAR times the area. Sub-leaf elements are then
# ordered from the canopy top, and cumulative absorbed PAR is averaged within 0.05-LAI bins of
# cumulative LAI.
helios_one <- function(loc) {
  s <- read.csv(file.path(HT, sprintf("canopy_summary_%s_%s.csv", loc, DAP)))
  L <- read.csv(file.path(HL, sprintf("%s_%s.csv", loc, DAP)))
  ground_a <- sum(L$leaf_area_m2) / s$LAI_used[1]
  tot_inc  <- s$incident_PAR_W_m2[1] * ground_a
  absW     <- L$abs_PAR_W_m2 * L$leaf_area_m2
  z <- data.frame(Loc_ID = loc, sensor = names(H_CM), height_cm = unname(H_CM), height_m = unname(H_CM) / 100,
                  fAPAR = sapply(unname(H_CM) / 100, function(h) sum(absW[L$z_m >= h]) / tot_inc),
                  LAI_used = s$LAI_used[1], height_m_canopy = s$height_m_used[1],
                  frac_PAR_absorbed = s$frac_PAR_absorbed[1], helios_leaf = s$Leaf_type[1])
  o <- order(-L$z_m)                                    # top to bottom, ties kept in file order
  k <- round((cumsum(L$leaf_area_m2[o]) / ground_a) / 0.05)
  f <- tapply(cumsum(absW[o]) / tot_inc, k, mean)
  list(z = z, curve = data.frame(Loc_ID = loc, bin = as.integer(names(f)), fAPAR_cum = unname(f)))
}
hel  <- lapply(pp$Loc_ID, helios_one)
hz   <- do.call(rbind, lapply(hel, `[[`, "z"))
hcur <- do.call(rbind, lapply(hel, `[[`, "curve"))
hcur$LAI_above <- hcur$bin * 0.05
hcur$Leaf_type <- pp$Leaf_type[match(hcur$Loc_ID, pp$Loc_ID)]
lt_check <- unique(hz[c("Loc_ID", "helios_leaf")])
n_mismatch <- sum(lt_check$helios_leaf != pp$Leaf_type[match(lt_check$Loc_ID, pp$Loc_ID)])
cat("Leaflet type of the Helios run differs from the LITES plot:", n_mismatch, "\n")
stopifnot(n_mismatch == 0)

paired <- merge(prof[prof$Loc_ID %in% pp$Loc_ID, c("Loc_ID", "Leaf_type", "sensor", "height_cm", "fIPAR")],
                hz[c("Loc_ID", "sensor", "height_m", "fAPAR", "LAI_used", "height_m_canopy")], by = c("Loc_ID", "sensor"))
paired$gap <- paired$fIPAR - paired$fAPAR
paired <- paired[order(paired$Loc_ID, paired$height_cm), c("Loc_ID", "Leaf_type", "sensor", "height_cm", "height_m",
                                                           "fIPAR", "fAPAR", "LAI_used", "height_m_canopy", "gap")]
stopifnot(nrow(paired) == 8 * nrow(pp))

## ---- 3. Mitscherlich fits: Helios median curve and LITES against SunScan LAI ----
med <- aggregate(fAPAR_cum ~ bin, hcur, function(x) c(med = median(x), n = length(x)))
med <- data.frame(LAI_above = med$bin * 0.05, fAPAR_median = med$fAPAR_cum[, "med"], n = med$fAPAR_cum[, "n"])
med <- med[med$n >= 5, ]
hfit <- nls(fAPAR_median ~ A_max * (1 - exp(-k_h * LAI_above)), data = med, start = list(A_max = 0.9, k_h = 0.5))
hA <- unname(coef(hfit)["A_max"]); hk <- unname(coef(hfit)["k_h"])
lai <- read.xlsx(XL, sheet = "LAI"); lai$plot <- as.character(lai$plot)
sun <- aggregate(LAI ~ plot + rep, lai[grepl("^[0-9]+$", lai$plot), ], mean)
sun$height_cm <- unname(REP_H[as.character(sun$rep)])
pair <- merge(prof[prof$height_cm <= 100, c("plot", "height_cm", "fIPAR", "Leaf_type")], sun[c("plot", "height_cm", "LAI")],
              by = c("plot", "height_cm"))
lfit <- nls(fIPAR ~ Aa * (1 - exp(-kk * LAI)), data = pair, start = list(Aa = 0.98, kk = 0.6))
lA <- unname(coef(lfit)["Aa"]); lk <- unname(coef(lfit)["kk"])
cat(sprintf("LITES fit (%d plots): A = %.4f, k = %.4f | Helios fit (%d plots): A = %.4f, k = %.4f\n",
            length(unique(pair$plot)), lA, lk, nrow(pp), hA, hk))

## ---- 4. Results ----
fl <- paired[paired$sensor == "H1", ]
byh <- do.call(rbind, lapply(split(paired, paired$height_cm), function(d) data.frame(
  height_cm = d$height_cm[1], n = nrow(d), fIPAR = mean(d$fIPAR), fAPAR = mean(d$fAPAR),
  gap = mean(d$gap), gap_sd = sd(d$gap), positive = sum(d$gap > 0))))
g  <- c(0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8)
gg <- seq(0, 9, 0.01); gp <- lA * (1 - exp(-lk * gg)) - hA * (1 - exp(-hk * gg))
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
res <- c(
  "LITES (measured) vs Helios (modeled) light profiles, SoyFACE 76-cm rows",
  paste("LITES scans 20-22 August 2024 (DAP 77-79); Helios run", DAP, "(19 August 2024)"),
  "Generated by code/6_field_validation/lites_sunscan/03_lites_helios_pairing.R",
  "Pairing: each LITES plot with its own Helios run, Loc_ID = SF_<Pass>_<Range>", "",
  sprintf("Plots paired: %d (Narrow %d, Broad %d). LITES BC3 plots without a Helios run: %s",
          nrow(pp), sum(pp$Leaf_type == "Narrow"), sum(pp$Leaf_type == "Broad"), paste(pl$Loc_ID[!has], collapse = ", ")),
  "", "Canopy floor (5 cm): R_sky = LITES fIPAR - Helios fAPAR",
  sprintf("  all: mean %s, SD %s, positive in %d of %d plots; min %s (%s)", fmt(mean(fl$gap)), fmt(sd(fl$gap)),
          sum(fl$gap > 0), nrow(fl), fmt(min(fl$gap)), fl$Loc_ID[which.min(fl$gap)]),
  sprintf("  Narrow: mean %s (SD %s, n = %d); Broad: mean %s (SD %s, n = %d)",
          fmt(mean(fl$gap[fl$Leaf_type == "Narrow"])), fmt(sd(fl$gap[fl$Leaf_type == "Narrow"])), sum(fl$Leaf_type == "Narrow"),
          fmt(mean(fl$gap[fl$Leaf_type == "Broad"])), fmt(sd(fl$gap[fl$Leaf_type == "Broad"])), sum(fl$Leaf_type == "Broad")),
  sprintf("  whole-canopy Helios fAPAR instead of fAPAR above 5 cm: mean %s",
          fmt(mean(fl$fIPAR - hz$frac_PAR_absorbed[match(fl$Loc_ID, hz$Loc_ID)]))),
  "", "Gap by sensor height (mean over plots):",
  sprintf("  %3d cm: fIPAR %s  fAPAR %s  gap %s (SD %s), positive %d/%d", byh$height_cm, fmt(byh$fIPAR), fmt(byh$fAPAR),
          formatC(byh$gap, format = "f", digits = 3, flag = "+"), fmt(byh$gap_sd), byh$positive, byh$n),
  "", "Mitscherlich fits f = A(1 - exp(-k LAI_above)) to cumulative fraction vs cumulative LAI from the top:",
  sprintf("  LITES fIPAR vs SunScan LAI (%d BC3 plots): A = %s, k = %s", length(unique(pair$plot)), fmt(lA), fmt(lk)),
  sprintf("  Helios fAPAR (median of %d plots per 0.05-LAI bin, bins with n >= 5): A = %s, k = %s", nrow(pp), fmt(hA), fmt(hk)),
  "", "Fitted-curve gap (LITES - Helios) by cumulative LAI from the top:",
  sprintf("  LAI %3.1f: %s", g, formatC(lA * (1 - exp(-lk * g)) - hA * (1 - exp(-hk * g)), format = "f", digits = 3, flag = "+")),
  sprintf("  maximum %s at LAI %.2f; asymptote (A_LITES - A_Helios) %s", fmt(max(gp)), gg[which.max(gp)], fmt(lA - hA)))
cat(res, sep = "\n")

## ---- 5. Write the outputs ----
write.csv(paired, file.path(OUT_DIR, "lites_helios_profiles_by_height.csv"), row.names = FALSE, quote = FALSE)
write.csv(hcur[order(hcur$Loc_ID, hcur$bin), c("Loc_ID", "Leaf_type", "LAI_above", "fAPAR_cum")],
          file.path(OUT_DIR, "helios_depth_curves_DAP076.csv"), row.names = FALSE, quote = FALSE)
writeLines(res, file.path(OUT_DIR, "lites_helios_depth_results.txt"))
cat("Wrote lites_helios_profiles_by_height.csv, helios_depth_curves_DAP076.csv and",
    "lites_helios_depth_results.txt to outputs/field_validation/lites_sunscan.\n")
