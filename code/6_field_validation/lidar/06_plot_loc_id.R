# Plot identifiers (Loc_ID) for the Energy Farm LiDAR plots
#
# Purpose
#   Links each SpiderCam LiDAR plot (block and plot number) to the plot identifier used in the
#   paper, Loc_ID = EF_<Pass>_<Range>. The LiDAR crosswalk and the Helios simulation inputs are
#   both keyed by row spacing, pass and range, so the two are joined on that key, and the genotype
#   ID and leaflet type from the two sources are checked for agreement. The Loc_ID keys the
#   per-plot LiDAR metrics of Table S9 to the other per-plot tables.
#
# Inputs
#   outputs/field_validation/lidar/plot_leaftype_crosswalk.csv   LiDAR plot crosswalk
#                                                                 (01_plot_crosswalk.R)
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_EF.csv         per-plot simulation inputs,
#                                                                 Energy Farm (leaf-inputs step)
#
# Outputs
#   outputs/field_validation/lidar/plot_loc_id_crosswalk.csv
#       the LiDAR plot crosswalk with the Loc_ID of each plot simulated with Helios (NA for the
#       check plots)
#
# Usage
#   Rscript code/6_field_validation/lidar/06_plot_loc_id.R   (run from the package root)
#
# Requirements
#   R (4.6.1 used); base R only

options(stringsAsFactors=FALSE, warn=1)

ROOT    <- Sys.getenv("PACKAGE_ROOT", unset = ".")
OUT_DIR <- file.path(ROOT, "outputs", "field_validation", "lidar")
IN_HELIOS <- file.path(ROOT, "outputs", "leaf_inputs", "canopy_inputs_leaf_optics_EF.csv")

cw <- read.csv(file.path(OUT_DIR, "plot_leaftype_crosswalk.csv"))
hz <- read.csv(IN_HELIOS)

# One row per simulated plot with its Loc_ID and genotype, keyed by Spacing|Pass|Range.
hz1 <- unique(hz[, c("Loc_ID","ID","Spacing","Pass","Range","Leaf_type","Line")])
hz1$key <- paste(hz1$Spacing, hz1$Pass, hz1$Range, sep="|")
stopifnot(!any(duplicated(hz1$key)))                 # the key must be unique among simulated plots

cw$key <- paste(cw$spacing, cw$pass, cw$range, sep="|")
cw$Loc_ID   <- hz1$Loc_ID[match(cw$key, hz1$key)]
cw$Loc_geno <- hz1$ID[match(cw$key, hz1$key)]
cw$Loc_leaf <- hz1$Leaf_type[match(cw$key, hz1$key)]

# ---- Coverage and agreement on the simulated (BC3) plots ----
h <- cw[cw$helios %in% c(TRUE,"TRUE"), ]
cat("BC3 LiDAR plots simulated with Helios:", nrow(h), "\n")
cat("  mapped to a Loc_ID :", sum(!is.na(h$Loc_ID)), "\n")
cat("  unmapped (NA)      :", sum(is.na(h$Loc_ID)), "\n")
cat("  Loc_ID unique 1:1  :", !any(duplicated(h$Loc_ID[!is.na(h$Loc_ID)])), "\n")
# Genotype and leaflet type must agree between the two independent sources.
ok <- !is.na(h$Loc_ID)
cat("  genoID agrees      :", sum(as.character(h$genoID[ok])==as.character(h$Loc_geno[ok])), "/", sum(ok), "\n")
cat("  leaf_type agrees   :", sum(h$leaf_type[ok]==h$Loc_leaf[ok]), "/", sum(ok), "\n")
cat("\nBy row spacing (15 = 38 cm, 30 = 76 cm) x leaflet type (mapped plots):\n"); print(table(h$spacing[ok], h$leaf_type[ok]))

cat("\nExamples (Soybean_1, 76-cm rows):\n")
print(head(h[h$block=="Soybean_1" & h$spacing==30, c("block","plot","pass","range","leaf_type","genoID","Loc_ID")], 6), row.names=FALSE)

out <- cw[, c("block","plot","spacing","pass","range","leaf_type","genoID","line","helios","Loc_ID")]
write.csv(out, file.path(OUT_DIR, "plot_loc_id_crosswalk.csv"), row.names=FALSE)
cat(sprintf("\nWrote plot_loc_id_crosswalk.csv (%d rows; %d simulated plots carry a Loc_ID)\n",
            nrow(out), sum(!is.na(out$Loc_ID) & out$helios %in% c(TRUE,"TRUE"))))
