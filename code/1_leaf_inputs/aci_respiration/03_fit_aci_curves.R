# Fit the Farquhar-von Caemmerer-Berry model to each A-Ci curve with PhotoGEA
#
# Purpose
#   Fits each curated A-Ci curve with the whole-curve method of PhotoGEA (fit_c3_aci) and returns
#   per-plant estimates at 25 °C of Vcmax, J, Tp and the respiration in the light (RL, used as
#   dark respiration Rd25 in Helios). Each workbook is processed on its own so that differences
#   in the user-defined constants between workbooks cannot drop the Range column. For each
#   workbook the script keeps the curves marked keep = Y in the point-exclusion table, removes the
#   listed points, and splits the one curve measured twice on the same plant. Mesophyll
#   conductance is set to infinity (Cc = Ci), temperature responses follow Bernacchi et al.
#   (2001), and atmospheric CO2 is 420 ppm. RL_at_25 is constrained to be non-negative, so no fit
#   returns a negative respiration rate. Only Rd25 from these fits enters the simulations, as
#   combination means (05_rd25_combination_means.R, Table S14). The Vcmax and J estimates are not
#   simulation inputs. The per-plot Vcmax25, Jmax25 and Tp25 used by Helios come from
#   data/canopy_inputs_base/ and pass through this pipeline unchanged.
#
#   The default PhotoGEA optimizer (differential evolution, DEoptim, 200 iterations) is random,
#   and the analysis set no random seed. A refit therefore gives slightly different estimates,
#   and for a few curves with a flat likelihood surface clearly different Rd25 values. In a full
#   refit the eight Rd25 combination means changed by -4.2% to +5.4%. The as-run fits used for
#   the simulations are outputs/leaf_inputs/aci_fits_per_plant.csv, shipped with the package.
#   This script writes its fits to aci_fits_per_plant_refit.csv so that the as-run fits are kept.
#   05_rd25_combination_means.R uses a refit only when the environment variable ACI_FITS points
#   to it.
#
# Inputs
#   data/leaf/aci_curves/<cell>/<instrument>.xlsx   recalculated LI-6800 workbooks
#   data/leaf/aci_curve_curation.csv                point exclusions (automatic flags of
#                                                   02_flag_aci_points.R and review decisions)
#
# Outputs
#   outputs/leaf_inputs/aci_fits_per_plant_refit.csv   one row per fitted curve with cell,
#                                                      curve_uid, curve_uid_orig, machine, Pass,
#                                                      Range, n_points_used, Vcmax_at_25,
#                                                      J_at_25, RL_at_25, Tp_at_25, PhotoGEA
#                                                      trust flags, RMSE, fit_status
#
# Usage
#   Rscript code/1_leaf_inputs/aci_respiration/03_fit_aci_curves.R   (run from the package root)
#   Cell codes given as arguments limit the run to those cells, for example "... EF_30".
#
# Requirements
#   R (4.6.1 used); package PhotoGEA (1.4.0 used)

suppressPackageStartupMessages({
    library(PhotoGEA)
})

ROOT        <- Sys.getenv("PACKAGE_ROOT", unset = ".")
EVAL_DIR    <- file.path(ROOT, "data", "leaf", "aci_curves")
CURATE_PATH <- file.path(ROOT, "data", "leaf", "aci_curve_curation.csv")
OUT_DIR     <- file.path(ROOT, "outputs", "leaf_inputs")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
CELL_NAMES  <- c("SF_15", "SF_30", "EF_15", "EF_30")

# Ripe15 at the Energy Farm 76-cm rows stores the field position Range as "Plot".
COL_REMAPS <- list(EF_30 = list(Ripe15 = c(Plot = "Range")))

# -------- Read the point-exclusion table --------
if (!file.exists(CURATE_PATH)) {
    stop("Point-exclusion table not found: data/leaf/aci_curve_curation.csv")
}
curate <- read.csv(CURATE_PATH, stringsAsFactors = FALSE)
curate$points_to_remove[is.na(curate$points_to_remove)] <- ""
curate$split_at_obs[is.na(curate$split_at_obs)]         <- ""
cat(sprintf("Point-exclusion table: %d curves; keep=Y %d, keep=N %d, split %d\n",
            nrow(curate), sum(curate$keep == "Y"), sum(curate$keep == "N"),
            sum(nchar(curate$split_at_obs) > 0)))

# -------- Helpers --------
add_col <- function(e, name, vals, cat_label = "metadata") {
    e$main_data[[name]] <- vals
    if (!is.null(e$units))      e$units[[name]]      <- ""
    if (!is.null(e$categories)) e$categories[[name]] <- cat_label
    e
}

apply_remap <- function(e, remap) {
    if (is.null(remap)) return(e)
    for (from in names(remap)) {
        to <- unname(remap[from])
        if (from %in% colnames(e$main_data) && !(to %in% colnames(e$main_data))) {
            colnames(e$main_data)[colnames(e$main_data) == from] <- to
            if (!is.null(e$units) && from %in% names(e$units)) {
                e$units[[to]] <- e$units[[from]]
                e$units[[from]] <- NULL
            }
            if (!is.null(e$categories) && from %in% names(e$categories)) {
                e$categories[[to]] <- e$categories[[from]]
                e$categories[[from]] <- NULL
            }
        }
    }
    e
}

# -------- Fit the curves of one instrument workbook --------
fit_one_machine <- function(cell_name, machine, xf) {
    cat(sprintf("\n  [%s/%s] ", cell_name, machine))
    e <- tryCatch(read_gasex_file(xf, "time"),
                  error = function(err) { cat(sprintf("read ERROR: %s\n",
                                                       conditionMessage(err))); NULL })
    if (is.null(e)) return(NULL)
    e <- apply_remap(e, COL_REMAPS[[cell_name]][[machine]])

    # Metadata columns
    e <- add_col(e, "machine",   rep(machine, nrow(e$main_data)))
    e <- add_col(e, "species",   rep("soybean", nrow(e$main_data)))
    e <- add_col(e, "curve_uid",
                 paste(machine, e$main_data$Pass, e$main_data$Range, sep = "__"))
    e <- add_col(e, "curve_uid_orig", e$main_data$curve_uid)

    # Exclusion decisions for the curves of this workbook
    cur <- curate[curate$cell == cell_name & curate$machine == machine &
                  curate$keep == "Y", , drop = FALSE]
    if (nrow(cur) == 0) {
        cat("no kept curves\n"); return(NULL)
    }

    # Keep the retained curves and remove the listed points. The curve measured twice on the same
    # plant is split. Observations up to split_at_obs form the first curve and the remaining
    # observations the second, each with its own suffix on the curve identifier.
    keep_mask <- rep(FALSE, nrow(e$main_data))
    for (i in seq_len(nrow(cur))) {
        uid <- cur$curve_uid[i]
        rows_idx <- which(e$main_data$curve_uid_orig == uid)
        if (length(rows_idx) == 0) next

        ptr <- cur$points_to_remove[i]
        if (nchar(ptr) > 0) {
            drop_obs <- as.integer(strsplit(gsub("\\s", "", ptr), ",")[[1]])
            rows_idx <- rows_idx[!e$main_data$obs[rows_idx] %in% drop_obs]
        }

        split_at <- cur$split_at_obs[i]
        if (nchar(split_at) > 0) {
            split_val <- as.integer(split_at)
            for (r in rows_idx) {
                e$main_data$curve_uid[r] <- if (e$main_data$obs[r] <= split_val)
                                                paste0(uid, "_v1")
                                            else
                                                paste0(uid, "_v2")
            }
        }

        keep_mask[rows_idx] <- TRUE
    }

    e <- e[keep_mask, , TRUE]
    n_kept_rows   <- nrow(e$main_data)
    n_kept_curves <- length(unique(e$main_data$curve_uid))
    if (n_kept_rows == 0) {
        cat("no records left after exclusions\n"); return(NULL)
    }

    # PhotoGEA processing. apply_gm() reads gmc_at_25, and an infinite mesophyll conductance makes
    # Cc equal to Ci. calculate_temperature_response() applies the Bernacchi et al. (2001)
    # parameter set, which mixes Arrhenius, Johnson and polynomial forms, and adds the
    # temperature-normalized gmc that apply_gm() needs, so it runs before apply_gm().
    e <- set_variable(e, "gmc_at_25", "mol m^(-2) s^(-1) bar^(-1)",
                      id_column = "species",
                      value_table = list(soybean = Inf))
    e <- calculate_total_pressure(e)
    e <- calculate_temperature_response(e, c3_temperature_param_bernacchi)
    e <- apply_gm(e)

    cat(sprintf("fitting %d curves (%d records after exclusions)... ",
                n_kept_curves, n_kept_rows))
    # RL_at_25 has a lower bound of zero. The other parameters use the PhotoGEA defaults.
    aci_results <- tryCatch({
        consolidate(by(e, e[, "curve_uid"], fit_c3_aci,
                       Ca_atmospheric = 420,
                       lower = list(RL_at_25 = 0)))
    }, error = function(err) {
        cat(sprintf("FIT ERROR: %s\n", conditionMessage(err))); NULL
    })

    if (is.null(aci_results)) return(NULL)

    pars <- as.data.frame(aci_results$parameters$main_data)
    md   <- e$main_data

    summary_rows <- list()
    safe <- function(row, col) if (col %in% colnames(row)) row[[col]] else NA
    for (uid in unique(pars$curve_uid)) {
        if (is.na(uid) || nchar(uid) == 0) next
        sub <- md[md$curve_uid == uid, , drop = FALSE]
        if (nrow(sub) == 0) next
        par_row <- pars[pars$curve_uid == uid, , drop = FALSE][1, ]
        summary_rows[[length(summary_rows) + 1]] <- data.frame(
            cell           = cell_name,
            curve_uid      = uid,
            curve_uid_orig = sub$curve_uid_orig[1],
            machine        = machine,
            Pass           = sub$Pass[1],
            Range          = sub$Range[1],
            n_points_used  = nrow(sub),
            Vcmax_at_25    = safe(par_row, "Vcmax_at_25"),
            J_at_25        = safe(par_row, "J_at_25"),
            RL_at_25       = safe(par_row, "RL_at_25"),
            Tp_at_25       = safe(par_row, "Tp_at_25"),
            Vcmax_trust    = as.character(safe(par_row, "Vcmax_trust")),
            J_trust        = as.character(safe(par_row, "J_trust")),
            RL_trust       = as.character(safe(par_row, "RL_trust")),
            Tp_trust       = as.character(safe(par_row, "Tp_trust")),
            RMSE           = safe(par_row, "RMSE"),
            fit_status     = "OK",
            stringsAsFactors = FALSE
        )
    }
    if (length(summary_rows) == 0) {
        cat("no fits produced\n"); return(NULL)
    }
    out <- do.call(rbind, summary_rows)
    cat(sprintf("OK -> %d plant fits\n", nrow(out)))
    out
}

# -------- Driver --------
args <- commandArgs(trailingOnly = TRUE)
target_cells <- if (length(args) > 0) args else CELL_NAMES

all_fits <- list()
for (cell_name in target_cells) {
    if (!cell_name %in% CELL_NAMES) {
        cat(sprintf("Unknown cell '%s', skipped.\n", cell_name)); next
    }
    cat(sprintf("\n========== %s ==========\n", cell_name))
    cell_dir <- file.path(EVAL_DIR, cell_name)
    xfs <- list.files(cell_dir, pattern = "\\.xlsx$", full.names = TRUE)
    for (xf in xfs) {
        machine <- tools::file_path_sans_ext(basename(xf))
        res <- fit_one_machine(cell_name, machine, xf)
        if (!is.null(res)) all_fits[[length(all_fits) + 1]] <- res
    }
}

out <- do.call(rbind, all_fits)
out_csv <- file.path(OUT_DIR, "aci_fits_per_plant_refit.csv")
write.csv(out, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s\n", basename(out_csv)))
cat(sprintf("  %d plant fits in %d cells\n", nrow(out),
            length(unique(out$cell))))

cat("\nPer-cell summary (mean +/- sd; n_reliable_3 = Vcmax, J and Tp all reliable;\n")
cat("PhotoGEA gives no trust flag for RL, which is estimated from the curve intercept):\n")
for (c in unique(out$cell)) {
    s <- out[out$cell == c, ]
    n_reliable <- sum(s$Vcmax_trust == "reliable" & s$J_trust == "reliable" &
                      s$Tp_trust == "reliable", na.rm = TRUE)
    cat(sprintf("  %-6s  n=%3d  n_reliable_3=%3d  Vcmax25=%.1f+/-%.1f  J25=%.1f+/-%.1f  RL25=%.3f+/-%.3f  Tp25=%.2f+/-%.2f\n",
                c, nrow(s), n_reliable,
                mean(s$Vcmax_at_25, na.rm = TRUE), sd(s$Vcmax_at_25, na.rm = TRUE),
                mean(s$J_at_25,     na.rm = TRUE), sd(s$J_at_25,     na.rm = TRUE),
                mean(s$RL_at_25,    na.rm = TRUE), sd(s$RL_at_25,    na.rm = TRUE),
                mean(s$Tp_at_25,    na.rm = TRUE), sd(s$Tp_at_25,    na.rm = TRUE)))
}
cat("\nDone.\n")
