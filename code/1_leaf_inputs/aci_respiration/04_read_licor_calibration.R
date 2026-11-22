# Tabulate the calibration records of the LI-6800 instruments
#
# Purpose
#   Reads the Remarks sheet of every LI-6800 workbook and tabulates the instrument metadata it
#   records. These are the console and sensor-head serial numbers and firmware versions, the
#   factory calibration date, the last CO2 and H2O range-match times, the chamber type and serial
#   number, and the time the file was opened. The table is the record behind the instrument exclusions applied to the
#   Rd25 combination means in 05_rd25_combination_means.R (Table S14). The script prints the
#   records of the excluded instruments (Ains2, Ripe14 and Ripe8) next to those of the others.
#
# Inputs
#   data/leaf/aci_curves/<cell>/<instrument>.xlsx   recalculated LI-6800 workbooks (sheet Remarks)
#
# Outputs
#   outputs/leaf_inputs/licor_calibration_records.csv   one row per workbook
#
# Usage
#   Rscript code/1_leaf_inputs/aci_respiration/04_read_licor_calibration.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); package readxl (1.5.0 used)

suppressPackageStartupMessages({
    library(readxl)
})

ROOT     <- Sys.getenv("PACKAGE_ROOT", unset = ".")
EVAL_DIR <- file.path(ROOT, "data", "leaf", "aci_curves")
OUT_DIR  <- file.path(ROOT, "outputs", "leaf_inputs")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

CELL_NAMES <- c("SF_15","SF_30","EF_15","EF_30")

# -------- Read the Remarks sheet of one workbook --------
read_remarks <- function(xlsx_path) {
    r <- tryCatch(
        as.data.frame(read_excel(xlsx_path, sheet = "Remarks",
                                  col_names = c("key","value"), col_types = "text")),
        error = function(e) NULL
    )
    if (is.null(r)) return(NULL)
    out <- list(file = basename(xlsx_path))
    keys_of_interest <- c("Console s/n", "Console ver", "Scripts ver",
                          "Head s/n", "Head ver",
                          "Factory cal date",
                          "CO2 rangematch", "H2O rangematch",
                          "Chamber type", "Chamber s/n", "File opened")
    for (k in keys_of_interest) {
        m <- r[!is.na(r$key) & r$key == k, "value"]
        out[[k]] <- if (length(m) > 0) m[1] else NA
    }
    as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}

# -------- Read all workbooks --------
rows <- list()
for (cell in CELL_NAMES) {
    cdir <- file.path(EVAL_DIR, cell)
    xfs <- list.files(cdir, pattern = "\\.xlsx$", full.names = TRUE)
    for (xf in xfs) {
        machine <- tools::file_path_sans_ext(basename(xf))
        r <- read_remarks(xf)
        if (!is.null(r)) {
            r$cell <- cell
            r$machine <- machine
            rows[[length(rows) + 1]] <- r
        }
    }
}
df <- do.call(rbind, rows)

# -------- Print the full table --------
cat("=========================================================\n")
cat("LI-6800 calibration records (Remarks sheet of each workbook)\n")
cat("=========================================================\n\n")
df_view <- df[, c("cell","machine","File opened","Console s/n","Console ver",
                   "Head s/n","Head ver","Factory cal date",
                   "CO2 rangematch","H2O rangematch","Chamber type","Chamber s/n")]
df_view <- df_view[order(df_view$cell, df_view$machine), ]
print(df_view, row.names = FALSE)

# -------- Records of the instruments excluded from the Rd25 means --------
cat("\n=========================================================\n")
cat("Ains2 compared with the other instruments\n")
cat("=========================================================\n")
ains2 <- df[df$machine == "Ains2", ]
others <- df[df$machine != "Ains2", ]

cat("Ains2 records (per workbook):\n")
for (i in seq_len(nrow(ains2))) {
    r <- ains2[i, ]
    cat(sprintf("  %s/%s\n", r$cell, r$machine))
    cat(sprintf("    Factory cal date  : %s\n", r$`Factory cal date`))
    cat(sprintf("    CO2 rangematch    : %s\n", r$`CO2 rangematch`))
    cat(sprintf("    H2O rangematch    : %s\n", r$`H2O rangematch`))
    cat(sprintf("    Head ver / Scripts: %s / %s\n", r$`Head ver`, r$`Scripts ver`))
    cat(sprintf("    Chamber s/n       : %s\n", r$`Chamber s/n`))
}

cat("\nFactory calibration dates of the other instruments\n")
cat(paste("  ", unique(others$`Factory cal date`)), sep = "\n")
cat("\nCO2 range-match times of the other instruments\n")
cat(paste("  ", unique(others$`CO2 rangematch`)), sep = "\n")
cat("\nH2O range-match times of the other instruments\n")
cat(paste("  ", unique(others$`H2O rangematch`)), sep = "\n")

cat("\n=========================================================\n")
cat("Ripe14 and Ripe8 records\n")
cat("=========================================================\n")
for (m in c("Ripe14","Ripe8")) {
    sub <- df[df$machine == m, ]
    cat(sprintf("\n%s (n=%d workbooks):\n", m, nrow(sub)))
    for (i in seq_len(nrow(sub))) {
        r <- sub[i, ]
        cat(sprintf("  %s: factory_cal=%s | co2_rm=%s | h2o_rm=%s\n",
                    r$cell, r$`Factory cal date`, r$`CO2 rangematch`, r$`H2O rangematch`))
    }
}

# -------- Write the table --------
write.csv(df, file.path(OUT_DIR, "licor_calibration_records.csv"), row.names = FALSE)
cat(sprintf("\nWrote licor_calibration_records.csv\n"))
