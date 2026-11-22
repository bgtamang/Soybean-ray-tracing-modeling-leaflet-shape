# Genome-wide association scan of Leaflet L:W
#
# Purpose
#   Tests each quality-controlled marker for association with the Leaflet L:W BLUPs of
#   04_leaflet_lw_blups_heritability.R (Fig. 7B and 7C and Table S20). The per-allele effect
#   (beta) is the marker slope from a kinship-corrected mixed model fitted by REML
#   (rrBLUP::mixed.solve, Endelman, 2011). The standard error, two-sided P-value and R2 come from
#   an ordinary least-squares regression of the BLUPs on the marker dosage. The script codes the
#   genotypes and applies the marker quality control as in 05_kinship_marker_qc.R, with lines
#   named by their number (BC3_ prefix removed), and builds its own kinship matrix (section 2).
#
# Test
#   A marker is tested when at least 30 lines have a call and the calls include two or more
#   dosage classes. Bonferroni and Benjamini-Hochberg (FDR) adjustments use the markers with a
#   P-value. The genomic inflation factor (lambda) is printed.
#
# Inputs
#   data/genetics/genotype.csv              SNP calls of the BC3 lines (as in 05_kinship_marker_qc.R)
#   outputs/genetics/blups_leaflet_lw.csv   Leaflet L:W BLUPs (04_leaflet_lw_blups_heritability.R)
#
# Outputs
#   outputs/genetics/gwas_leaflet_lw.csv    one row per quality-controlled marker. marker, chr and
#                                           pos_bp identify the marker. beta (mixed-model slope per
#                                           Allele_2 copy, in BLUP units), se, pvalue and rsq (OLS),
#                                           maf, minuslog10p (-log10 P), p_bonf and p_fdr (adjusted
#                                           P), sig_bonf (p_bonf < 0.05) and sig_05 (P < 0.05).
#
# Usage
#   Rscript code/5_genetics/06_gwas_leaflet_lw.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1; packages dplyr, rrBLUP

suppressPackageStartupMessages({
  library(dplyr); library(rrBLUP)
})
options(stringsAsFactors = FALSE, scipen = 999)
set.seed(42)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

GENO_FILE <- file.path(ROOT, "data", "genetics", "genotype.csv")
BLUP_FILE <- file.path(ROOT, "outputs", "genetics", "blups_leaflet_lw.csv")
OUT_DIR   <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ===========================================================================
# 1. Genotype dosages and marker quality control
# ===========================================================================
cat("Loading genotype...\n")
geno_raw <- read.csv(GENO_FILE, stringsAsFactors = FALSE)
marker_info <- geno_raw[, 1:6]
names(marker_info) <- c("AgriPlex_ID","SNP_ID","Chr","bp","Allele_1","Allele_2")
bc3_cols <- grep("^BC3_", names(geno_raw), value = TRUE)
geno_matrix <- as.matrix(geno_raw[, bc3_cols])
rownames(geno_matrix) <- marker_info$SNP_ID
colnames(geno_matrix) <- gsub("BC3_", "", bc3_cols)

n_markers_total <- nrow(geno_matrix)
n_individuals   <- ncol(geno_matrix)
cat(sprintf("  markers: %d   individuals: %d\n", n_markers_total, n_individuals))

# Marker statistics and dosage coding (0, 1, 2 copies of Allele_2).
marker_stats <- data.frame(
  marker = rownames(geno_matrix), chr = marker_info$Chr,
  bp = marker_info$bp,
  n_AA = 0, n_AB = 0, n_BB = 0, n_missing = 0,
  call_rate = 0, maf = 0, is_segregating = FALSE
)
geno_numeric <- matrix(NA_real_, nrow = n_individuals, ncol = n_markers_total,
                       dimnames = list(colnames(geno_matrix), rownames(geno_matrix)))

for (i in seq_len(n_markers_total)) {
  a1 <- marker_info$Allele_1[i]; a2 <- marker_info$Allele_2[i]
  for (j in seq_len(n_individuals)) {
    g <- as.character(geno_matrix[i, j])
    if (is.na(g) || g %in% c("", "-", "NN", "FAIL")) {
      geno_numeric[j, i] <- NA
      marker_stats$n_missing[i] <- marker_stats$n_missing[i] + 1
    } else if (grepl("/", g)) {
      parts <- trimws(unlist(strsplit(g, "/")))
      if (length(parts) == 2) {
        if (all(parts == a1)) { geno_numeric[j, i] <- 0; marker_stats$n_AA[i] <- marker_stats$n_AA[i] + 1
        } else if (all(parts == a2)) { geno_numeric[j, i] <- 2; marker_stats$n_BB[i] <- marker_stats$n_BB[i] + 1
        } else if (setequal(parts, c(a1, a2))) { geno_numeric[j, i] <- 1; marker_stats$n_AB[i] <- marker_stats$n_AB[i] + 1
        } else { geno_numeric[j, i] <- NA; marker_stats$n_missing[i] <- marker_stats$n_missing[i] + 1 }
      }
    } else if (nchar(g) == 1) {
      if (g == a1) { geno_numeric[j, i] <- 0; marker_stats$n_AA[i] <- marker_stats$n_AA[i] + 1
      } else if (g == a2) { geno_numeric[j, i] <- 2; marker_stats$n_BB[i] <- marker_stats$n_BB[i] + 1
      } else { geno_numeric[j, i] <- NA; marker_stats$n_missing[i] <- marker_stats$n_missing[i] + 1 }
    } else if (nchar(g) == 2) {
      b1 <- substr(g, 1, 1); b2 <- substr(g, 2, 2)
      if (b1 == a1 && b2 == a1) { geno_numeric[j, i] <- 0; marker_stats$n_AA[i] <- marker_stats$n_AA[i] + 1
      } else if (b1 == a2 && b2 == a2) { geno_numeric[j, i] <- 2; marker_stats$n_BB[i] <- marker_stats$n_BB[i] + 1
      } else if (setequal(c(b1, b2), c(a1, a2))) { geno_numeric[j, i] <- 1; marker_stats$n_AB[i] <- marker_stats$n_AB[i] + 1
      } else { geno_numeric[j, i] <- NA; marker_stats$n_missing[i] <- marker_stats$n_missing[i] + 1 }
    }
  }
  total_called <- marker_stats$n_AA[i] + marker_stats$n_AB[i] + marker_stats$n_BB[i]
  marker_stats$call_rate[i] <- total_called / n_individuals
  if (total_called > 0) {
    pA <- (2*marker_stats$n_AA[i] + marker_stats$n_AB[i]) / (2*total_called)
    marker_stats$maf[i] <- min(pA, 1 - pA)
    marker_stats$is_segregating[i] <- length(unique(na.omit(geno_numeric[, i]))) > 1
  }
}

qc_pass <- marker_stats$call_rate >= 0.8 &
           marker_stats$maf       >= 0.05 &
           marker_stats$is_segregating
markers_to_keep <- which(qc_pass)
geno_filtered <- geno_numeric[, markers_to_keep, drop = FALSE]
marker_stats_filtered <- marker_stats[markers_to_keep, , drop = FALSE]
cat(sprintf("  passing QC: %d / %d\n", length(markers_to_keep), n_markers_total))

# ===========================================================================
# 2. Kinship (genomic relationship matrix)
# ===========================================================================
# The kinship uses the markers with call rate >= 0.80 and minor allele frequency >= 0.05, without
# the two-class condition of the quality control. This adds three markers that are heterozygous
# in every line (173 markers in all). Being constant, they vanish on centering and change only the
# divisor p. After the eigenvalue floor and the mean-diagonal scaling, K equals the matrix of
# 05_kinship_marker_qc.R to within 2e-8. Missing dosages are mean-imputed, W is centered within
# markers and K = WW'/p. If K has a negative eigenvalue, eigenvalues below 1e-6 are set to 1e-6.
# K is then divided by its mean diagonal.
cat("\nBuilding kinship (centered W, K = WW'/ncol(W), scaled to mean diagonal 1)\n")
kinship_markers <- which(marker_stats$call_rate >= 0.8 & marker_stats$maf >= 0.05)
geno_for_kinship <- geno_numeric[, kinship_markers, drop = FALSE]
for (i in seq_len(ncol(geno_for_kinship))) {
  miss <- is.na(geno_for_kinship[, i])
  if (any(miss)) geno_for_kinship[miss, i] <- mean(geno_for_kinship[, i], na.rm = TRUE)
}
W <- scale(geno_for_kinship, center = TRUE, scale = FALSE)
K <- tcrossprod(W) / ncol(W)
eig <- eigen(K, symmetric = TRUE)
if (any(eig$values < 0)) {
  eig$values[eig$values < 1e-6] <- 1e-6
  K <- eig$vectors %*% diag(eig$values) %*% t(eig$vectors)
}
K <- K / mean(diag(K))
rownames(K) <- colnames(K) <- rownames(geno_for_kinship)

# ===========================================================================
# 3. Leaflet L:W BLUPs aligned to the genotyped lines
# ===========================================================================
cat("\nLoading Leaflet L:W BLUPs...\n")
blup_data <- read.csv(BLUP_FILE, stringsAsFactors = FALSE)
# The BLUP file names lines BC3_<n>. The genotype rows use <n>.
blup_data$id <- gsub("^BC3_", "", blup_data$BC3_ID)

geno_individuals <- rownames(geno_numeric)
blup_filtered <- blup_data %>%
  filter(id %in% geno_individuals,
         !is.na(leaf_ratio_LR)) %>%
  select(id, BLUP = leaf_ratio_LR)

y <- setNames(blup_filtered$BLUP, blup_filtered$id)
valid_idx <- !is.na(y) & names(y) %in% rownames(K)
y <- y[valid_idx]
K_clean <- K[names(y), names(y)]
cat(sprintf("  N individuals with BLUP & K: %d\n", length(y)))

# ===========================================================================
# 4. Single-marker tests (mixed-model slope, OLS standard error and P-value)
# ===========================================================================
cat("\nRunning per-marker tests (mixed.solve for beta, lm for SE and P)...\n")
qtl_results <- data.frame(
  marker = marker_stats_filtered$marker,
  chr    = marker_stats_filtered$chr,
  pos_bp = marker_stats_filtered$bp,
  pvalue = NA_real_, beta = NA_real_, se = NA_real_,
  rsq    = NA_real_, maf = marker_stats_filtered$maf,
  stringsAsFactors = FALSE
)

successful <- 0
for (i in seq_len(ncol(geno_filtered))) {
  x_all <- geno_filtered[, i]
  x  <- x_all[names(y)]
  ok <- !is.na(x) & (x %in% c(0, 1, 2))
  if (sum(ok) >= 30 && length(unique(x[ok])) > 1) {
    yy <- y[ok]; xx <- x[ok]
    KK <- K_clean[ok, ok, drop = FALSE]
    X  <- cbind(1, xx)
    ms <- tryCatch(mixed.solve(y = yy, X = X, K = KK, method = "REML"),
                   error = function(e) NULL)
    if (!is.null(ms) && length(ms$beta) >= 2) {
      b <- as.numeric(ms$beta[2])
      fit_lm <- lm(yy ~ xx)
      summ <- summary(fit_lm)
      if (nrow(summ$coefficients) > 1) {
        qtl_results$beta[i]   <- b
        qtl_results$se[i]     <- summ$coefficients[2, 2]
        qtl_results$pvalue[i] <- summ$coefficients[2, 4]
        qtl_results$rsq[i]    <- summ$r.squared
        successful <- successful + 1
      }
    }
  }
}

qtl_results$minuslog10p <- -log10(qtl_results$pvalue)
valid_p <- qtl_results$pvalue[!is.na(qtl_results$pvalue) &
                              qtl_results$pvalue > 0 &
                              qtl_results$pvalue < 1]
lambda <- if (length(valid_p) > 10)
  median(qchisq(1 - valid_p, 1), na.rm = TRUE) / qchisq(0.5, 1) else NA
qtl_results$p_bonf <- p.adjust(qtl_results$pvalue, method = "bonferroni")
qtl_results$p_fdr  <- p.adjust(qtl_results$pvalue, method = "fdr")
qtl_results$sig_bonf <- qtl_results$p_bonf < 0.05
qtl_results$sig_05   <- qtl_results$pvalue < 0.05

cat(sprintf("\n  markers tested: %d\n", successful))
cat(sprintf("  genomic inflation factor (lambda) = %.3f\n", lambda))
cat(sprintf("  Bonferroni < 0.05: %d\n", sum(qtl_results$sig_bonf, na.rm = TRUE)))
cat(sprintf("  P < 0.05:          %d\n", sum(qtl_results$sig_05, na.rm = TRUE)))

cat("\nTop 5 markers\n")
top5 <- qtl_results[order(qtl_results$pvalue), ][1:5, ]
print(top5[, c("marker", "chr", "pos_bp", "pvalue", "minuslog10p", "beta")])

# ===========================================================================
# 5. Save
# ===========================================================================
out_path <- file.path(OUT_DIR, "gwas_leaflet_lw.csv")
write.csv(qtl_results, out_path, row.names = FALSE)
cat("\nWrote outputs/genetics/gwas_leaflet_lw.csv\n")
