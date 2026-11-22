# Flag A-Ci points for removal by automatic quality rules
#
# Purpose
#   Builds one row per A-Ci curve from the combined LI-6800 records and lists the points to
#   remove under fixed quality rules, together with the reason for each. Six curves with
#   nonstandard records (an aborted start, an aborted curve, a trailing extra point, two warm-up
#   readings without a leaf and one plant measured twice) receive fixed curve-level decisions.
#   A curve is kept when at least six points remain, the minimum for a Farquhar-von
#   Caemmerer-Berry fit. The resulting table, with the review decisions, is the point-exclusion
#   table data/leaf/aci_curve_curation.csv that 03_fit_aci_curves.R reads. This script writes its
#   flags to outputs/ so that the table in data/ is never overwritten. The fits behind the Rd25
#   values in Table S14 use these exclusions.
#
#   The quality rules for each point are listed below.
#     Stable = 0 (LI-6800 stability criteria not met)        removed
#     Stable = 1 or 2 (criteria partly or fully met)          kept
#     Ci < -100 or Ci > 1500 umol mol-1                       removed (outside the chamber range)
#     Qin < 1500 umol m-2 s-1                                 removed (light not saturating)
#   Points with Stable = 1 are kept because A typically settles before stomatal conductance meets
#   its criterion. At SoyFACE the stability criteria were set stricter, so Stable = 1 was common in
#   otherwise normal records, and requiring Stable = 2 would leave many curves with too few points
#   to fit.
#
# Inputs
#   outputs/leaf_inputs/aci_curves_combined_<cell>.csv   combined records (01_combine_aci_curves.R)
#
# Outputs
#   outputs/leaf_inputs/aci_curve_flags_auto.csv   one row per curve with the columns cell,
#                                                  curve_uid, machine, Pass, Range, n_rows_orig,
#                                                  keep, points_to_remove, split_at_obs,
#                                                  n_rows_after, auto_flag_reason, user_notes
#
# Usage
#   Rscript code/1_leaf_inputs/aci_respiration/02_flag_aci_points.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

ROOT       <- Sys.getenv("PACKAGE_ROOT", unset = ".")
IN_DIR     <- file.path(ROOT, "outputs", "leaf_inputs")
OUT_DIR    <- file.path(ROOT, "outputs", "leaf_inputs")
CELL_NAMES <- c("SF_15", "SF_30", "EF_15", "EF_30")

# -------- Thresholds --------
CI_MIN  <- -100   # Ci below this is a computation artifact
CI_MAX  <- 1500   # Ci above this exceeds the physical chamber range
QIN_MIN <- 1500   # Qin below this is not saturating light
KEEP_STABLE <- c(1, 2)  # drop only Stable = 0, keep Stable = 1 (partly met) and 2 (fully met)

# -------- Fixed decisions for nonstandard curves --------
# These curves were checked record by record. The decision replaces the automatic rules. A curve
# measured twice on the same plant is split at the given observation, and the fitting step gives
# the first and the second measurement their own curve identifiers.
HARD_OVERRIDES <- list(
    # SF_15
    "Ripe14__1__24" = list(keep = "Y", points_to_remove = "15,16,17", split_at_obs = "",
                            notes = "Aborted prelude (rows obs 15-17); keep last 14"),
    "Ripe3__1__2"   = list(keep = "N", points_to_remove = "",         split_at_obs = "",
                            notes = "Aborted curve, only 3 points; drop entirely"),
    # SF_30
    "Ains3__1__18"  = list(keep = "Y", points_to_remove = "85",       split_at_obs = "",
                            notes = "Trailing extra 400 ppm point; drop obs 85"),
    # EF_15
    "Ripe15__NA__NA" = list(keep = "N", points_to_remove = "",        split_at_obs = "",
                            notes = "Warm-up reading, no plant attached"),
    # EF_30
    "Ripe15__6__1"  = list(keep = "Y", points_to_remove = "",         split_at_obs = "70",
                            notes = "Operator re-measured same plant; split at obs 70 into _v1/_v2"),
    "Ripe3__NA__NA" = list(keep = "N", points_to_remove = "",         split_at_obs = "",
                            notes = "Warm-up reading, no plant attached")
)

# -------- Build the flag rows of one cell --------
process_cell <- function(cell_name) {
    fp <- file.path(IN_DIR, sprintf("aci_curves_combined_%s.csv", cell_name))
    if (!file.exists(fp)) {
        cat(sprintf("[%s] combined records not found, cell skipped.\n", cell_name)); return(NULL)
    }
    df <- read.csv(fp, stringsAsFactors = FALSE, check.names = FALSE)

    rows <- list()
    uids <- unique(df$curve_uid)
    cat(sprintf("\n[%s] %d curves\n", cell_name, length(uids)))

    for (uid in uids) {
        sub <- df[df$curve_uid == uid, , drop = FALSE]
        sub <- sub[order(sub$obs), ]
        n_orig <- nrow(sub)
        machine <- unique(sub$machine)[1]
        pass    <- unique(sub$Pass)[1]
        range_  <- unique(sub$Range)[1]

        # Curves with a fixed decision
        if (uid %in% names(HARD_OVERRIDES)) {
            ov <- HARD_OVERRIDES[[uid]]
            # n_rows_after counts the points left after removal and ignores a split.
            n_after <- if (ov$keep == "N") 0 else {
                drop_n <- if (nchar(ov$points_to_remove) > 0)
                            length(strsplit(ov$points_to_remove, ",")[[1]]) else 0
                n_orig - drop_n
            }
            rows[[length(rows) + 1]] <- data.frame(
                cell = cell_name, curve_uid = uid, machine = machine,
                Pass = pass, Range = range_, n_rows_orig = n_orig,
                keep = ov$keep, points_to_remove = ov$points_to_remove,
                split_at_obs = ov$split_at_obs,
                n_rows_after = n_after,
                auto_flag_reason = sprintf("HARD_OVERRIDE: %s", ov$notes),
                user_notes = "",
                stringsAsFactors = FALSE
            )
            next
        }

        # Point rules
        flagged_obs <- integer(0)
        reasons <- character(0)
        for (i in seq_len(n_orig)) {
            r <- sub[i, ]
            why <- character(0)
            if (!is.na(r$Stable) && !(r$Stable %in% KEEP_STABLE)) {
                why <- c(why, sprintf("Stable=%s", r$Stable))
            }
            if (!is.na(r$Ci) && (r$Ci < CI_MIN || r$Ci > CI_MAX)) {
                why <- c(why, sprintf("Ci=%.1f", r$Ci))
            }
            if ("Qin" %in% colnames(sub) && !is.na(r$Qin) && r$Qin < QIN_MIN) {
                why <- c(why, sprintf("Qin=%.0f", r$Qin))
            }
            if (length(why) > 0) {
                flagged_obs <- c(flagged_obs, r$obs)
                reasons     <- c(reasons, sprintf("obs%s:%s", r$obs, paste(why, collapse = "+")))
            }
        }

        n_after <- n_orig - length(flagged_obs)
        keep_flag <- if (n_after >= 6) "Y" else "N"  # at least 6 points are needed for an FvCB fit

        points_to_remove_str <- if (length(flagged_obs) > 0)
                                   paste(flagged_obs, collapse = ",") else ""

        reason_str <- if (length(reasons) > 0) paste(reasons, collapse = "; ") else "clean"

        rows[[length(rows) + 1]] <- data.frame(
            cell = cell_name, curve_uid = uid, machine = machine,
            Pass = pass, Range = range_, n_rows_orig = n_orig,
            keep = keep_flag, points_to_remove = points_to_remove_str,
            split_at_obs = "",
            n_rows_after = n_after,
            auto_flag_reason = reason_str,
            user_notes = "",
            stringsAsFactors = FALSE
        )
    }

    out <- do.call(rbind, rows)

    # Summary
    n_keep <- sum(out$keep == "Y")
    n_drop <- sum(out$keep == "N")
    n_points_dropped <- sum(sapply(strsplit(out$points_to_remove, ","), length))
    cat(sprintf("  kept curves=%d, dropped curves=%d, points flagged=%d\n",
                n_keep, n_drop, n_points_dropped))

    # Curves that lose many points
    pct_lost <- 1 - (out$n_rows_after / out$n_rows_orig)
    n_50pct  <- sum(pct_lost > 0.5 & out$n_rows_orig > 1, na.rm = TRUE)
    n_under_8 <- sum(out$n_rows_after < 8 & out$n_rows_orig > 1, na.rm = TRUE)
    if (n_50pct > 0)  cat(sprintf("  curves losing more than 50%% of their points: %d\n", n_50pct))
    if (n_under_8 > 0) cat(sprintf("  curves with fewer than 8 points left: %d\n", n_under_8))

    out
}

# -------- Driver --------
all_rows <- list()
for (cell in CELL_NAMES) {
    res <- process_cell(cell)
    if (!is.null(res)) all_rows[[cell]] <- res
}

curate <- do.call(rbind, all_rows)
out_csv <- file.path(OUT_DIR, "aci_curve_flags_auto.csv")
write.csv(curate, out_csv, row.names = FALSE)

cat(sprintf("\nWrote %s\n", basename(out_csv)))
cat(sprintf("Total: %d curves in 4 cells\n", nrow(curate)))
cat(sprintf("  keep=Y: %d  |  keep=N: %d  |  split curves: %d\n",
            sum(curate$keep == "Y"), sum(curate$keep == "N"),
            sum(nchar(curate$split_at_obs) > 0)))
cat(sprintf("  points flagged for removal: %d\n",
            sum(sapply(strsplit(curate$points_to_remove, ","), length))))

# The ten curves with the most flagged points
flagged_count <- sapply(strsplit(curate$points_to_remove, ","), length)
ord <- order(flagged_count, decreasing = TRUE)
cat("\nCurves with the most flagged points\n")
for (i in head(ord, 10)) {
    if (flagged_count[i] == 0) break
    cat(sprintf("  %-8s %-30s n_orig=%d -> n_after=%d  reason: %s\n",
                curate$cell[i], curate$curve_uid[i],
                curate$n_rows_orig[i], curate$n_rows_after[i],
                substr(curate$auto_flag_reason[i], 1, 80)))
}

cat("\nThe fitting step reads the point-exclusion table data/leaf/aci_curve_curation.csv,\n")
cat("which holds these flags together with the review decisions.\n")
