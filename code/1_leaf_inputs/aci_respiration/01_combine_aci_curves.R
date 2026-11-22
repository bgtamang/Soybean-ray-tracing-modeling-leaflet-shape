# Combine the LI-6800 A-Ci records of each site and row spacing into one table
#
# Purpose
#   Reads every recalculated LI-6800 workbook of one site and row spacing with PhotoGEA's
#   read_gasex_file(), so that the formula columns (A, Ci, Ca, gsw, Qin) carry their evaluated
#   values, and stacks the records into one table per site and row spacing. Columns missing from
#   a workbook are filled with NA. Each record gets the instrument name, the source workbook, its
#   MD5 checksum, the time the workbook was read, and a curve identifier
#   <instrument>__<Pass>__<Range> that stays unique when two instruments measured the same field
#   position. All records are kept. Point screening follows in 02_flag_aci_points.R. These tables
#   are the first step toward the dark respiration (Rd25) values in Table S14.
#
# Inputs
#   data/leaf/aci_curves/<cell>/<instrument>.xlsx   recalculated LI-6800 workbooks
#                                                    (00_recalculate_licor_workbooks.ps1)
#
# Outputs
#   outputs/leaf_inputs/aci_curves_combined_<cell>.csv   all records of one site and row spacing
#
#   <cell> is SF_15, SF_30, EF_15 or EF_30: the site code and the row spacing in inches
#   (15 = 38-cm rows, 30 = 76-cm rows).
#
# Usage
#   Rscript code/1_leaf_inputs/aci_respiration/01_combine_aci_curves.R   (run from the package root)
#   Cell codes given as arguments limit the run to those cells, for example "... EF_30".
#
# Requirements
#   R (4.6.1 used); packages PhotoGEA (1.4.0 used), tools

suppressPackageStartupMessages({
    library(PhotoGEA)
    library(tools)
})

ROOT     <- Sys.getenv("PACKAGE_ROOT", unset = ".")
EVAL_DIR <- file.path(ROOT, "data", "leaf", "aci_curves")
OUT_DIR  <- file.path(ROOT, "outputs", "leaf_inputs")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# One folder per site and row spacing, with one workbook per instrument named <instrument>.xlsx.
CELL_NAMES <- c("SF_15", "SF_30", "EF_15", "EF_30")
SPACING_CM <- c("15" = 38, "30" = 76)

# -------- Per-instrument column renames --------
# Field position is stored in the user-defined constants Pass and Range. The operator of Ripe15
# at the Energy Farm 76-cm rows labeled the position constant "Plot" instead of "Range". Its
# values are field positions like Range in the other files, so the column is renamed before the
# curves are grouped.
COL_REMAPS <- list(
    EF_30 = list(
        Ripe15 = c(Plot = "Range")  # rename column "Plot" to "Range"
    )
)

# -------- Helpers --------
md5_short <- function(filepath) {
    h <- tools::md5sum(filepath)
    substr(unname(h), 1, 12)
}

# -------- Process one cell --------
process_cell <- function(cell_name) {
    parts <- strsplit(cell_name, "_", fixed = TRUE)[[1]]
    site <- parts[1]
    spacing <- as.integer(parts[2])

    cell_dir <- file.path(EVAL_DIR, cell_name)
    cat(sprintf("\n=== %s (%s, %d-cm rows) ===\n", cell_name, site,
                SPACING_CM[[as.character(spacing)]]))

    if (!dir.exists(cell_dir)) {
        cat(sprintf("  No workbook folder data/leaf/aci_curves/%s. Cell skipped.\n", cell_name))
        return(NULL)
    }

    xlsx_files <- list.files(cell_dir, pattern = "\\.xlsx$", full.names = TRUE, ignore.case = TRUE)
    cat(sprintf("  workbooks found: %d\n", length(xlsx_files)))

    # Read each workbook into a plain data frame and add the provenance columns.
    df_list <- list()

    for (xf in xlsx_files) {
        # The instrument name is the workbook name without its extension.
        machine <- tools::file_path_sans_ext(basename(xf))

        cat(sprintf("  [%s] reading %s ... ", machine, basename(xf)))
        result <- tryCatch({
            exdf <- read_gasex_file(xf, "time")
            df   <- as.data.frame(exdf$main_data)  # plain data frame without the exdf wrapper
            n_rows <- nrow(df)
            hash   <- md5_short(xf)

            # Apply the per-instrument column renames (Ripe15 at EF_30: Plot -> Range).
            remap <- COL_REMAPS[[cell_name]][[machine]]
            if (!is.null(remap)) {
                for (from_col in names(remap)) {
                    to_col <- unname(remap[from_col])
                    if (from_col %in% colnames(df)) {
                        if (to_col %in% colnames(df)) {
                            cat(sprintf("[both %s and %s present, rename not applied] ",
                                        from_col, to_col))
                        } else {
                            colnames(df)[colnames(df) == from_col] <- to_col
                            cat(sprintf("[renamed %s -> %s] ", from_col, to_col))
                        }
                    }
                }
            }

            df$machine                <- machine
            df$source_xlsx            <- basename(xf)
            df$source_xlsx_md5_short  <- hash
            df$read_timestamp         <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

            cat(sprintf("rows=%d md5=%s cols=%d\n", n_rows, hash, ncol(df)))
            list(df = df, n_rows = n_rows, hash = hash)
        }, error = function(e) {
            cat(sprintf("ERROR: %s\n", conditionMessage(e)))
            NULL
        })

        if (!is.null(result)) {
            df_list[[length(df_list) + 1]] <- result$df
        }
    }

    if (length(df_list) == 0) {
        cat(sprintf("  No workbook could be read for %s. Cell skipped.\n", cell_name))
        return(NULL)
    }

    cat(sprintf("  Read %d workbooks. Stacking on the union of their columns...\n", length(df_list)))

    # Union of the columns of all workbooks. A column missing from a workbook is NA in its rows.
    all_cols <- unique(unlist(lapply(df_list, colnames)))

    df_list_aligned <- lapply(df_list, function(d) {
        miss <- setdiff(all_cols, colnames(d))
        for (m in miss) d[[m]] <- NA
        d[, all_cols, drop = FALSE]
    })

    main <- do.call(rbind, df_list_aligned)

    # Curve identifier that stays unique across instruments.
    main$curve_uid <- paste(main$machine, main$Pass, main$Range, sep = "__")

    # Site and row spacing (inch code) of the cell.
    main$Site_label <- site
    main$Spacing_inch <- spacing

    out_path <- file.path(OUT_DIR, sprintf("aci_curves_combined_%s.csv", cell_name))
    write.csv(main, out_path, row.names = FALSE)

    n_curves <- length(unique(main$curve_uid))
    cat(sprintf("  wrote %s: %d rows, %d curves, %d columns\n",
                basename(out_path), nrow(main), n_curves, ncol(main)))

    # Number of records per curve, which shows truncated or extended curves.
    rpc <- table(main$curve_uid)
    rpc_summary <- data.frame(
        rows_per_curve = as.integer(names(table(rpc))),
        n_curves = as.integer(table(rpc)),
        stringsAsFactors = FALSE
    )
    cat("  Records per curve\n")
    for (i in seq_len(nrow(rpc_summary))) {
        cat(sprintf("    %d records: %d curves\n",
                    rpc_summary$rows_per_curve[i], rpc_summary$n_curves[i]))
    }

    return(list(cell = cell_name, n_rows = nrow(main),
                n_curves = n_curves, n_files = length(df_list),
                n_cols = ncol(main)))
}

# -------- Driver --------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
    target_cells <- CELL_NAMES
} else {
    target_cells <- args
}

results <- list()
for (cell_name in target_cells) {
    if (!cell_name %in% CELL_NAMES) {
        cat(sprintf("Unknown cell '%s', skipped. Known cells: %s\n",
                    cell_name, paste(CELL_NAMES, collapse = ", ")))
        next
    }
    res <- process_cell(cell_name)
    if (!is.null(res)) results[[cell_name]] <- res
}

# -------- Summary --------
cat("\n========== SUMMARY ==========\n")
for (r in results) {
    cat(sprintf("  %-6s  files=%d  rows=%d  curves=%d  cols=%d\n",
                r$cell, r$n_files, r$n_rows, r$n_curves, r$n_cols))
}
cat("\nDone.\n")
