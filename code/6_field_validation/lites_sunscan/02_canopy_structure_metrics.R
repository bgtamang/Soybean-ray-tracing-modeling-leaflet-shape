# Per-plot light-profile and leaf-area-profile metrics from LITES and SunScan at SoyFACE
#
# Purpose
#   Computes canopy-structure metrics for the 39 plots of the SoyFACE field validation (76-cm
#   rows, 20-22 August 2024, DAP 77-79). They are 22 narrow-leaflet and 11 broad-leaflet BC3
#   near-isogenic lines and six plots of the broad-leaflet recurrent parent LD11-2170, which are
#   pooled with the broad-leaflet lines. Each plot's canopy height is its own manual plant height
#   on 22 August 2024 (DAP 79), matched by Loc_ID = SF_<Pass>_<Range>, and is used to express the
#   metrics on a relative-height scale (Methods S1.9).
#     The LITES light profile is fIPAR(z) = 1 - PAR(z)/PAR(140 cm), the mean of the scans. The
#       ratio of fIPAR at 80 cm (fixed height) or at 0.8 of canopy height (relative height) to
#       fIPAR at the canopy floor (5 cm) gives light top-heaviness, and h50 is the height above
#       which half of the floor interception occurs, in cm and as a fraction of canopy height.
#     The SunScan leaf-area profile is the cumulative LAI above each of six heights (5-100 cm),
#       the mean of the two pole positions. Total LAI is the value at 5 cm. The leaf-area
#       fraction above 0.7 of canopy height and the leaf-area median height (the height above
#       which half of the total LAI lies, as a fraction of canopy height) describe its vertical
#       distribution.
#   Narrow and broad canopies are compared with Welch two-sample t-tests for the per-plot Beer
#   extinction coefficient k, total LAI and leaf-area median height, with LD11-2170 pooled with the
#   broad-leaflet NILs, for the broad-leaflet NILs alone, and for LD11-2170 against the
#   broad-leaflet NILs (Results, Discussion, Methods S1.8). The metrics are listed in Table S21.
#
# Inputs
#   data/lites_sunscan/lites_sunscan_SF.xlsx   sheets plots (plot sheet), LITE (PAR at eight
#                                               sensor heights per scan), LAI (SunScan cumulative LAI
#                                               per plot, pole position and height) and k (per-plot
#                                               Beer fit, fIPAR = 1 - exp(-k LAI))
#   data/field/SF/plant_height_per_plot.csv     SoyFACE manual plant heights (height_August22, inches)
#   outputs/field_validation/lites_sunscan/plot_inventory.csv
#                                               scanned plots with class and field position
#                                               (01_plot_inventory.R)
#
# Outputs
#   outputs/field_validation/lites_sunscan/light_profile_metrics.csv
#       per plot, the leaflet class (shape), is_LD11, canopy height H_m (m), top_heavy_abs =
#       fIPAR(80 cm)/fIPAR(5 cm), top_heavy_rel = fIPAR(0.8 H)/fIPAR(5 cm), h50_cm and h50_rel
#   outputs/field_validation/lites_sunscan/leaf_area_profile_metrics.csv
#       per plot, shape, is_LD11, H_m, total_LAI, frac_LA_upper (leaf-area fraction above 0.7 H)
#       and LA_halfheight_rel (leaf-area median height / H)
#   outputs/field_validation/lites_sunscan/leaflet_type_tests.txt
#       Welch tests of Beer k, total LAI and leaf-area median height between leaflet types
#
# Usage
#   Rscript code/6_field_validation/lites_sunscan/02_canopy_structure_metrics.R
#   (run from the package root)
#
# Requirements
#   R (4.6.1 used); package openxlsx

options(stringsAsFactors = FALSE, warn = 1)
suppressPackageStartupMessages(library(openxlsx))

ROOT      <- Sys.getenv("PACKAGE_ROOT", unset = ".")
XL        <- file.path(ROOT, "data", "lites_sunscan", "lites_sunscan_SF.xlsx")
IN_HEIGHT <- file.path(ROOT, "data", "field", "SF", "plant_height_per_plot.csv")
OUT_DIR   <- file.path(ROOT, "outputs", "field_validation", "lites_sunscan")
IN_INV    <- file.path(OUT_DIR, "plot_inventory.csv")
H_CM  <- c(H1 = 5, H2 = 20, H3 = 40, H4 = 60, H5 = 80, H6 = 100, H7 = 120, H8 = 140)  # sensor heights (cm)
REP_H <- c(`1` = 5, `2` = 20, `3` = 40, `4` = 60, `5` = 80, `6` = 100)              # SunScan heights (cm)
INCH  <- 0.0254

## ---- Plots and canopy heights ----
## The validation plots are the BC3 NILs (numeric plot names) and the LD11-2170 plots of the
## inventory, in inventory order. Each plot takes the manual height of its own field position.
plots <- read.xlsx(XL, sheet = "plots"); plots$plot <- as.character(plots$ID)
inv   <- read.csv(IN_INV); inv$plot <- as.character(inv$plot)
inv$Loc_ID <- paste0("SF_", inv$Pass, "_", inv$Range)
hr <- read.csv(IN_HEIGHT); hr$H_m <- suppressWarnings(as.numeric(hr$height_August22)) * INCH

meta <- data.frame(plot = inv$plot[inv$class %in% c("BC3_NIL_numeric", "PARENT_LD11_recurrent")])
stopifnot(!anyDuplicated(meta$plot))
meta$is_LD11   <- grepl("^LD11", meta$plot)
meta$Leaf_type <- plots$Leaf_type[match(meta$plot, plots$plot)]
meta$shape     <- ifelse(meta$Leaf_type == "Narrow", "Narrow", "Broad")
meta$Loc_ID    <- inv$Loc_ID[match(meta$plot, inv$plot)]
meta$H_plot    <- hr$H_m[match(meta$Loc_ID, hr$Loc_ID)]
stopifnot(!anyNA(meta$Loc_ID), !anyNA(meta$H_plot),
          all(hr$Spacing[match(meta$Loc_ID, hr$Loc_ID)] == 30))

## ---- LITES fIPAR profile per plot (mean of scans, sensor H8 at 140 cm = incident PAR) ----
lite <- read.xlsx(XL, sheet = "LITE"); lite$plot <- as.character(lite$plot)
lite <- lite[lite$plot %in% meta$plot, ]
fip <- do.call(rbind, lapply(1:8, function(i) data.frame(
  plot = lite$plot, height_cm = unname(H_CM[i]),
  fIPAR = pmin(pmax(1 - lite[[paste0("PAR_Den_H", i, "_Avg")]] / lite$PAR_Den_H8_Avg, 0), 1))))
prof <- aggregate(fIPAR ~ plot + height_cm, fip, mean)

## ---- SunScan cumulative LAI above each height (mean of the two pole positions) ----
lai <- read.xlsx(XL, sheet = "LAI"); lai$plot <- as.character(lai$plot)
sun <- aggregate(LAI ~ plot + rep, lai[lai$plot %in% meta$plot, ], mean)
sun$height_cm <- unname(REP_H[as.character(sun$rep)])

# Height at which a cumulative profile first reaches the target value, scanning down from the
# top and interpolating linearly between measurement heights.
half_height <- function(h, y, tgt) {
  o <- order(-h); h <- h[o]; y <- y[o]
  for (i in seq_len(length(h) - 1))
    if (y[i] < tgt && y[i + 1] >= tgt) return(h[i] + (h[i + 1] - h[i]) * (tgt - y[i]) / (y[i + 1] - y[i]))
  NA_real_
}
# Light top-heaviness and half-interception height of one plot (H = canopy height, m).
light_metrics <- function(d, H) {
  d <- d[order(d$height_cm), ]; fl <- d$fIPAR[d$height_cm == 5]; Hc <- H * 100
  h50 <- half_height(d$height_cm, d$fIPAR, 0.5 * fl)
  c(H_m = H, top_heavy_abs = d$fIPAR[d$height_cm == 80] / fl,
    top_heavy_rel = approx(d$height_cm, d$fIPAR, xout = 0.8 * Hc, rule = 2)$y / fl,
    h50_cm = h50, h50_rel = h50 / Hc)
}
# SunScan leaf-area structure of one plot (H = canopy height, m).
leaf_area_metrics <- function(d, H) {
  d <- d[order(d$height_cm), ]; tot <- d$LAI[d$height_cm == 5]; Hc <- H * 100
  c(H_m = H, total_LAI = tot,
    frac_LA_upper = approx(d$height_cm, d$LAI, xout = 0.7 * Hc, rule = 2)$y / tot,
    LA_halfheight_rel = half_height(d$height_cm, d$LAI, 0.5 * tot) / Hc)
}
build <- function(H) {
  id <- meta[c("plot", "shape", "is_LD11")]
  lt <- t(sapply(seq_len(nrow(meta)), function(i) light_metrics(prof[prof$plot == meta$plot[i], ], H[i])))
  la <- t(sapply(seq_len(nrow(meta)), function(i) leaf_area_metrics(sun[sun$plot == meta$plot[i], ], H[i])))
  list(light = data.frame(id, lt), leaf_area = data.frame(id, la))
}
cols_light     <- c("H_m", "top_heavy_abs", "top_heavy_rel", "h50_cm", "h50_rel")
cols_leaf_area <- c("H_m", "total_LAI", "frac_LA_upper", "LA_halfheight_rel")

metrics <- build(meta$H_plot)

## ---- Tests between leaflet types (Welch two-sample t-tests, R default) ----
k <- read.xlsx(XL, sheet = "k"); k$plot <- as.character(k$plot)
k <- k[k$plot %in% meta$plot, ]
stopifnot(nrow(k) == nrow(meta), !anyDuplicated(k$plot),
          all((k$shape == meta$shape[match(k$plot, meta$plot)])[!grepl("^LD11", k$plot)]))
vals <- data.frame(plot = meta$plot, shape = meta$shape, is_LD11 = meta$is_LD11,
                   k = k$k[match(meta$plot, k$plot)],
                   total_LAI = metrics$leaf_area$total_LAI, LA_median = metrics$leaf_area$LA_halfheight_rel)
grp <- list(Narrow = vals$shape == "Narrow", BroadPooled = vals$shape == "Broad",
            BroadNIL = vals$shape == "Broad" & !vals$is_LD11, LD11 = vals$is_LD11)
row_t <- function(v, a, b, lab) {
  x <- vals[[v]][grp[[a]]]; y <- vals[[v]][grp[[b]]]; p <- t.test(x, y)$p.value
  sprintf("%-34s %-22s %8.4f (n=%2d) %8.4f (n=%2d)   P = %.4f", lab, paste(a, "vs", b),
          mean(x), length(x), mean(y), length(y), p)
}
out <- c(
  "LITES and SunScan field validation, SoyFACE 76-cm rows, 20-22 August 2024 (DAP 77-79)",
  "Generated by code/6_field_validation/lites_sunscan/02_canopy_structure_metrics.R",
  sprintf("Plots: %d Narrow NIL, %d Broad NIL, %d LD11-2170 (recurrent parent, pooled into Broad)",
          sum(grp$Narrow), sum(grp$BroadNIL), sum(grp$LD11)),
  "Canopy height: each plot's own manual height on 22 August 2024 (Loc_ID = SF_<Pass>_<Range>)",
  "Welch two-sample t-tests (R t.test default)", "",
  row_t("k", "Narrow", "BroadPooled", "Beer k"),
  row_t("k", "Narrow", "BroadNIL", "Beer k"),
  row_t("k", "LD11", "BroadNIL", "Beer k"),
  row_t("total_LAI", "Narrow", "BroadPooled", "SunScan total LAI"),
  row_t("total_LAI", "Narrow", "BroadNIL", "SunScan total LAI"),
  row_t("total_LAI", "LD11", "BroadNIL", "SunScan total LAI"),
  row_t("LA_median", "Narrow", "BroadPooled", "Leaf-area median height / H"),
  row_t("LA_median", "Narrow", "BroadNIL", "Leaf-area median height / H"),
  row_t("LA_median", "LD11", "BroadNIL", "Leaf-area median height / H"))
cat(out, sep = "\n")

## ---- Write the metrics and the tests ----
write.csv(metrics$light[c("plot", "shape", "is_LD11", cols_light)],
          file.path(OUT_DIR, "light_profile_metrics.csv"), row.names = FALSE, quote = FALSE)
write.csv(metrics$leaf_area[c("plot", "shape", "is_LD11", cols_leaf_area)],
          file.path(OUT_DIR, "leaf_area_profile_metrics.csv"), row.names = FALSE, quote = FALSE)
writeLines(out, file.path(OUT_DIR, "leaflet_type_tests.txt"))
cat("Wrote light_profile_metrics.csv, leaf_area_profile_metrics.csv and leaflet_type_tests.txt",
    "to outputs/field_validation/lites_sunscan.\n")
