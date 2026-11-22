# Marker quality control and genomic relationship matrix of the BC3 lines
#
# Purpose
#   Converts the SNP calls of the genotyped BC3 lines to allele dosages, applies the marker
#   quality control of the association analysis and builds the genomic relationship (kinship)
#   matrix (Methods S1.7). Markers are kept with a call rate of at least 0.80, a minor allele
#   frequency of at least 0.05 and at least two genotype classes, which leaves 170 markers (the
#   Bonferroni threshold of Fig. 7B is P = 0.05/170). The marker list and the kinship matrix are
#   read by 07_gwas_canopy_yield.R.
#
# Genotype coding
#   0 = homozygous for Allele_1, 1 = heterozygous, 2 = homozygous for Allele_2. Calls written as
#   "A / C", "A" or "AC" are recognized. Empty calls, "-", "NN", "FAIL" and calls that do not
#   match the two alleles of the marker are missing.
#
# Kinship
#   Missing dosages are replaced by the marker mean for the kinship only. W is the dosage matrix
#   centered within each marker, and K = WW'/p with p the number of markers. If K has a negative
#   eigenvalue, eigenvalues below 1e-6 are set to 1e-6 and K is rebuilt from the cleaned spectrum.
#   K is then divided by its mean diagonal.
#
# Inputs
#   data/genetics/genotype.csv   SNP calls of the BC3 lines (AgriPlex 1K panel). One row per
#                                marker with AgriPlex ID, SNP ID, chromosome, position (bp) and
#                                the two alleles, then one column per line (BC3_<n>).
#
# Outputs
#   outputs/genetics/marker_qc.csv        markers that pass quality control, with chromosome,
#                                         position, genotype counts (n_AA, n_AB, n_BB, n_miss),
#                                         call rate, minor allele frequency (maf) and segregation flag
#   outputs/genetics/kinship_matrix.rds   kinship matrix (R matrix, rows and columns named BC3_<n>)
#
# Usage
#   Rscript code/5_genetics/05_kinship_marker_qc.R      (run from the package root)
#
# Requirements
#   R 4.5.2 or 4.6.1 (base R only)

set.seed(42); options(stringsAsFactors = FALSE, scipen = 999)

ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

GENO_FILE <- file.path(ROOT, "data", "genetics", "genotype.csv")
OUT_DIR   <- file.path(ROOT, "outputs", "genetics")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ===========================================================================
# Section 1 - Genotype dosages and marker quality control
# ===========================================================================
cat("Section 1: reading the genotype matrix ...\n")
geno_raw <- read.csv(GENO_FILE, stringsAsFactors = FALSE)
marker_info <- geno_raw[, 1:6]
names(marker_info) <- c("AgriPlex_ID","SNP_ID","Chr","bp","Allele_1","Allele_2")
bc3_cols <- grep("^BC3_", names(geno_raw), value = TRUE)
geno_str <- as.matrix(geno_raw[, bc3_cols])
rownames(geno_str) <- marker_info$SNP_ID

n_markers <- nrow(geno_str); n_inds <- ncol(geno_str)
cat(sprintf("  markers: %d   individuals: %d\n", n_markers, n_inds))

# Dosage matrix (lines x markers) and per-marker genotype counts.
geno_num <- matrix(NA_real_, nrow = n_inds, ncol = n_markers,
                   dimnames = list(bc3_cols, marker_info$SNP_ID))
mstats <- data.frame(marker = marker_info$SNP_ID, chr = marker_info$Chr,
                     bp = marker_info$bp,
                     n_AA = 0, n_AB = 0, n_BB = 0, n_miss = 0,
                     call_rate = 0, maf = 0, segregating = FALSE)

for (i in seq_len(n_markers)) {
  a1 <- marker_info$Allele_1[i]; a2 <- marker_info$Allele_2[i]
  for (j in seq_len(n_inds)) {
    g <- as.character(geno_str[i, j])
    if (is.na(g) || g %in% c("","-","NN","FAIL")) {
      mstats$n_miss[i] <- mstats$n_miss[i] + 1
    } else if (grepl("/", g)) {
      parts <- trimws(unlist(strsplit(g, "/")))
      if (length(parts) == 2) {
        if (all(parts == a1)) {
          geno_num[j, i] <- 0; mstats$n_AA[i] <- mstats$n_AA[i] + 1
        } else if (all(parts == a2)) {
          geno_num[j, i] <- 2; mstats$n_BB[i] <- mstats$n_BB[i] + 1
        } else if (setequal(parts, c(a1, a2))) {
          geno_num[j, i] <- 1; mstats$n_AB[i] <- mstats$n_AB[i] + 1
        } else mstats$n_miss[i] <- mstats$n_miss[i] + 1
      }
    } else if (nchar(g) == 1) {
      if      (g == a1) { geno_num[j, i] <- 0; mstats$n_AA[i] <- mstats$n_AA[i] + 1 }
      else if (g == a2) { geno_num[j, i] <- 2; mstats$n_BB[i] <- mstats$n_BB[i] + 1 }
      else mstats$n_miss[i] <- mstats$n_miss[i] + 1
    } else if (nchar(g) == 2) {
      b1 <- substr(g, 1, 1); b2 <- substr(g, 2, 2)
      if      (b1 == a1 && b2 == a1) { geno_num[j, i] <- 0; mstats$n_AA[i] <- mstats$n_AA[i] + 1 }
      else if (b1 == a2 && b2 == a2) { geno_num[j, i] <- 2; mstats$n_BB[i] <- mstats$n_BB[i] + 1 }
      else if (setequal(c(b1,b2), c(a1,a2))) { geno_num[j, i] <- 1; mstats$n_AB[i] <- mstats$n_AB[i] + 1 }
      else mstats$n_miss[i] <- mstats$n_miss[i] + 1
    }
  }
  called <- mstats$n_AA[i] + mstats$n_AB[i] + mstats$n_BB[i]
  mstats$call_rate[i] <- called / n_inds
  if (called > 0) {
    pA <- (2 * mstats$n_AA[i] + mstats$n_AB[i]) / (2 * called)
    mstats$maf[i] <- min(pA, 1 - pA)
    mstats$segregating[i] <- length(unique(na.omit(geno_num[, i]))) > 1
  }
}

qc_keep <- mstats$call_rate >= 0.80 & mstats$maf >= 0.05 & mstats$segregating
geno_qc <- geno_num[, qc_keep, drop = FALSE]
mstats_qc <- mstats[qc_keep, ]
cat(sprintf("  passed QC: %d / %d\n", sum(qc_keep), n_markers))
write.csv(mstats_qc, file.path(OUT_DIR, "marker_qc.csv"), row.names = FALSE)

# ===========================================================================
# Section 2 - Kinship (genomic relationship matrix)
# ===========================================================================
cat("\nSection 2: kinship matrix...\n")
geno_kin <- geno_qc
for (i in seq_len(ncol(geno_kin))) {
  miss <- is.na(geno_kin[, i])
  if (any(miss)) geno_kin[miss, i] <- mean(geno_kin[, i], na.rm = TRUE)
}
W <- scale(geno_kin, center = TRUE, scale = FALSE)
K <- tcrossprod(W) / ncol(W)
eig <- eigen(K, symmetric = TRUE)
if (any(eig$values < 0)) {
  eig$values[eig$values < 1e-6] <- 1e-6
  K <- eig$vectors %*% diag(eig$values) %*% t(eig$vectors)
}
K <- K / mean(diag(K))
rownames(K) <- colnames(K) <- rownames(geno_kin)
saveRDS(K, file.path(OUT_DIR, "kinship_matrix.rds"))
cat(sprintf("  K dim: %d x %d\n", nrow(K), ncol(K)))

cat("\nWrote outputs/genetics/marker_qc.csv and outputs/genetics/kinship_matrix.rds\n")
