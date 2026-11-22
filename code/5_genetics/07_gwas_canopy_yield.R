# Genome-wide association scans of Canopy A, Canopy LUE and Yield per LAI
#
# Purpose
#   Tests each quality-controlled marker for association with three line BLUPs from the all-lines
#   model (BOTH-all-lines), using the test of 06_gwas_leaflet_lw.R (Fig. 7B and 7C and Table S20).
#   The traits are reproductive-stage canopy A (A_mean_repro) and canopy LUE (L_mean_repro) from
#   02_canopy_blups_heritability.R and yield per LAI (yield_per_LAI_BOTH_all_lines) from
#   03_yield_per_lai_blups_heritability.R. Every line with a BLUP and a genotype is used. The
#   per-allele effect (beta) is the marker slope from rrBLUP::mixed.solve (REML, Endelman, 2011)
#   with the kinship matrix of 05_kinship_marker_qc.R. The standard error, two-sided P-value and
#   R2 come from ordinary least squares.
#
# Test
#   A marker is tested when at least 30 lines have a call and the calls include two or more
#   dosage classes. minuslog10p is -log10(pvalue). If a P-value underflows to zero, minuslog10p is
#   computed instead on the log scale from the t distribution of beta / se with n - 2 degrees of
#   freedom, where n is the number of lines in the scan. p_bonf is pvalue times the number of
#   markers with a P-value (capped at 1), and p_fdr is the Benjamini-Hochberg adjusted P-value.
#
# Inputs
#   data/genetics/genotype.csv                SNP calls of the BC3 lines
#   outputs/genetics/marker_qc.csv            quality-controlled markers (05_kinship_marker_qc.R)
#   outputs/genetics/kinship_matrix.rds       kinship matrix (05_kinship_marker_qc.R)
#   outputs/genetics/blups_canopy.csv         canopy BLUPs (02_canopy_blups_heritability.R)
#   outputs/genetics/blups_yield_per_lai.csv  yield-per-LAI BLUPs (03_yield_per_lai_blups_heritability.R)
#
# Outputs (one row per quality-controlled marker, columns as in 06_gwas_leaflet_lw.R with
# sig_fdr, p_fdr < 0.05, in place of sig_05)
#   outputs/genetics/gwas_canopy_A.csv        scan of A_mean_repro (Canopy A)
#   outputs/genetics/gwas_canopy_LUE.csv      scan of L_mean_repro (Canopy LUE)
#   outputs/genetics/gwas_yield_per_lai.csv   scan of yield_per_LAI_BOTH_all_lines (Yield per LAI)
#
# Usage
#   Rscript code/5_genetics/07_gwas_canopy_yield.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1; packages rrBLUP, dplyr, readr

suppressPackageStartupMessages({
  library(rrBLUP); library(dplyr); library(readr)
})
set.seed(42); options(stringsAsFactors = FALSE)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

GENO_FILE  <- file.path(ROOT, "data", "genetics", "genotype.csv")
K_FILE     <- file.path(ROOT, "outputs", "genetics", "kinship_matrix.rds")
MSTAT_FILE <- file.path(ROOT, "outputs", "genetics", "marker_qc.csv")

CANOPY_BLUPS_ALL <- file.path(ROOT, "outputs", "genetics", "blups_canopy.csv")
YIELD_BLUPS      <- file.path(ROOT, "outputs", "genetics", "blups_yield_per_lai.csv")

OUT_DIR <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- Genotype dosages of the quality-controlled markers ---------------------
# Coding as in 05_kinship_marker_qc.R (0, 1, 2 copies of Allele_2, unmatched calls missing).
geno_raw <- read.csv(GENO_FILE)
marker_info <- geno_raw[, 1:6]
names(marker_info) <- c("AgriPlex_ID","SNP_ID","Chr","bp","Allele_1","Allele_2")
bc3_cols <- grep("^BC3_", names(geno_raw), value = TRUE)
geno_str <- as.matrix(geno_raw[, bc3_cols]); rownames(geno_str) <- marker_info$SNP_ID

n_markers <- nrow(geno_str); n_inds <- ncol(geno_str)
geno_num <- matrix(NA_real_, n_inds, n_markers,
                   dimnames = list(bc3_cols, marker_info$SNP_ID))
for (i in seq_len(n_markers)) {
  a1 <- marker_info$Allele_1[i]; a2 <- marker_info$Allele_2[i]
  for (j in seq_len(n_inds)) {
    g <- as.character(geno_str[i, j])
    if (is.na(g) || g %in% c("","-","NN","FAIL")) next
    if (grepl("/", g)) {
      parts <- trimws(unlist(strsplit(g, "/")))
      if (length(parts) == 2) {
        if (all(parts == a1)) geno_num[j, i] <- 0
        else if (all(parts == a2)) geno_num[j, i] <- 2
        else if (setequal(parts, c(a1, a2))) geno_num[j, i] <- 1
      }
    } else if (nchar(g) == 1) {
      if (g == a1) geno_num[j, i] <- 0
      else if (g == a2) geno_num[j, i] <- 2
    } else if (nchar(g) == 2) {
      b1 <- substr(g, 1, 1); b2 <- substr(g, 2, 2)
      if (b1 == a1 && b2 == a1) geno_num[j, i] <- 0
      else if (b1 == a2 && b2 == a2) geno_num[j, i] <- 2
      else if (setequal(c(b1, b2), c(a1, a2))) geno_num[j, i] <- 1
    }
  }
}
mstats_qc <- read.csv(MSTAT_FILE)
geno_qc <- geno_num[, mstats_qc$marker, drop = FALSE]
K <- readRDS(K_FILE)
cat(sprintf("Loaded: %d QC markers, %d individuals, kinship %d x %d\n",
            ncol(geno_qc), nrow(geno_qc), nrow(K), ncol(K)))

# ---- Single-marker scan (mixed-model slope, OLS standard error and P-value) ----
gwas_scan <- function(y_named) {
  ids <- intersect(rownames(geno_qc), names(y_named))
  ids <- ids[!is.na(y_named[ids]) & ids %in% rownames(K)]
  if (length(ids) < 30) stop("Too few lines")
  yy <- y_named[ids]
  GG <- geno_qc[ids, , drop = FALSE]
  KK <- K[ids, ids]
  out <- data.frame(marker = mstats_qc$marker, chr = mstats_qc$chr,
                    pos_bp = mstats_qc$bp, pvalue = NA_real_,
                    beta = NA_real_, se = NA_real_, rsq = NA_real_,
                    maf = mstats_qc$maf)
  for (i in seq_len(ncol(GG))) {
    x <- GG[, i]
    ok <- !is.na(x) & x %in% c(0, 1, 2)
    if (sum(ok) < 30 || length(unique(x[ok])) < 2) next
    y_i <- yy[ok]; x_i <- x[ok]; K_i <- KK[ok, ok, drop = FALSE]
    X <- cbind(1, x_i)
    ms <- tryCatch(mixed.solve(y = y_i, X = X, K = K_i, method = "REML"),
                   error = function(e) NULL)
    if (is.null(ms) || length(ms$beta) < 2) next
    fit <- tryCatch(lm(y_i ~ x_i), error = function(e) NULL)
    if (is.null(fit)) next
    co <- summary(fit)$coefficients
    if (nrow(co) < 2) next
    out$beta[i]   <- as.numeric(ms$beta[2])
    out$se[i]     <- co[2, "Std. Error"]
    out$pvalue[i] <- co[2, "Pr(>|t|)"]
    out$rsq[i]    <- summary(fit)$r.squared
  }
  # -log10 P. Where the P-value underflows to zero, it is taken from the t distribution with
  # n - 2 degrees of freedom on the log scale.
  df_t <- length(ids) - 2
  z_t  <- out$beta / out$se
  log10p_via_pt <- (log(2) + pt(-abs(z_t), df = df_t, log.p = TRUE)) / log(10)
  out$minuslog10p <- ifelse(is.na(out$pvalue) | out$pvalue <= 0,
                             -log10p_via_pt,
                             -log10(out$pvalue))
  # Bonferroni and Benjamini-Hochberg adjusted P-values and significance flags.
  nM <- sum(!is.na(out$pvalue))
  out$p_bonf   <- pmin(1, out$pvalue * nM)
  out$p_fdr    <- p.adjust(out$pvalue, method = "BH")
  out$sig_bonf <- !is.na(out$p_bonf) & out$p_bonf < 0.05
  out$sig_fdr  <- !is.na(out$p_fdr)  & out$p_fdr  < 0.05
  list(qtl = out, n_lines = length(ids))
}

# ---- Run the three scans ----------------------------------------------------
# BLUP files name lines by number. The genotype rows use BC3_<n>.
canopy_all <- read_csv(CANOPY_BLUPS_ALL, show_col_types = FALSE) %>%
  mutate(BC3_ID = paste0("BC3_", BC3_ID))
yield_all  <- read_csv(YIELD_BLUPS, show_col_types = FALSE) %>%
  mutate(BC3_ID = ifelse(grepl("^BC3_", as.character(BC3_ID)),
                          as.character(BC3_ID),
                          paste0("BC3_", BC3_ID)))

run_and_save <- function(blup_df, trait_col, out_fname) {
  y <- setNames(blup_df[[trait_col]][match(rownames(K), blup_df$BC3_ID)],
                rownames(K))
  res <- gwas_scan(y)
  cat(sprintf("  %s : n_lines = %d\n", out_fname, res$n_lines))
  fp <- file.path(OUT_DIR, out_fname)
  write.csv(res$qtl, fp, row.names = FALSE)
  cat(sprintf("  wrote outputs/genetics/%s\n", out_fname))
  res$n_lines
}

cat("\nRunning the association scans on the all-lines BLUPs\n")
n_A <- run_and_save(canopy_all, "A_mean_repro",
                    "gwas_canopy_A.csv")
n_L <- run_and_save(canopy_all, "L_mean_repro",
                    "gwas_canopy_LUE.csv")
n_Y <- run_and_save(yield_all,  "yield_per_LAI_BOTH_all_lines",
                    "gwas_yield_per_lai.csv")

cat(sprintf("\nLines in each scan: Canopy A = %d, Canopy LUE = %d, Yield per LAI = %d\n", n_A, n_L, n_Y))
