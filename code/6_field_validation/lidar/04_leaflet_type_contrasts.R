# Broad- versus narrow-leaflet contrasts in LiDAR canopy structure at the Energy Farm
#
# Purpose
#   Summarizes the per-plot LiDAR metrics of the 224 BC3 near-isogenic line plots simulated with
#   Helios (56 Broad and 56 Narrow plots in each row spacing) and tests broad against narrow
#   leaflets with Welch two-sample t-tests. The plot is the unit of replication. The script
#   writes class means and SE by row spacing and flight date (Table S8), per-date Welch tests
#   (Table S8), the contrast at canopy closure in 76-cm rows (8 and 13 August 2024, DAP 70 and
#   75, values in the Results), and class-mean relative-height profiles (Fig. 5C).
#
# Inputs
#   outputs/field_validation/lidar/plot_metrics.csv                    per-plot metrics
#                                                                       (03_canopy_structure_metrics.R)
#   outputs/field_validation/lidar/plot_relative_height_profiles.csv   per-plot relative-height
#                                                                       profiles (same script)
#
# Outputs
#   outputs/field_validation/lidar/group_means_by_date.csv
#       mean and SE of each metric by row spacing (spacing = 15 or 30, the inch codes of the
#       38-cm and 76-cm rows), flight date and leaflet type
#   outputs/field_validation/lidar/welch_tests_by_date.csv
#       Welch test of broad against narrow for frac_top, frac_above07, rel_median, h99, lpi5 and
#       ht_p05, by row spacing and flight date
#   outputs/field_validation/lidar/canopy_closure_contrast_76cm.csv
#       Welch tests on the per-plot means of the 8 and 13 August flights in 76-cm rows
#   outputs/field_validation/lidar/group_relative_height_profiles.csv
#       mean and SE of the foliage share in each relative-height bin by row spacing, flight date
#       and leaflet type
#
# Usage
#   Rscript code/6_field_validation/lidar/04_leaflet_type_contrasts.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

options(stringsAsFactors = FALSE, warn = 1)

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
OUT_DIR <- file.path(ROOT, "outputs", "field_validation", "lidar")
IN_METRICS <- file.path(OUT_DIR, "plot_metrics.csv")
IN_PROFILE <- file.path(OUT_DIR, "plot_relative_height_profiles.csv")

DATE_ORDER <- c("June10","June11","June20","June27","July1","July5","July12","July15",
                "July18","July22","July26","July30","Aug8","Aug13","Aug22")
METRICS <- c("frac_top","frac_above07","rel_median","h99","lpi5","ht_p05")

M <- read.csv(IN_METRICS)
M$spacing <- as.character(M$spacing)
M$helios  <- M$helios %in% c(TRUE, "TRUE", "True")

## The analysis uses the plots simulated with Helios, which are the 224 BC3 NILs. The 31 check
## plots (the parents of the population) are not near-isogenic. Their point clouds are not in the
## package, so the metrics hold the simulated plots only and this filter keeps every row.
M <- M[M$helios, ]
study_plots <- unique(paste(M$block, M$plot))
cat(sprintf("BC3 NIL plots: %d plot x date rows, %d unique plots.\n",
            nrow(M), length(study_plots)))
se <- function(x){ x <- x[is.finite(x)]; if (length(x) < 1) return(NA_real_); sd(x)/sqrt(length(x)) }
mn <- function(x){ x <- x[is.finite(x)]; if (length(x) < 1) return(NA_real_); mean(x) }

# Welch two-sample t-test of broad against narrow. When both groups have zero variance (for
# example a date on which every plot has frac_top = 1), t.test cannot be computed, and the
# contrast is reported as null with P = 1.
welch <- function(b, n){
  b <- b[is.finite(b)]; n <- n[is.finite(n)]
  if (length(b) < 2 || length(n) < 2) return(NULL)
  if (sd(b) == 0 && sd(n) == 0)
    return(data.frame(nBroad=length(b), nNarrow=length(n), meanBroad=mean(b),
                      meanNarrow=mean(n), diff=mean(b)-mean(n), t=NA_real_, df=NA_real_, p=1))
  tt <- tryCatch(t.test(b, n), error=function(e) NULL); if (is.null(tt)) return(NULL)
  data.frame(nBroad=length(b), nNarrow=length(n),
             meanBroad=mean(b), meanNarrow=mean(n), diff=mean(b)-mean(n),
             t=unname(tt$statistic), df=unname(tt$parameter), p=tt$p.value)
}

## ---- Class means and SE by spacing x date x leaflet type ----
gm <- list()
for (sp in c("30","15")) for (dt in DATE_ORDER) for (lf in c("Broad","Narrow")) {
  s <- M[M$spacing==sp & M$date==dt & M$leaf_type==lf, ]
  if (nrow(s) == 0) next
  row <- data.frame(spacing=sp, date=dt, DAP=s$DAP[1], leaf=lf, n=nrow(s))
  for (mt in c(METRICS, "density_ptscm2","hmax","lpi10")) {
    row[[paste0(mt,"_mean")]] <- round(mn(s[[mt]]), 4)
    row[[paste0(mt,"_se")]]   <- round(se(s[[mt]]), 4)
  }
  gm[[length(gm)+1]] <- row
}
write.csv(do.call(rbind, gm), file.path(OUT_DIR, "group_means_by_date.csv"), row.names=FALSE)

## ---- Welch tests on each flight date ----
tst <- list()
for (sp in c("30","15")) for (dt in DATE_ORDER) {
  s <- M[M$spacing==sp & M$date==dt, ]; if (nrow(s)==0) next
  for (mt in METRICS) {
    w <- welch(s[[mt]][s$leaf_type=="Broad"], s[[mt]][s$leaf_type=="Narrow"]); if (is.null(w)) next
    tst[[length(tst)+1]] <- cbind(spacing=sp, date=dt, DAP=s$DAP[1], metric=mt,
      round(w[c("nBroad","nNarrow")],0),
      data.frame(meanBroad=round(w$meanBroad,4), meanNarrow=round(w$meanNarrow,4),
                 diff=round(w$diff,4), t=round(w$t,3), df=round(w$df,1), p=round(w$p,5)))
  }
}
write.csv(do.call(rbind, tst), file.path(OUT_DIR, "welch_tests_by_date.csv"), row.names=FALSE)

## ---- Canopy-closure contrast in 76-cm rows (8 and 13 August 2024, DAP 70 and 75) ----
## The light-redistribution mechanism predicts a structural difference between leaflet types once
## the canopy closes, so the test uses the two flights at canopy closure and peak leaf area,
## before canopy height declined at the 22 August flight. Each plot's metric is averaged over the
## two dates before the Welch test. The 38-cm rows are excluded because they lodged and closed
## from about DAP 57, after which the beams no longer reached the lower canopy (lpi5 near 0.0001,
## ht_p05 near 0.6 m) and frac_top saturated near 0.90 in both leaflet types.
CLOSURE_DATES <- c("Aug8","Aug13")
cl <- list()
wcl <- M[M$spacing=="30" & M$date %in% CLOSURE_DATES, ]
for (mt in METRICS) {
  ag <- aggregate(wcl[[mt]], list(plot=wcl$plot, leaf=wcl$leaf_type),
                  function(x) mean(x[is.finite(x)]))
  w <- welch(ag$x[ag$leaf=="Broad"], ag$x[ag$leaf=="Narrow"]); if (is.null(w)) next
  cl[[length(cl)+1]] <- data.frame(spacing="30", window="peak_Aug8-13", metric=mt,
    nBroad=w$nBroad, nNarrow=w$nNarrow,
    meanBroad=round(w$meanBroad,4), meanNarrow=round(w$meanNarrow,4),
    diff=round(w$diff,4), t=round(w$t,3), df=round(w$df,1), p=signif(w$p,6))
}
closure <- do.call(rbind, cl)
write.csv(closure, file.path(OUT_DIR, "canopy_closure_contrast_76cm.csv"), row.names=FALSE)

## ---- Class-mean relative-height profiles ----
R <- read.csv(IN_PROFILE)
R$spacing <- as.character(R$spacing)
R <- R[paste(R$block, R$plot) %in% study_plots, ]           # same 224-plot set
agg_m <- aggregate(share ~ spacing+date+leaf_type+relbin, R, mn)
agg_s <- aggregate(share ~ spacing+date+leaf_type+relbin, R, se)
agg_n <- aggregate(share ~ spacing+date+leaf_type+relbin, R, length)
dap_lk <- setNames(R$DAP, paste(R$spacing, R$date))
bands <- data.frame(spacing=agg_m$spacing, date=agg_m$date,
                    DAP=as.integer(dap_lk[paste(agg_m$spacing, agg_m$date)]),
                    leaf=agg_m$leaf_type, relbin=agg_m$relbin, nplots=agg_n$share,
                    share_mean=round(agg_m$share,5), share_se=round(agg_s$share,5))
bands <- bands[order(bands$spacing, match(bands$date, DATE_ORDER), bands$leaf, bands$relbin), ]
write.csv(bands, file.path(OUT_DIR, "group_relative_height_profiles.csv"), row.names=FALSE)

cat("Wrote group_means_by_date, welch_tests_by_date, canopy_closure_contrast_76cm and",
    "group_relative_height_profiles to outputs/field_validation/lidar.\n\n")
cat("=== Canopy-closure contrast, 76-cm rows (8 and 13 August 2024, DAP 70 and 75), plot means ===\n")
print(closure[, c("metric","nBroad","nNarrow","meanBroad","meanNarrow","diff","t","df","p")], row.names=FALSE)
