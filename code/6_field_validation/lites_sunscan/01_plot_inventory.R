# Plot inventory of the LITES light-profile campaign at SoyFACE
#
# Purpose
#   Lists every plot scanned with the LITES PAR-sensor frame at SoyFACE (76-cm rows, 20-22 August
#   2024, DAP 77-79), counts its scans and assigns it to a class. The classes are BC3
#   near-isogenic lines (numeric plot names), the broad-leaflet recurrent parent LD11-2170
#   (LD11-*), the donor lines 713A and 745, and dark calibration scans. Each scanned plot is
#   joined to the plot sheet for its field position (Range, Pass), leaflet type, spacing and rank.
#   The inventory defines the 39 plots of the field validation (33 BC3 NILs and six LD11-2170
#   plots, Methods S1.8) and maps each plot to its Loc_ID = SF_<Pass>_<Range> in the later steps
#   (Fig. 5A-B, Tables S7 and S21).
#
# Inputs
#   data/lites_sunscan/lites_sunscan_SF.xlsx   sheets LITE (PAR at eight sensor heights per scan)
#                                               and plots (SoyFACE plot sheet)
#
# Outputs
#   outputs/field_validation/lites_sunscan/plot_inventory.csv
#       one row per scanned plot (dark calibration scans excluded) with columns plot, n_scans,
#       class, Location, Range, Pass, Leaf_type, Spacing and Rank
#
# Usage
#   Rscript code/6_field_validation/lites_sunscan/01_plot_inventory.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); packages readxl, dplyr, readr

suppressPackageStartupMessages({ library(readxl); library(dplyr); library(readr) })

ROOT  <- Sys.getenv("PACKAGE_ROOT", unset = ".")
XL    <- file.path(ROOT, "data", "lites_sunscan", "lites_sunscan_SF.xlsx")
OUT   <- file.path(ROOT, "outputs", "field_validation", "lites_sunscan")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

lite  <- read_excel(XL, sheet = "LITE")  %>% mutate(plot = as.character(plot))
plots <- read_excel(XL, sheet = "plots") %>% mutate(plot = as.character(ID))

# Plot classes from the plot name.
classify <- function(p) {
  ifelse(grepl("^da[krl]", tolower(p)), "DARK_calib",
  ifelse(grepl("^LD11", p),             "PARENT_LD11_recurrent",
  ifelse(grepl("^713",  p),             "LINE_713",
  ifelse(grepl("^745",  p),             "LINE_745",
                                        "BC3_NIL_numeric"))))
}

# ---- LITES scan counts per plot ----
scan_counts <- lite %>% group_by(plot) %>% summarize(n_scans = n(), .groups="drop") %>%
  mutate(class = classify(plot))

cat("===== LITES scan inventory by class =====\n")
scan_counts %>% group_by(class) %>%
  summarize(n_plots = n(), n_scans = sum(n_scans), .groups="drop") %>%
  as.data.frame() %>% print(row.names = FALSE)

cat("\n===== scans-per-plot distribution (calibration scans excluded) =====\n")
scan_counts %>% filter(class != "DARK_calib") %>%
  count(n_scans, name = "n_plots") %>% as.data.frame() %>% print(row.names = FALSE)

# ---- Join to the plot sheet ----
cat("\n===== scanned plots found in the plot sheet =====\n")
xwalk <- scan_counts %>% filter(class != "DARK_calib") %>%
  left_join(plots %>% select(plot, Location, Range, Pass, Leaf_type, Spacing, Rank),
            by = "plot")
xwalk %>% summarize(in_design = sum(!is.na(Leaf_type)),
                    NOT_in_design = sum(is.na(Leaf_type))) %>%
  as.data.frame() %>% print(row.names = FALSE)

cat("\n--- scanned plots not in the plot sheet (no Leaf_type) ---\n")
print(xwalk %>% filter(is.na(Leaf_type)) %>% select(plot, class, n_scans) %>%
        as.data.frame(), row.names = FALSE)

# ---- Scanned plots by leaflet type and spacing ----
cat("\n===== scanned plots in the plot sheet, Leaf_type x Spacing =====\n")
meas <- xwalk %>% filter(!is.na(Leaf_type))
cat("n plots:", nrow(meas), "\n")
print(addmargins(table(meas$Leaf_type, meas$Spacing, useNA="ifany")))
cat("\nBy class (number of plots):\n")
print(table(meas$class))

write_csv(xwalk, file.path(OUT, "plot_inventory.csv"))
cat("\nWrote plot_inventory.csv\n")
