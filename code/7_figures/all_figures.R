# All figures of the article, main and supplementary
#
# Purpose
#   Draws the panels of Figs 1 to 7 and Figs S1 to S8 and writes the statistics and tables behind
#   the numbers quoted with them. Each figure or group of panels is one section below, written as
#   a function, in the order of the article. A section reads its inputs from data/ and outputs/ of
#   the dataset and writes its panels and statistics to outputs/figures/. The Purpose, Inputs and
#   Outputs of every section are given above its function.
#
#   The field maps in Fig 1A-B, the photograph in Fig 1D and the Helios canopy images in Figs 2B
#   and 3E are not produced by code.
#
# Sections
#   fig1c         Fig 1C: Leaf area index time courses of broad- and narrow-leaflet lines at both
#                 sites
#   fig1d         Fig 1D: Leaflet length, maximum width and length-to-maximum-width ratio of broad-
#                 and narrow-leaflet lines
#   fig1cd_stats  Figs 1C-D: Broad-versus-narrow statistics of peak leaf area index and leaflet
#                 dimensions
#   fig2a         Fig 2A: Seasonal course of Helios canopy net photosynthesis by leaflet type, site
#                 and row spacing
#   fig2c         Fig 2C: Narrow-minus-broad difference in Helios canopy net photosynthesis against
#                 mean leaf area index
#   fig2d         Fig 2D: Cumulative share of canopy net photosynthesis against cumulative share of
#                 leaf area from the canopy top
#   fig3ab        Figs 3A-B and S7A-B: Seasonal fAPAR and canopy light-use efficiency of broad- and
#                 narrow-leaflet canopies
#   fig3cd        Figs 3C-D and S7C-D: Vertical and within-layer distribution of absorbed PAR in
#                 broad- and narrow-leaflet canopies
#   fig4a         Fig 4A: Helios three-dimensional against one-dimensional sun-shade canopy net
#                 photosynthesis
#   fig4b         Fig 4B: Narrow-minus-broad canopy net photosynthesis from the one-dimensional and
#                 Helios models and the 3D architectural residual
#   fig5a         Fig 5A: Measured and modeled light profiles against cumulative LAI at SoyFACE
#   fig5b         Fig 5B: SunScan leaf-area profiles of broad- and narrow-leaflet canopies at
#                 SoyFACE
#   fig5c         Fig 5C: LiDAR foliage share by relative canopy height at the Energy Farm, canopy
#                 closure
#   fig5d         Fig 5D: LiDAR return density of one broad- and one narrow-leaflet plot at canopy
#                 closure
#   fig6a         Fig 6A: Slopegraph of per-plot peak leaf area index and grain yield
#   fig6b         Fig 6B: Raincloud plot of per-plot grain yield per unit peak leaf area index
#   fig6b_kgha    Fig 6B values in kg/ha: Yield per unit peak LAI of narrow- versus broad-leaflet
#                 NILs
#   fig6_stats    Fig 6 statistics: Grain yield and yield per unit peak LAI of broad- and
#                 narrow-leaflet NILs
#   fig7a         Fig 7A: Distributions of line BLUPs for the four traits of the association
#                 analysis
#   fig7b         Fig 7B: Manhattan plot of the association scans for the four traits
#   fig7b_qq      Fig 7B inset: Quantile-quantile plot of the Leaflet L:W association scan
#   fig7c         Fig 7C: Standardized per-allele effect at SNP1293 for the four traits
#   figS1         Fig S1: Per-plot plant height, leaf photosynthetic capacity, SPAD and LMA inputs
#   figS2         Fig S2: Per-plot leaflet dimensions of broad- and narrow-leaflet NILs
#   figS3         Fig S3: Per-plot leaf reflectance spectra and PROSPECT-D leaf optical inputs
#   figS4         Fig S4: Daily weather at SoyFACE and the Energy Farm, 1 May to 31 October 2024
#   figS5         Fig S5: Alternative fits of the narrow-minus-broad canopy A difference against
#                 mean LAI
#   figS6         Fig S6: Post-closure fAPAR of broad- and narrow-leaflet NILs and its equivalence
#                 test
#   figS8         Fig S8: Checks on the Helios canopy simulations
#
# Usage
#   Run from the main folder of the dataset.
#     Rscript code/7_figures/all_figures.R                  all sections, in the order above
#     Rscript code/7_figures/all_figures.R fig4a figS4      only the named sections
#     Rscript code/7_figures/all_figures.R --list           print the section names
#   fig2d and fig3cd read the 530 Helios per-leaf files (about 3.3 GB). fig2d needs about 20 GB
#   of memory and runs for about half an hour. fig3cd reads a file written by fig2d, so fig2d has
#   to be run first. The points of Figs 2A and 6B are jittered without a fixed random seed.
#
# Requirements
#   R 4.6.1; packages data.table, dplyr, ggdist, ggnewscale, ggplot2, lubridate, openxlsx,
#   patchwork, readr, readxl, scales, tidyr, cowplot (legend of Fig S8) and ragg 1.5.2 (PNG
#   device of most panels). The supplementary figures are set in Arial.

suppressPackageStartupMessages({
  library(data.table)
  library(openxlsx)
  library(readxl)
  library(lubridate)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(ggnewscale)
  library(scales)
  library(ggdist)
  library(patchwork)
})

options(stringsAsFactors = FALSE, warn = 1)

# Main folder of the dataset. All paths below start from it.
ROOT <- Sys.getenv("PACKAGE_ROOT", unset = ".")

# ==================================================================================================
# Shared look of the supplementary figures (Figs S1 to S6 and S8): sizes, colors, theme and
# layout helpers. Definitions only; nothing is drawn or written here.
# ==================================================================================================

# Sizes (points) at the final figure width.
FIG_W    <- 7
FIG_DPI  <- 600
FONT     <- "Arial"
PT_TICK  <- 8
PT_TITLE <- 10
PT_STRIP <- 8
PT_LEG   <- 8
PT_NOTE  <- 6.5
PT_SITE  <- 8.5
PT_TAG   <- 14
NOTE_MM  <- PT_NOTE / .pt
SITE_MM  <- PT_SITE / .pt
TAG_W    <- 0.30      # width of the panel-letter column, in
TITLE_W  <- 0.36      # width of the y-axis title column (two lines), in
STRIP_H  <- 0.21      # height of a one-line facet header, in

# Leaflet-type and site colors used in all figures.
LEAF_FILL  <- c(Broad = "#FFD700", Narrow = "#00BFFF")
LEAF_LINE  <- c(Broad = "#B8860B", Narrow = "#006D9C")
LEAF_SHAPE <- c(Broad = 21, Narrow = 22)
SITE_COL   <- c("SoyFACE" = "#1F8A8B", "Energy Farm" = "#D17A22")
LEAF_NAME  <- "Leaflet type"
NOTE_COL   <- "gray35"
SITE_GRAY  <- "gray50"

# Site x row spacing labels. The data code row spacing in inches (15 = 38 cm, 30 = 76 cm).
CELL_LEVELS <- c("SoyFACE, 38 cm", "SoyFACE, 76 cm", "Energy Farm, 38 cm", "Energy Farm, 76 cm")
cell_factor <- function(site, spacing) {
  site_name <- ifelse(site %in% c("SF", "SoyFACE"), "SoyFACE", "Energy Farm")
  factor(paste0(site_name, ", ", ifelse(spacing == 15, "38 cm", "76 cm")), levels = CELL_LEVELS)
}

# Axis titles. Words are bold and anything in parentheses is regular weight.
#   ttl("Plant height", "(cm)")     bold words followed by a regular-weight parenthesis
#   ttl("Mean LAI", U$lai)          the parenthesis can be one of the unit expressions below
#   pl("(cm)")                      regular-weight text on its own (second line of a y title)
U <- list(
  flux     = quote(plain("(µmol m"^"−2" * " s"^"−1" * ")")),
  flux_co2 = quote(plain("(µmol CO"[2] * " m"^"−2" * " s"^"−1" * ")")),
  g_m2     = quote(plain("(g m"^"−2" * ")")),
  ug_cm2   = quote(plain("(µg cm"^"−2" * ")")),
  cm2      = quote(plain("(cm"^"2" * ")")),
  lai      = quote(plain("(m"^"2" * " m"^"−2" * ")")),
  kw_m2    = quote(plain("(kW m"^"−2" * ")")),
  m_s      = quote(plain("(m s"^"−1" * ")")))
ttl <- function(words, paren = NULL) {
  if (is.null(paren)) return(bquote(bold(.(words))))
  if (is.character(paren)) return(bquote(bold(.(words)) * plain(.(paste0(" ", paren)))))
  bquote(bold(.(words)) * " " * .(paren))
}
pl <- function(text) bquote(plain(.(text)))

supp_theme <- theme_minimal(base_size = PT_TICK, base_family = FONT) +
  theme(
    text              = element_text(family = FONT, color = "black"),
    axis.title        = element_text(size = PT_TITLE, face = "bold", color = "black"),
    axis.title.x      = element_text(margin = margin(t = 3)),
    axis.title.y      = element_blank(),
    axis.text         = element_text(size = PT_TICK, color = "black"),
    axis.ticks        = element_line(color = "black", linewidth = 0.35),
    axis.ticks.length = unit(0.07, "cm"),
    panel.grid.major  = element_line(color = "gray92", linewidth = 0.25),
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(color = "black", fill = NA, linewidth = 0.6),
    panel.background  = element_rect(fill = "white", color = NA),
    plot.background   = element_rect(fill = "white", color = NA),
    panel.spacing     = unit(0.09, "in"),
    strip.background  = element_rect(fill = "gray95", color = "black", linewidth = 0.4),
    strip.text        = element_text(size = PT_STRIP, face = "bold", color = "black",
                                     margin = margin(2.5, 1, 2.5, 1)),
    legend.position   = "top",
    legend.title      = element_text(size = PT_LEG, face = "bold", margin = margin(r = 5)),
    legend.text       = element_text(size = PT_LEG),
    legend.key.size   = unit(0.15, "in"),
    legend.key.spacing.x = unit(0.06, "in"),
    legend.margin     = margin(0, 0, 0, 0),
    legend.box.margin = margin(0, 0, -3, 0),
    plot.margin       = margin(3, 4, 3, 0)
  )

# Switches used by the panel builders. Facet headers and x tick labels are shown once per
# figure column, so stacked panels drop them.
no_strips  <- theme(strip.text = element_blank(), strip.background = element_blank())
no_xlabels <- theme(axis.text.x = element_blank())
no_xtitle  <- theme(axis.title.x = element_blank())
no_legend  <- theme(legend.position = "none")

# Box plot of one per-plot trait by leaflet type, one facet per site x row spacing
# combination, with jittered plots and the number of plots above each box. The data need
# the columns Cell and Leaf_type. The plot numbers are attached to the returned plot as the
# attribute "plot_numbers".
box_panel <- function(d, y_col, strips = FALSE, xlabels = FALSE, notes = TRUE) {
  d   <- d[is.finite(d[[y_col]]), ]
  rng <- diff(range(d[[y_col]]))
  nl  <- aggregate(d[[y_col]], d[c("Cell", "Leaf_type")],
                   function(v) c(n = length(v), top = max(v)))
  nl  <- data.frame(nl[c("Cell", "Leaf_type")], n_plots = nl$x[, "n"],
                    y = nl$x[, "top"] + 0.04 * rng)
  p <- ggplot(d, aes(x = Leaf_type, y = .data[[y_col]], fill = Leaf_type, color = Leaf_type)) +
    geom_boxplot(width = 0.55, outlier.shape = NA, alpha = 0.55, linewidth = 0.35,
                 key_glyph = "polygon") +
    geom_point(position = position_jitter(width = 0.18, height = 0, seed = 42), size = 0.85,
               alpha = 0.85, shape = 21, stroke = 0.22, color = "black", show.legend = FALSE) +
    scale_fill_manual(values = LEAF_FILL, name = LEAF_NAME) +
    scale_color_manual(values = LEAF_LINE, name = LEAF_NAME) +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.16)), n.breaks = 4) +
    facet_wrap(~ Cell, nrow = 1) +
    labs(x = NULL, y = NULL) +
    supp_theme
  if (notes) p <- p + geom_text(data = nl,
                                aes(x = Leaf_type, y = y, label = paste0("n = ", n_plots)),
                                size = NOTE_MM, family = FONT, color = "black", vjust = 0,
                                inherit.aes = FALSE)
  if (!strips)  p <- p + no_strips
  if (!xlabels) p <- p + no_xlabels
  attr(p, "plot_numbers") <- data.frame(Cell = nl$Cell, Leaf_type = nl$Leaf_type,
                                        n = nl$n_plots)
  p
}

# Site or model name written inside a panel in gray bold, as in the main figures.
inside_label <- function(label, x = -Inf, y = Inf, hjust = -0.08, vjust = 1.6) {
  annotate("text", x = x, y = y, label = label, hjust = hjust, vjust = vjust, size = SITE_MM,
           family = FONT, fontface = "bold", color = SITE_GRAY)
}

# Figure assembly. A panel is laid out as three cells in a row. These are its letter, its
# y-axis title (one or two lines, drawn here so that the two lines sit close together) and
# the plot. The letter sits at the top of the panel, raised by `lift` inches where the panel
# has a facet header.
tag_cell <- function(letter, lift = 0) {
  wrap_elements(
    panel = grid::textGrob(sprintf("(%s)", letter), x = unit(0, "npc"),
                           y = unit(1, "npc") + unit(lift + 0.03, "in"), hjust = 0, vjust = 1,
                           gp = grid::gpar(fontfamily = FONT, fontface = "bold",
                                           fontsize = PT_TAG)),
    clip = FALSE)
}
title_cell <- function(line1, line2 = NULL) {
  as_lab <- function(x) {
    if (is.character(x)) as.expression(bquote(bold(.(x)))) else as.expression(x)
  }
  gp <- grid::gpar(fontfamily = FONT, fontsize = PT_TITLE, col = "black")
  lh <- unit(PT_TITLE * 1.25, "pt")
  g <- if (is.null(line2)) {
    grid::textGrob(as_lab(line1), rot = 90, gp = gp)
  } else {
    grid::grobTree(
      grid::textGrob(as_lab(line1), x = unit(0.5, "npc") - 0.5 * lh, rot = 90, gp = gp),
      grid::textGrob(as_lab(line2), x = unit(0.5, "npc") + 0.5 * lh, rot = 90, gp = gp))
  }
  wrap_elements(panel = g, clip = FALSE)
}
# One panel as a list of cells. `title` is a list of one or two lines.
panel_cells <- function(letter, title, plot, lift = 0) {
  list(tag_cell(letter, lift), do.call(title_cell, title, quote = TRUE), plot)
}
# Stack panels (each a list from panel_cells) in `ncol` columns of panels, with the legends
# of all panels collected into one row at the top.
assemble <- function(panels, ncol = 1, heights = NULL, tag_w = TAG_W, title_w = TITLE_W,
                     collect = TRUE) {
  cells  <- do.call(c, panels)
  widths <- rep(unit(c(tag_w, title_w, 1), c("in", "in", "null")), ncol)
  p <- wrap_plots(cells, ncol = 3 * ncol, widths = widths, heights = heights)
  if (collect) p <- p + plot_layout(guides = "collect") & theme(legend.position = "top")
  p
}
# A single panel with its y title, without a letter.
single_panel <- function(title, plot, title_w = TITLE_W) {
  wrap_plots(do.call(title_cell, title, quote = TRUE), plot, nrow = 1,
             widths = unit(c(title_w, 1), c("in", "null")))
}

# Write a plot to a PNG file of the given size in inches.
save_png <- function(plot, file, height, width = FIG_W) {
  ragg::agg_png(file, width = width, height = height, units = "in", res = FIG_DPI,
                background = "white")
  print(plot)
  invisible(dev.off())
  cat("Wrote", file, "\n")
}
# Figure made of separately assembled rows, each drawn in its own band of the given height.
save_rows <- function(rows, heights, file, width = FIG_W) {
  ragg::agg_png(file, width = width, height = sum(heights), units = "in", res = FIG_DPI,
                background = "white")
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(
    layout = grid::grid.layout(length(rows), 1, heights = unit(heights, "in"))))
  for (i in seq_along(rows)) {
    vp <- grid::viewport(layout.pos.row = i, layout.pos.col = 1)
    if (inherits(rows[[i]], "grob")) {
      grid::pushViewport(vp)
      grid::grid.draw(rows[[i]])
      grid::popViewport()
    } else {
      print(rows[[i]], vp = vp, newpage = FALSE)
    }
  }
  grid::popViewport()
  invisible(dev.off())
  cat("Wrote", file, "\n")
}
# Legend of a plot as a drawable object, for figures assembled from rows. The legend text is
# measured with the device that draws it.
legend_of <- function(plot) {
  cowplot::set_null_device("agg")
  cowplot::get_plot_component(plot + theme(legend.position = "top"), "guide-box-top")
}

# Single panels, drawn on their own canvas with their own facet headers, x labels and
# legend. A panel with numbers written inside the plot is saved with and without them, as
# <stem>_annotated.png and <stem>_not_annotated.png. A panel without such numbers is saved
# as <stem>.png. `make(notes)` returns the complete panel and `stem` is the file path
# without its ending.
save_panel <- function(make, stem, height, width = FIG_W, has_notes = TRUE) {
  if (has_notes) {
    save_png(make(TRUE),  paste0(stem, "_annotated.png"), height, width)
    save_png(make(FALSE), paste0(stem, "_not_annotated.png"), height, width)
  } else {
    save_png(make(TRUE), paste0(stem, ".png"), height, width)
  }
}

# ==================================================================================================
# Section fig1c
# Fig 1C: Leaf area index time courses of broad- and narrow-leaflet lines at both sites
# ==================================================================================================
#
# Purpose
#   Draws the per-plot leaf area index (LAI) measured with the SunScan on each date against days
#   after planting (DAP). Broad- and narrow-leaflet plots are shown as side-by-side box plots at
#   each date, over shaded vegetative, reproductive and maturity stages. One panel is drawn for
#   each site, and the two panels make up Fig. 1C. The statistics quoted with Fig. 1C are written
#   by section fig1cd_stats.
#
# Inputs
#   data/field/SF/LAI_per_plot_per_DAP.csv                  SoyFACE per-plot LAI on each date
#   data/field/EF/LAI_per_plot_per_DAP.csv                  Energy Farm per-plot LAI on each date
#   data/field/{SF,EF}/leaflet_morphometrics_per_plot.csv   leaflet type of each plot, used where
#                                                           the LAI file has no Leaf_type column
#
# Outputs
#   outputs/figures/Figure1/Fig1C_LAI_SF.png                Fig. 1C, SoyFACE panel
#   outputs/figures/Figure1/Fig1C_LAI_EF.png                Fig. 1C, Energy Farm panel

fig1c <- function() {
  FIELD_DIR <- file.path(ROOT, "data", "field")
  OUT <- file.path(ROOT, "outputs", "figures", "Figure1")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type colors, shared by all figures of the paper.
  BROAD_COL  <- "#FFD700"   # gold
  NARROW_COL <- "#00BFFF"   # deep sky blue
  LEAF_COLS  <- c("Broad" = BROAD_COL, "Narrow" = NARROW_COL)

  # Growth-stage bands in days after planting. The vegetative stage ends at DAP 48 and the
  # reproductive stage at DAP 82. The bands are shaded and their boundaries dashed.
  stage_boundaries <- data.frame(
    Stage = factor(c("Vegetative", "Reproductive", "Maturity"),
                   levels = c("Vegetative", "Reproductive", "Maturity")),
    xmin = c(10, 48, 82),
    xmax = c(48, 82, 130)
  )
  STAGE_COLS <- c("Vegetative"   = "#009E73",
                  "Reproductive" = "#F0E442",
                  "Maturity"     = "#D55E00")
  BG_ALPHA <- 0.1

  # Publication theme with large bold axis titles, a light grid and a black panel border.
  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(size = 18, face = "bold", hjust = 0.5,
                                      margin = margin(b = 6)),
      axis.title.x     = element_text(size = 20, face = "bold", color = "black",
                                      margin = margin(t = 6)),
      axis.title.y     = element_text(size = 20, color = "black",
                                      margin = margin(r = 4)),
      axis.text.x      = element_text(size = 16, color = "black"),
      axis.text.y      = element_text(size = 16, color = "black"),
      axis.ticks       = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length = unit(0.2, "cm"),
      panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor   = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background   = element_rect(fill = "white"),
      plot.background    = element_rect(fill = "white", color = NA),
      strip.background   = element_rect(fill = "#F0F0F0", color = NA),
      strip.text         = element_text(face = "bold", size = 14, color = "black"),
      legend.position    = "top",
      legend.title       = element_text(face = "bold", size = 14),
      legend.text        = element_text(size = 13),
      plot.margin        = margin(10, 14, 10, 10)
    )

  # Read the per-plot LAI of one site. The Energy Farm file has no plot identifier or leaflet
  # type. Its plot identifier is built from the field position as <site>_<Pass>_<Range>, and its
  # leaflet type is taken from the leaflet morphometrics file of the same site. Only broad- and
  # narrow-leaflet plots with an LAI value are kept.
  read_lai_with_leaf <- function(site) {
    fp <- file.path(FIELD_DIR, site, "LAI_per_plot_per_DAP.csv")
    d <- read_csv(fp, show_col_types = FALSE)
    if (!"Loc_ID" %in% names(d)) {
      d <- d %>% mutate(Loc_ID = paste(site, Pass, Range, sep = "_"),
                         Location = site)
    }
    if (!"Leaf_type" %in% names(d)) {
      morph_lookup <- read_csv(
        file.path(FIELD_DIR, site, "leaflet_morphometrics_per_plot.csv"),
        show_col_types = FALSE) %>%
        select(Loc_ID, Leaf_type) %>% distinct()
      d <- d %>% left_join(morph_lookup, by = "Loc_ID")
    }
    d %>%
      rename(Site = Location, LAI = LAI_m2_m2) %>%
      select(Site, Loc_ID, Spacing, Leaf_type, DAP, LAI) %>%
      filter(!is.na(LAI), !is.na(Leaf_type), Leaf_type %in% c("Broad","Narrow")) %>%
      mutate(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")))
  }
  lai_sf <- read_lai_with_leaf("SF")
  lai_ef <- read_lai_with_leaf("EF")
  cat(sprintf("LAI rows: SF=%d (DAPs %d), EF=%d (DAPs %d)\n",
              nrow(lai_sf), n_distinct(lai_sf$DAP),
              nrow(lai_ef), n_distinct(lai_ef$DAP)))

  # Build one LAI panel. The x axis is continuous DAP, so the box width is set from the typical
  # spacing between measurement dates, and the two leaflet types are dodged at each date. A second
  # fill scale (ggnewscale) separates the stage shading from the leaflet-type fill.
  build_lai <- function(d, site_label) {
    dap_range <- range(d$DAP)
    x_lo <- min(10, dap_range[1] - 4)
    x_hi <- max(115, dap_range[2] + 4)
    y_hi <- ceiling(max(d$LAI, na.rm = TRUE) + 0.5)

    daps <- sort(unique(d$DAP))
    typical_gap <- if (length(daps) >= 2) median(diff(daps)) else 6
    box_w   <- max(2.0, typical_gap * 0.30)
    dodge_w <- box_w * 1.10

    ggplot() +
      geom_rect(data = stage_boundaries,
                aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf,
                    fill = Stage), alpha = BG_ALPHA) +
      scale_fill_manual(values = STAGE_COLS, guide = "none") +
      geom_vline(xintercept = c(48, 82), linetype = "dashed",
                 color = "gray40", linewidth = 0.6, alpha = 0.7) +
      ggnewscale::new_scale_fill() +
      geom_boxplot(data = d,
                   aes(x = DAP, y = LAI, fill = Leaf_type,
                       group = interaction(DAP, Leaf_type)),
                   width = box_w, linewidth = 0.4, color = "black",
                   outlier.shape = 21, outlier.fill = "white",
                   outlier.size = 1.0, outlier.stroke = 0.4,
                   position = position_dodge(width = dodge_w)) +
      scale_fill_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_x_continuous(breaks = seq(20, 120, by = 20),
                         limits = c(x_lo, x_hi), expand = c(0.01, 0)) +
      scale_y_continuous(breaks = seq(0, y_hi, by = 2),
                         limits = c(0, y_hi), expand = c(0.01, 0)) +
      labs(title = site_label,
           x = "Days After Planting (DAP)",
           y = expression(bold("LAI") ~ "(" * m^2 ~ m^-2 * ")")) +
      pub_theme
  }

  ggsave(file.path(OUT, "Fig1C_LAI_SF.png"),
         build_lai(lai_sf, "SoyFACE (SF)"),
         width = 8, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)
  ggsave(file.path(OUT, "Fig1C_LAI_EF.png"),
         build_lai(lai_ef, "Energy Farm (EF)"),
         width = 8, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)

  cat("Wrote Fig1C_LAI_SF.png and Fig1C_LAI_EF.png to ", OUT, "\n", sep = "")
}

# ==================================================================================================
# Section fig1d
# Fig 1D: Leaflet length, maximum width and length-to-maximum-width ratio of broad- and
# narrow-leaflet lines
# ==================================================================================================
#
# Purpose
#   Draws raincloud plots of the per-plot leaflet length, maximum width and length-to-maximum-
#   width (L:W) ratio of the 530 simulated plots of both sites (266 broad, 264 narrow). Each
#   raincloud combines a half-violin density, jittered plot values and a box plot. The three
#   panels are the lower row of Fig. 1D. The leaflet-type means quoted in the Results (length,
#   maximum width and L:W) are printed to the console.
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_{SF,EF}.csv   per-plot simulation inputs,
#                                                                       one leaflet measurement per plot
#
# Outputs
#   outputs/figures/Figure1/Fig1D_leaflet_length.png       Fig. 1D, leaflet length
#   outputs/figures/Figure1/Fig1D_leaflet_max_width.png    Fig. 1D, leaflet maximum width
#   outputs/figures/Figure1/Fig1D_leaflet_LW_ratio.png     Fig. 1D, length / maximum width

fig1d <- function() {
  set.seed(42)

  INP <- file.path(ROOT, "data", "simulation_inputs")
  OUT <- file.path(ROOT, "outputs", "figures", "Figure1")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type fill colors (shared by all figures) and darker point colors.
  LEAF_FILL <- c(Broad = "#FFD700", Narrow = "#00BFFF")
  LEAF_LINE <- c(Broad = "#B8860B", Narrow = "#006D9C")
  pub_theme <- theme_minimal(base_size = 12) + theme(
    axis.title.x = element_text(size = 18, face = "bold", color = "black", margin = margin(t = 6)),
    axis.title.y = element_text(size = 18, face = "bold", color = "black", margin = margin(r = 4)),
    axis.text = element_text(size = 14, color = "black"),
    axis.ticks = element_line(color = "black", linewidth = 0.8), axis.ticks.length = unit(0.2, "cm"),
    panel.grid.major = element_line(color = "gray90", linewidth = 0.3), panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 1.0),
    panel.background = element_rect(fill = "white"), plot.background = element_rect(fill = "white", color = NA),
    legend.position = "none", plot.margin = margin(10, 14, 10, 10))

  # One row per plot (530 near-isogenic line plots).
  # The simulation inputs repeat the leaflet measurement of a plot on every date, so the first row
  # of each plot is kept. The leaf_ratio_LR column of the inputs is length / average width. The
  # L:W ratio of the paper is length / maximum width and is computed here as LW_max.
  rd <- function(site) {
    x <- read.csv(file.path(INP, sprintf("canopy_inputs_per_plot_per_DAP_%s.csv", site)))
    x[x$Leaf_type %in% c("Broad", "Narrow"), c("Loc_ID", "Leaf_type", "length_m", "avwidth_m", "mxwidth_m", "leaf_ratio_LR")]
  }
  m <- rbind(rd("SF"), rd("EF"))
  m <- m[!duplicated(m$Loc_ID), ]
  stopifnot(nrow(m) == 530, sum(m$Leaf_type == "Broad") == 266, !anyNA(m[c("length_m", "mxwidth_m")]),
            isTRUE(all.equal(m$leaf_ratio_LR, m$length_m / m$avwidth_m)))
  m$length_cm  <- m$length_m * 100
  m$mxwidth_cm <- m$mxwidth_m * 100
  m$LW_max     <- m$length_m / m$mxwidth_m
  m$Leaf_type  <- factor(m$Leaf_type, levels = c("Narrow", "Broad"))
  s <- aggregate(cbind(length_cm, mxwidth_cm, LW_max) ~ Leaf_type, m, mean)
  cat(sprintf("%s: n = %d, length %.2f cm, maximum width %.2f cm, length / maximum width %.2f\n",
              s$Leaf_type, as.vector(table(m$Leaf_type)[as.character(s$Leaf_type)]), s$length_cm, s$mxwidth_cm, s$LW_max), sep = "")

  # Raincloud panels with the half-violin drawn to the right of each box.
  # The density of each leaflet type uses the Sheather-Jones plug-in bandwidth with adjust = 0.6,
  # trimmed to the data range, as in ggdist::stat_halfeye(adjust = 0.6, justification = -0.18).
  # Both densities are scaled to a common maximum and drawn as polygons.
  half_violin <- function(d, col, scale = 0.9, shift = 0.18) {
    ds <- lapply(split(d[[col]], d$Leaf_type), function(v) {
      k <- density(v, bw = "SJ", adjust = 0.6, from = min(v), to = max(v), n = 512)
      data.frame(y = k$x, dens = k$y)
    })
    top <- max(vapply(ds, function(z) max(z$dens), 0))                  # common scale across leaflet types
    do.call(rbind, lapply(names(ds), function(g) {
      z <- ds[[g]]; x0 <- match(g, levels(d$Leaf_type)) + shift * scale
      data.frame(Leaf_type = g, x = c(x0, x0 + scale * z$dens / top, x0), y = c(z$y[1], z$y, z$y[nrow(z)]))
    }))
  }
  raincloud <- function(d, col, y_label) {
    hv <- half_violin(d, col)
    hv$Leaf_type <- factor(hv$Leaf_type, levels = levels(d$Leaf_type))
    ggplot(d, aes(x = Leaf_type, y = .data[[col]])) +
      geom_polygon(data = hv, aes(x = x, y = y, fill = Leaf_type, group = Leaf_type),
                   color = "gray15", linewidth = 0.4, alpha = 0.8, inherit.aes = FALSE) +
      geom_jitter(aes(color = Leaf_type), width = 0.07, height = 0, alpha = 0.45, size = 0.9, shape = 16) +
      geom_boxplot(width = 0.14, outlier.shape = NA, fill = "white", color = "black", linewidth = 0.5, alpha = 0.85) +
      scale_fill_manual(values = LEAF_FILL) + scale_color_manual(values = LEAF_LINE) +
      scale_x_discrete(expand = expansion(add = c(0.6, 1.2))) +
      expand_limits(y = 0) +
      labs(x = "Leaflet type", y = y_label) + pub_theme
  }

  # The jitter is drawn when each panel is saved, so the panels are saved in a fixed order after
  # the seed is set.
  panels <- list(
    Fig1D_leaflet_length.png    = raincloud(m, "length_cm",  expression(bold("Leaflet length") ~ "(cm)")),
    Fig1D_leaflet_max_width.png = raincloud(m, "mxwidth_cm", expression(bold("Leaflet maximum width") ~ "(cm)")),
    Fig1D_leaflet_LW_ratio.png  = raincloud(m, "LW_max",     expression(bold("L:W ratio"))))
  for (f in names(panels)) ggsave(file.path(OUT, f), panels[[f]], width = 4.5, height = 4.5, dpi = 300, bg = "white", device = ragg::agg_png)
  cat("Wrote", paste(names(panels), collapse = ", "), "to", OUT, "\n")
}

# ==================================================================================================
# Section fig1cd_stats
# Figs 1C-D: Broad-versus-narrow statistics of peak leaf area index and leaflet dimensions
# ==================================================================================================
#
# Purpose
#   Compares broad- and narrow-leaflet plots for the ground-truth traits of Figure 1 and writes
#   the results to one text file. Each comparison reports n, median, interquartile range,
#   mean and SD, Cohen's d (broad minus narrow, pooled SD), a two-sided Wilcoxon rank-sum test
#   and a Welch t-test. Peak LAI is each plot's maximum LAI over the season, tested per site,
#   so that each plot contributes one value (Fig. 1C). Leaflet length, average width and length /
#   average width are tested on per-plot values pooled across sites. The peak LAI and leaflet
#   length values support the Results text on Fig. 1C and 1D.
#
# Inputs
#   data/field/{SF,EF}/LAI_per_plot_per_DAP.csv             per-plot LAI on each date
#   data/field/{SF,EF}/leaflet_morphometrics_per_plot.csv   per-plot leaflet dimensions and
#                                                           leaflet type
#
# Outputs
#   outputs/figures/Figure1/Fig1CD_stats.txt                statistics for Fig. 1C (peak LAI by
#                                                           site) and Fig. 1D (leaflet dimensions)

fig1cd_stats <- function() {
  FIELD_DIR <- file.path(ROOT, "data", "field")
  OUT <- file.path(ROOT, "outputs", "figures", "Figure1")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
  out_txt <- file.path(OUT, "Fig1CD_stats.txt")

  # Format a P value, with scientific notation below 0.001.
  fmt_p <- function(p) {
    if (is.na(p)) return("P = NA")
    if (p < 1e-10) return(sprintf("P < 1e-10 (%.2e)", p))
    if (p < 0.001) return(sprintf("P < 0.001 (%.2e)", p))
    if (p < 0.01)  return(sprintf("P = %.4f", p))
    return(sprintf("P = %.3f", p))
  }

  # Summary statistics and tests for one narrow-versus-broad comparison. Cohen's d uses the pooled
  # SD, with a positive sign when broad exceeds narrow. In R 4.6.1, wilcox.test returns P = 0 when
  # P falls below about 1e-16 and the first (narrow) sample is the larger. Such values print as
  # "P < 1e-10 (0.00e+00)".
  contrast_stats <- function(narrow_vals, broad_vals) {
    n_n <- length(narrow_vals); n_b <- length(broad_vals)
    med_n <- median(narrow_vals); med_b <- median(broad_vals)
    q_n   <- quantile(narrow_vals, c(0.25, 0.75))
    q_b   <- quantile(broad_vals,  c(0.25, 0.75))
    m_n   <- mean(narrow_vals);   m_b <- mean(broad_vals)
    s_n   <- sd(narrow_vals);     s_b <- sd(broad_vals)
    pooled <- sqrt(((n_n - 1)*s_n^2 + (n_b - 1)*s_b^2) / (n_n + n_b - 2))
    d   <- (m_b - m_n) / pooled
    wt  <- suppressWarnings(wilcox.test(narrow_vals, broad_vals))
    tt  <- suppressWarnings(t.test(narrow_vals, broad_vals))
    list(n_n = n_n, n_b = n_b,
         med_n = med_n, med_b = med_b,
         q_n = q_n, q_b = q_b,
         mean_n = m_n, mean_b = m_b,
         sd_n = s_n, sd_b = s_b,
         d = d,
         wilcox_p = wt$p.value,
         t_p = tt$p.value)
  }

  # Write one comparison block to the statistics file.
  print_block <- function(con, title, s, units = "") {
    cat(sprintf("--- %s ---\n", title), file = con, append = TRUE)
    cat(sprintf("  n          : Narrow = %d, Broad = %d (total %d)\n",
                s$n_n, s$n_b, s$n_n + s$n_b), file = con, append = TRUE)
    cat(sprintf("  Median     : Narrow = %.3f%s, Broad = %.3f%s\n",
                s$med_n, units, s$med_b, units), file = con, append = TRUE)
    cat(sprintf("  IQR (Q1-Q3): Narrow = [%.3f, %.3f]%s, Broad = [%.3f, %.3f]%s\n",
                s$q_n[1], s$q_n[2], units,
                s$q_b[1], s$q_b[2], units), file = con, append = TRUE)
    cat(sprintf("  Mean ± SD  : Narrow = %.3f ± %.3f%s, Broad = %.3f ± %.3f%s\n",
                s$mean_n, s$sd_n, units, s$mean_b, s$sd_b, units),
        file = con, append = TRUE)
    cat(sprintf("  Cohen's d  : %+.2f  (Broad - Narrow / pooled SD)\n", s$d),
        file = con, append = TRUE)
    cat(sprintf("  Wilcoxon   : %s\n", fmt_p(s$wilcox_p)), file = con, append = TRUE)
    cat(sprintf("  Welch t    : %s\n", fmt_p(s$t_p)),      file = con, append = TRUE)
    cat("\n", file = con, append = TRUE)
  }

  # Read the leaflet morphometrics of both sites (one row per plot) and keep the broad- and
  # narrow-leaflet plots. Lengths and widths are converted from m to cm.
  read_morph <- function(site) {
    read_csv(file.path(FIELD_DIR, site, "leaflet_morphometrics_per_plot.csv"),
             show_col_types = FALSE) %>%
      select(any_of(c("Loc_ID","Pass","Range","Location","Spacing","Leaf_type",
                      "length_m","avwidth_m","leaf_ratio_LR"))) %>%
      rename(Site = Location)
  }
  morph <- bind_rows(read_morph("SF"), read_morph("EF")) %>%
    filter(Leaf_type %in% c("Broad","Narrow")) %>%
    mutate(length_cm  = length_m * 100,
           avwidth_cm = avwidth_m * 100)

  # Read the per-plot LAI of one site. The Energy Farm file has no plot identifier or leaflet
  # type. Its plot identifier is built from the field position as <site>_<Pass>_<Range>, and its
  # leaflet type is taken from the leaflet morphometrics file of the same site.
  read_lai <- function(site) {
    fp <- file.path(FIELD_DIR, site, "LAI_per_plot_per_DAP.csv")
    d <- read_csv(fp, show_col_types = FALSE)
    if (!"Loc_ID" %in% names(d)) {
      d <- d %>% mutate(Loc_ID = paste(site, Pass, Range, sep = "_"),
                         Location = site)
    }
    if (!"Leaf_type" %in% names(d)) {
      morph_lookup <- read_csv(
        file.path(FIELD_DIR, site, "leaflet_morphometrics_per_plot.csv"),
        show_col_types = FALSE) %>%
        select(Loc_ID, Leaf_type) %>% distinct()
      d <- d %>% left_join(morph_lookup, by = "Loc_ID")
    }
    d %>%
      rename(Site = Location, LAI = LAI_m2_m2) %>%
      select(Site, Loc_ID, Spacing, Leaf_type, DAP, LAI) %>%
      filter(!is.na(LAI), !is.na(Leaf_type), Leaf_type %in% c("Broad","Narrow"))
  }
  lai_sf <- read_lai("SF")
  lai_ef <- read_lai("EF")

  # File header.
  con <- file(out_txt, open = "w")
  cat("================================================================================\n",
      file = con)
  cat("Figure 1 panel statistics (Fig 1C and 1D).\n", file = con)
  cat("Source data: data/field/{SF,EF}/{LAI_per_plot_per_DAP, leaflet_morphometrics_per_plot}.csv\n",
      file = con)
  cat("Test conventions: Wilcoxon rank-sum (primary); Welch's t (reported for comparison).\n",
      file = con)
  cat("Cohen's d sign: positive means Broad > Narrow.\n", file = con)
  cat("================================================================================\n\n",
      file = con)
  close(con)

  con <- file(out_txt, open = "a")

  # Fig. 1C. Per-plot peak LAI by site, so that each plot contributes one value.
  cat("################################################################################\n",
      file = con)
  cat("PANEL C — LAI vs DAP\n", file = con)
  cat("Test: Wilcoxon on per-plot peak LAI (one observation per plot).\n", file = con)
  cat("Why peak LAI: avoids pseudo-replication from multiple DAPs per plot.\n",
      file = con)
  cat("################################################################################\n\n",
      file = con)

  for (site_lab in c("SoyFACE (SF)", "Energy Farm (EF)")) {
    d <- if (grepl("SF", site_lab)) lai_sf else lai_ef
    peak_per_plot <- d %>%
      group_by(Loc_ID, Leaf_type) %>%
      summarize(peak = max(LAI, na.rm = TRUE), .groups = "drop")
    narrow_peak <- peak_per_plot$peak[peak_per_plot$Leaf_type == "Narrow"]
    broad_peak  <- peak_per_plot$peak[peak_per_plot$Leaf_type == "Broad"]
    s <- contrast_stats(narrow_peak, broad_peak)
    print_block(con, sprintf("%s — per-plot peak LAI (m^2 m^-2)", site_lab), s,
                units = "")
    # Number of measurement dates and plot-date rows behind the peak values.
    cat(sprintf("  Coverage   : %d distinct DAPs, %d plot-DAP rows\n\n",
                n_distinct(d$DAP), nrow(d)), file = con)
  }

  # Fig. 1D. Leaflet length, average width and length / average width, pooled across sites.
  # The Fig. 1D panels plot maximum width and length / maximum width (section fig1d).
  cat("################################################################################\n",
      file = con)
  cat("PANEL D — leaflet morphology (length, average width, length / average width)\n", file = con)
  cat("Test: Wilcoxon rank-sum on per-plot values, pooled across SF + EF.\n",
      file = con)
  cat("################################################################################\n\n",
      file = con)

  morph_panel <- morph %>% filter(!is.na(length_cm), !is.na(avwidth_cm),
                                   !is.na(leaf_ratio_LR))

  for (trait_info in list(
        list(name = "Leaflet length", col = "length_cm",     units = " cm"),
        list(name = "Leaflet average width", col = "avwidth_cm", units = " cm"),
        list(name = "L:W ratio (length / average width)", col = "leaf_ratio_LR", units = ""))) {
    narrow_vals <- morph_panel[[trait_info$col]][morph_panel$Leaf_type == "Narrow"]
    broad_vals  <- morph_panel[[trait_info$col]][morph_panel$Leaf_type == "Broad"]
    s <- contrast_stats(narrow_vals, broad_vals)
    print_block(con, trait_info$name, s, units = trait_info$units)
  }

  close(con)
  cat(sprintf("Wrote: %s\n", out_txt))
}

# ==================================================================================================
# Section fig2a
# Fig 2A: Seasonal course of Helios canopy net photosynthesis by leaflet type, site and row spacing
# ==================================================================================================
#
# Purpose
#   Draws Helios-predicted canopy net photosynthesis (canopy A) against days after planting (DAP)
#   for each site and row spacing. Small jittered points are plots, and lines and ribbons are the
#   means and standard errors of plots of each leaflet type on each date, over shaded growth
#   stages. The four panels make up Fig. 2A. For each panel, per-plot peak canopy A (the maximum
#   over dates) is compared between leaflet types by a two-sided Wilcoxon rank-sum test and
#   Cohen's d (broad minus narrow, pooled SD). These give the n, P and d values of Fig. 2A and the
#   peak canopy A comparisons in the Results.
#
# Inputs
#   outputs/helios/helios_canopy_summary_{SF,EF}.csv   Helios canopy summary, one row per
#                                                      plot and date (simulation group)
#
# Outputs
#   outputs/figures/Figure2/Fig2A_canopy_A_<site>_<rows>.png         Fig. 2A panels for SF and EF
#                                                                    in 38-cm and 76-cm rows
#   outputs/figures/Figure2/Fig2A_canopy_A_stats_<site>_<rows>.txt   peak canopy A statistics of
#                                                                    each panel

fig2a <- function() {
  HELIOS_DIR <- file.path(ROOT, "outputs", "helios")
  OUT        <- file.path(ROOT, "outputs", "figures", "Figure2")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type colors, shared by all figures of the paper.
  BROAD_COL  <- "#FFD700"
  NARROW_COL <- "#00BFFF"
  LEAF_COLS  <- c("Broad" = BROAD_COL, "Narrow" = NARROW_COL)

  # Growth-stage bands in days after planting, as in Fig. 1C.
  stage_boundaries <- data.frame(
    Stage = factor(c("Vegetative", "Reproductive", "Maturity"),
                   levels = c("Vegetative", "Reproductive", "Maturity")),
    xmin = c(10, 48, 82),
    xmax = c(48, 82, 120)
  )
  STAGE_COLS <- c("Vegetative"   = "#009E73",
                  "Reproductive" = "#F0E442",
                  "Maturity"     = "#D55E00")
  BG_ALPHA <- 0.10

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title         = element_text(size = 18, face = "bold", hjust = 0.5,
                                        margin = margin(b = 6)),
      axis.title.x       = element_text(size = 20, face = "bold", color = "black",
                                        margin = margin(t = 6)),
      axis.title.y       = element_text(size = 20, color = "black",
                                        margin = margin(r = 4)),
      axis.text.x        = element_text(size = 16, color = "black"),
      axis.text.y        = element_text(size = 16, color = "black"),
      axis.ticks         = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length  = unit(0.2, "cm"),
      panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor   = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background   = element_rect(fill = "white"),
      plot.background    = element_rect(fill = "white", color = NA),
      legend.position    = "top",
      legend.title       = element_text(face = "bold", size = 14),
      legend.text        = element_text(size = 13),
      plot.margin        = margin(10, 14, 10, 10)
    )

  # Read the canopy summaries of both sites and keep the broad- and narrow-leaflet plot-dates
  # with a canopy A value.
  ef <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_EF.csv"), show_col_types = FALSE)
  sf <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_SF.csv"), show_col_types = FALSE)
  canopy <- bind_rows(ef, sf)
  cat(sprintf("Loaded Helios canopy summaries: %d rows (EF=%d, SF=%d), %d unique plots\n",
              nrow(canopy), nrow(ef), nrow(sf), n_distinct(canopy$Loc_ID)))

  canopy_plots <- canopy %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(A_umol_m2_s)) %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")))
  cat(sprintf("Filtered: %d rows, %d distinct DAPs\n",
              nrow(canopy_plots), n_distinct(canopy_plots$DAP)))

  # Mean and standard error of plots for each site, row spacing, leaflet type and date.
  agg <- canopy_plots %>%
    group_by(Site, Spacing, Leaf_type, DAP) %>%
    summarize(
      n      = dplyr::n(),
      A_mean = mean(A_umol_m2_s, na.rm = TRUE),
      A_sd   = sd(A_umol_m2_s,   na.rm = TRUE),
      A_se   = A_sd / sqrt(n),
      .groups = "drop"
    )

  # Build one panel. Plot values are jittered by up to 0.7 DAP, and the class means are drawn as
  # lines with standard-error ribbons. A second fill scale (ggnewscale) separates the stage
  # shading from the leaflet-type fill.
  build_canopyA_panel <- function(d_plot, d_agg, panel_title) {
    dap_range <- range(d_plot$DAP)
    x_lo <- min(10, dap_range[1] - 4)
    x_hi <- max(110, dap_range[2] + 4)
    y_max <- max(d_agg$A_mean + d_agg$A_se, na.rm = TRUE)
    y_hi  <- ceiling(y_max * 1.10 + 1)

    ggplot() +
      geom_rect(data = stage_boundaries,
                aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf,
                    fill = Stage), alpha = BG_ALPHA) +
      scale_fill_manual(values = STAGE_COLS, guide = "none") +
      geom_vline(xintercept = c(48, 82), linetype = "dashed",
                 color = "gray40", linewidth = 0.6, alpha = 0.7) +
      ggnewscale::new_scale_fill() +
      geom_jitter(data = d_plot,
                  aes(x = DAP, y = A_umol_m2_s, color = Leaf_type),
                  width = 0.7, alpha = 0.18, size = 0.9, shape = 16) +
      geom_ribbon(data = d_agg,
                  aes(x = DAP, ymin = A_mean - A_se, ymax = A_mean + A_se,
                      fill = Leaf_type),
                  alpha = 0.30) +
      geom_line(data = d_agg,
                aes(x = DAP, y = A_mean, color = Leaf_type),
                linewidth = 1.1) +
      geom_point(data = d_agg,
                 aes(x = DAP, y = A_mean, fill = Leaf_type),
                 shape = 21, color = "black", size = 2.6, stroke = 0.5) +
      scale_fill_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_color_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_x_continuous(breaks = seq(20, 120, by = 20),
                         limits = c(x_lo, x_hi), expand = c(0.01, 0)) +
      scale_y_continuous(limits = c(0, y_hi), expand = c(0.01, 0)) +
      labs(title = panel_title,
           x = "Days After Planting (DAP)",
           y = expression(bold("Canopy A") ~
                          "(" * mu * mol ~ CO[2] ~ m^-2 ~ s^-1 * ")")) +
      pub_theme
  }

  # The four panels. Spacing is coded in inches in the data (15 = 38-cm rows, 30 = 76-cm rows).
  # The panel titles drawn in the figure keep the inch codes. The statistics files use the
  # metric row spacings.
  panels <- list(
    list(label = "SF_38cm", site = "SF", spacing = 15, title = "SoyFACE (SF) - 15-inch row spacing",
         rows = "SoyFACE (SF), 38-cm rows"),
    list(label = "SF_76cm", site = "SF", spacing = 30, title = "SoyFACE (SF) - 30-inch row spacing",
         rows = "SoyFACE (SF), 76-cm rows"),
    list(label = "EF_38cm", site = "EF", spacing = 15, title = "Energy Farm (EF) - 15-inch row spacing",
         rows = "Energy Farm (EF), 38-cm rows"),
    list(label = "EF_76cm", site = "EF", spacing = 30, title = "Energy Farm (EF) - 30-inch row spacing",
         rows = "Energy Farm (EF), 76-cm rows")
  )

  for (p in panels) {
    d_plot <- canopy_plots %>% filter(Site == p$site, Spacing == p$spacing)
    d_agg  <- agg  %>% filter(Site == p$site, Spacing == p$spacing)
    if (nrow(d_agg) == 0) {
      cat(sprintf("No data for %s (%s x %s)\n", p$label, p$site, p$spacing))
      next
    }
    pl <- build_canopyA_panel(d_plot, d_agg, p$title)
    fn <- file.path(OUT, sprintf("Fig2A_canopy_A_%s.png", p$label))
    ggsave(fn, pl, width = 7, height = 5, dpi = 300, bg = "white", device = ragg::agg_png)
    cat(sprintf("Saved %s\n", basename(fn)))
  }

  # Statistics of each panel. Cohen's d is (broad mean - narrow mean) / pooled SD, so a negative
  # d means higher canopy A in narrow-leaflet plots.
  cohens_d <- function(x, y) {
    nx <- length(x); ny <- length(y)
    sx <- sd(x); sy <- sd(y)
    pooled_sd <- sqrt(((nx-1)*sx^2 + (ny-1)*sy^2) / (nx + ny - 2))
    (mean(x) - mean(y)) / pooled_sd
  }

  d  <- bind_rows(ef, sf) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"), !is.na(A_umol_m2_s))

  # Per-plot peak canopy A, the maximum over all simulated dates of the plot.
  peak <- d %>%
    group_by(Site, Spacing, Leaf_type, Loc_ID) %>%
    summarize(A_peak = max(A_umol_m2_s, na.rm = TRUE), .groups = "drop")

  n_total <- nrow(d)
  for (p in panels) {
    sub <- peak %>% filter(Site == p$site, Spacing == p$spacing)
    narrow <- sub %>% filter(Leaf_type == "Narrow") %>% pull(A_peak)
    broad  <- sub %>% filter(Leaf_type == "Broad")  %>% pull(A_peak)

    w   <- wilcox.test(broad, narrow, exact = FALSE)
    pv  <- w$p.value
    d_e <- cohens_d(broad, narrow)
    pv_str <- if (pv < 1e-10) sprintf("P < 1e-10 (%.2e)", pv) else sprintf("P = %.4e", pv)

    txt <- sprintf(
  '================================================================================
canopyA stats - Fig 2A (%s)
Source: Helios canopy summaries (outputs/helios/helios_canopy_summary_{EF,SF}.csv); n=%d plot-DAPs total
Test: Wilcoxon rank-sum on per-plot PEAK A_umol_m2_s.
Cohen\'s d sign: positive = Broad > Narrow.
================================================================================

--- %s ---
  n          : Narrow = %d, Broad = %d
  Median     : Narrow = %.4f, Broad = %.4f
  Mean+/-SD  : Narrow = %.4f+/-%.4f, Broad = %.4f+/-%.4f
  Cohen\'s d  : %.2f
  Wilcoxon   : %s
',
      p$rows,
      n_total,
      p$rows,
      length(narrow), length(broad),
      median(narrow), median(broad),
      mean(narrow), sd(narrow), mean(broad), sd(broad),
      d_e, pv_str)

    fn <- file.path(OUT, sprintf("Fig2A_canopy_A_stats_%s.txt", p$label))
    writeLines(txt, fn)
    cat(sprintf("Wrote %s | n(N)=%d n(B)=%d | d=%.2f | %s\n",
                basename(fn), length(narrow), length(broad), d_e, pv_str))
  }
}

# ==================================================================================================
# Section fig2c
# Fig 2C: Narrow-minus-broad difference in Helios canopy net photosynthesis against mean leaf area
# index
# ==================================================================================================
#
# Purpose
#   Averages Helios canopy net photosynthesis (canopy A) and LAI over the plots of each site, row
#   spacing, leaflet type and date, and computes the narrow-minus-broad difference in canopy A
#   (delta A) and the mean LAI of narrow and broad plots for each of the 40 site x row spacing x
#   date combinations. A quadratic in mean LAI is fitted by ordinary least squares and drawn with
#   its 95% confidence band, and the LAI at which the fit crosses zero is marked (Fig. 2C). The
#   coefficients, R2, RMSE, zero crossing and vertex of the fit are written to a statistics file
#   and are quoted in the Results. The file also gives the zero crossing of the same quadratic
#   fitted separately to each site x row spacing combination.
#
# Inputs
#   outputs/helios/helios_canopy_summary_{SF,EF}.csv   Helios canopy summary, one row per
#                                                      plot and date (simulation group)
#
# Outputs
#   outputs/figures/Figure2/Fig2C_delta_canopy_A.png         Fig. 2C
#   outputs/figures/Figure2/Fig2C_delta_canopy_A_stats.txt   quadratic fit of delta A on mean LAI

fig2c <- function() {
  HELIOS_DIR <- file.path(ROOT, "outputs", "helios")
  OUT        <- file.path(ROOT, "outputs", "figures", "Figure2")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  delta_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title        = element_text(size = 16, face = "bold", hjust = 0.5,
                                       margin = margin(b = 6)),
      axis.title.x      = element_text(size = 17, face = "bold", color = "black",
                                       margin = margin(t = 6)),
      axis.title.y      = element_text(size = 17, face = "bold", color = "black",
                                       margin = margin(r = 4)),
      axis.text         = element_text(size = 14, color = "black"),
      axis.ticks        = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length = unit(0.2, "cm"),
      panel.grid.major  = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      panel.border      = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background  = element_rect(fill = "white"),
      plot.background   = element_rect(fill = "white", color = NA),
      legend.position   = "top",
      legend.title      = element_text(face = "bold", size = 10),
      legend.text       = element_text(size = 9),
      legend.key.width  = unit(0.9, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.margin     = margin(0, 0, 0, 0),
      aspect.ratio      = 1,
      plot.margin       = margin(10, 14, 10, 10)
    )

  # Site fill colors, row-spacing point shapes (Spacing 15 = 38-cm rows, 30 = 76-cm rows) and the
  # colors of the fitted curve, its band and the zero line.
  SITE_COLS <- c("EF" = "#8C5A2B", "SF" = "#3A6B3A")
  SHAPE_SP  <- c("15" = 21, "30" = 22)
  FIT_COL   <- "#222222"; FIT_BAND <- "#bbbbbb"; ZERO_COL <- "#777777"

  # Read both sites and average the plots of each site, row spacing, leaflet type and date.
  ef <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_EF.csv"), show_col_types = FALSE)
  sf <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_SF.csv"), show_col_types = FALSE)
  per_plot <- bind_rows(ef, sf) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(A_umol_m2_s), !is.na(LAI_used), !is.na(DAP))

  df <- per_plot %>%
    group_by(site = Site, Spacing, Leaf_type, DAP) %>%
    summarize(LAI_used    = mean(LAI_used,                                  na.rm = TRUE),
              A_umol_m2_s = mean(A_umol_m2_s,                               na.rm = TRUE),
              fAPAR       = mean(frac_PAR_absorbed,                         na.rm = TRUE),
              LUE         = mean(inst_canopy_A_per_abs_PAR_umol_per_umol,   na.rm = TRUE),
              .groups = "drop") %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")),
           Spacing   = factor(as.character(Spacing), levels = c("15", "30")))
  cat(sprintf("Loaded %d cell-DAP rows. EF: %d, SF: %d\n",
              nrow(df), sum(df$site == "EF"), sum(df$site == "SF")))

  # Narrow-minus-broad difference in canopy A and the mean LAI of the two leaflet types, for each
  # site x row spacing x date.
  dw <- df %>%
    pivot_wider(names_from = Leaf_type,
                values_from = c(A_umol_m2_s, LAI_used,
                                fAPAR, LUE)) %>%
    mutate(deltaA   = A_umol_m2_s_Narrow - A_umol_m2_s_Broad,
           LAI_mean = (LAI_used_Narrow + LAI_used_Broad) / 2) %>%
    filter(!is.na(deltaA), !is.na(LAI_mean))

  # Quadratic fit by ordinary least squares. The zero crossing is the smallest positive root of
  # the fitted quadratic and the vertex is its maximum.
  fit <- lm(deltaA ~ LAI_mean + I(LAI_mean^2), data = dw)
  cf  <- coef(fit)
  b0  <- cf["(Intercept)"]; b1 <- cf["LAI_mean"]; b2 <- cf["I(LAI_mean^2)"]
  disc <- b1^2 - 4 * b2 * b0
  roots <- if (disc >= 0) (-b1 + c(-1,1) * sqrt(disc)) / (2 * b2) else NA
  crossover <- if (all(!is.na(roots)) && any(roots > 0)) min(roots[roots > 0]) else NA
  vertex_x <- -b1 / (2 * b2)
  vertex_y <- b0 + b1 * vertex_x + b2 * vertex_x^2
  r2   <- summary(fit)$r.squared
  rmse <- sqrt(mean(residuals(fit)^2))
  n    <- nrow(dw)

  # Fitted curve and 95% confidence band, extended 0.3 LAI beyond the highest mean LAI.
  LAI_grid <- seq(min(dw$LAI_mean), max(dw$LAI_mean) + 0.3, length.out = 400)
  pred <- predict(fit, newdata = data.frame(LAI_mean = LAI_grid),
                  interval = "confidence", level = 0.95)
  fit_df <- data.frame(LAI = LAI_grid, deltaA = pred[,"fit"],
                       lwr = pred[,"lwr"], upr = pred[,"upr"])

  ax_x_max <- ceiling(max(dw$LAI_mean) + 1)
  ax_y_min <- floor(min(dw$deltaA, na.rm = TRUE) - 0.3)
  ax_y_max <- ceiling(max(dw$deltaA, na.rm = TRUE) + 1)

  p <- ggplot(dw, aes(x = LAI_mean, y = deltaA)) +
    geom_hline(yintercept = 0, linetype = "12",
               color = ZERO_COL, linewidth = 0.5) +
    geom_ribbon(data = fit_df,
                aes(x = LAI, y = deltaA, ymin = lwr, ymax = upr),
                fill = FIT_BAND, alpha = 0.35) +
    geom_line(data = fit_df, aes(x = LAI, y = deltaA),
              color = FIT_COL, linewidth = 1.0) +
    {if (!is.na(crossover))
        annotate("point", x = crossover, y = 0,
                 shape = 21, size = 3.5, fill = "white",
                 color = "black", stroke = 0.8)} +
    geom_point(aes(fill = site, shape = Spacing),
               color = "black", size = 3.0, stroke = 0.5, alpha = 0.85) +
    scale_fill_manual(values = SITE_COLS, name = "Site",
                      guide = guide_legend(override.aes = list(shape = 21, size = 3.5))) +
    scale_shape_manual(values = SHAPE_SP, name = "Row spacing (in)") +
    scale_x_continuous(limits = c(0, ax_x_max),
                       breaks = seq(0, 14, 2), expand = c(0.01, 0)) +
    scale_y_continuous(limits = c(ax_y_min, ax_y_max),
                       breaks = seq(-4, 12, 1), expand = c(0.01, 0)) +
    labs(x = expression(bold("Mean LAI") ~ "(" * m^2 ~ m^-2 * ")"),
         y = expression(bold(Delta) ~ bold("canopy A (Narrow - Broad)") ~
                        "(" * mu * mol ~ CO[2] ~ m^-2 ~ s^-1 * ")")) +
    delta_theme

  ggsave(file.path(OUT, "Fig2C_delta_canopy_A.png"),
         p, width = 6.0, height = 6.0, dpi = 300, bg = "white", device = ragg::agg_png)
  cat("Saved Fig2C_delta_canopy_A.png\n")

  # The same quadratic fitted separately to each site x row spacing combination (10 dates each),
  # with its zero crossing (smallest positive root).
  ROW_LAB <- c("15" = "38-cm rows", "30" = "76-cm rows")
  combo_lines <- character()
  for (site_code in c("EF", "SF")) {
    for (sp in c("15", "30")) {
      one <- dw[dw$site == site_code & as.character(dw$Spacing) == sp, ]
      fit_one <- lm(deltaA ~ LAI_mean + I(LAI_mean^2), data = one)
      cf_one  <- unname(coef(fit_one))
      disc_one  <- cf_one[2]^2 - 4 * cf_one[3] * cf_one[1]
      roots_one <- if (disc_one >= 0) (-cf_one[2] + c(-1, 1) * sqrt(disc_one)) / (2 * cf_one[3]) else NA
      cross_one <- if (all(!is.na(roots_one)) && any(roots_one > 0)) min(roots_one[roots_one > 0]) else NA
      combo_lines <- c(combo_lines, sprintf(
        "  %s, %s (n = %d): crossover LAI = %s, R^2 = %.2f\n", site_code, ROW_LAB[[sp]], nrow(one),
        if (is.na(cross_one)) "no positive root" else sprintf("%.2f", cross_one),
        summary(fit_one)$r.squared))
    }
  }

  # Statistics of the quadratic fit.
  sink(file.path(OUT, "Fig2C_delta_canopy_A_stats.txt"))
  cat("================================================================================\n")
  cat("Fig 2C stats - Delta A (Narrow - Broad) vs mean LAI scaling\n")
  cat("Panel: Combined SF + EF (single quadratic fit across both sites)\n")
  cat("Source: Helios canopy summaries, cell-mean per Site x Spacing x Leaf_type x DAP.\n")
  cat("Fit:    Quadratic   deltaA = b0 + b1*LAI + b2*LAI^2\n")
  cat("================================================================================\n\n")
  cat(sprintf("  n cell-DAP pairs : %d\n", n))
  cat(sprintf("  Coefficients     : b0 = %+.4f, b1 = %+.4f, b2 = %+.5f\n", b0, b1, b2))
  cat(sprintf("  R^2              : %.3f\n", r2))
  cat(sprintf("  RMSE             : %.2f umol CO2/m2/s\n", rmse))
  cat(sprintf("  Crossover LAI    : %s\n",
              if (is.na(crossover)) "no positive root" else sprintf("%.2f", crossover)))
  cat(sprintf("  Vertex (peak)    : LAI = %.2f, deltaA = %+.2f\n", vertex_x, vertex_y))
  cat(sprintf("  Initial slope    : %+.3f umol per unit LAI (derivative at LAI=0)\n", b1))
  cat("\n--- Quadratic fitted separately to each site x row spacing ---\n")
  cat(combo_lines, sep = "")
  sink()
  cat(sprintf("Saved Fig2C_delta_canopy_A_stats.txt\n\nFig 2C: crossover LAI=%.2f, vertex (LAI=%.2f, dA=%+.2f), R^2=%.3f, n=%d\n",
              crossover, vertex_x, vertex_y, r2, n))
}

# ==================================================================================================
# Section fig2d
# Fig 2D: Cumulative share of canopy net photosynthesis against cumulative share of leaf area from
# the canopy top
# ==================================================================================================
#
# Purpose
#   For each site x row spacing x leaflet type, finds the date with the highest mean LAI and pools
#   the Helios sub-leaf elements of all plots of that class on that date. Elements are sorted by
#   height from the canopy top, and the cumulative share of canopy net photosynthesis (canopy A)
#   is drawn against the cumulative share of the class's leaf area (Fig. 2D, one panel per site).
#   The statistics files give, for each class, the share of canopy A in the top 10%, 25% and 50%
#   of leaf area and the overshoot above 100% caused by net-respiring leaves at the canopy bottom.
#   These are the top-25% shares and respiration values in the Results. The top-25% table is also
#   read by section fig3cd to check that it uses the same plots and dates.
#
# Inputs
#   outputs/helios/helios_canopy_summary_{SF,EF}.csv          Helios canopy summary, one row per
#                                                             plot and date (simulation group)
#   outputs/helios/{SF,EF}/per_leaf/<Loc_ID>_DAP<ddd>.csv     Helios sub-leaf element outputs
#                                                             (height, area, net A) of each plot
#                                                             and date (simulation group)
#
# Outputs
#   outputs/figures/Figure2/Fig2D_canopy_A_by_depth_SF.png    Fig. 2D, SoyFACE panel
#   outputs/figures/Figure2/Fig2D_canopy_A_by_depth_EF.png    Fig. 2D, Energy Farm panel
#   outputs/figures/Figure2/Fig2D_top25_share.csv             share of canopy A in the top 25% of
#                                                             leaf area and total LAI of each class
#   outputs/figures/Figure2/Fig2D_canopy_A_by_depth_stats_{SF,EF}.txt   statistics of each site

fig2d <- function() {
  HELIOS_DIR  <- file.path(ROOT, "outputs", "helios")
  LEAF_DIR    <- HELIOS_DIR  # per-leaf files are in <site>/per_leaf/
  OUT         <- file.path(ROOT, "outputs", "figures", "Figure2")
  GROUND_AREA <- 9.0         # m2, the 3 x 3 m simulated canopy
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type colors (shared by all figures) and row-spacing line types. Spacing is coded in
  # inches in the data (15 = 38-cm rows, 30 = 76-cm rows).
  BROAD_COL  <- "#FFD700"; NARROW_COL <- "#00BFFF"
  LEAF_COLS  <- c("Broad" = BROAD_COL, "Narrow" = NARROW_COL)
  SPACING_LT <- c("15" = "solid", "30" = "22")
  ROW_LAB    <- c("15" = "38-cm rows", "30" = "76-cm rows")

  # Read both sites and find the date with the highest mean LAI of each class.
  ef <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_EF.csv"), show_col_types = FALSE)
  sf <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_SF.csv"), show_col_types = FALSE)
  master <- bind_rows(ef, sf) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"))
  cat(sprintf("Helios canopy summary rows: %d\n", nrow(master)))

  peak_dap <- master %>%
    group_by(Site, Spacing, Leaf_type, DAP) %>%
    summarize(LAI_cell_mean = mean(LAI_used, na.rm = TRUE), .groups = "drop_last") %>%
    slice_max(LAI_cell_mean, n = 1) %>% ungroup()
  cat("Peak-LAI DAP of each cell\n"); print(peak_dap)

  # Read the per-leaf files of all plots of one class on one date.
  load_cell <- function(site, sp, leaf, dap) {
    loc_ids <- master %>%
      filter(Site == site, Spacing == sp, Leaf_type == leaf, DAP == dap) %>%
      pull(Loc_ID) %>% unique()
    rows <- list()
    for (loc in loc_ids) {
      fp <- file.path(LEAF_DIR, site, "per_leaf", sprintf("%s_DAP%03d.csv", loc, dap))
      if (!file.exists(fp)) next
      df <- tryCatch(read_csv(fp, show_col_types = FALSE), error = function(e) NULL)
      if (!is.null(df) && nrow(df) > 0) {
        df$Loc_ID <- loc
        rows[[length(rows) + 1]] <- df
      }
    }
    if (length(rows) == 0) return(NULL)
    out <- bind_rows(rows)
    out$Site <- site; out$Spacing <- sp; out$Leaf_type <- leaf; out$DAP <- dap
    out
  }

  all_leaflets <- list()
  for (i in seq_len(nrow(peak_dap))) {
    p <- peak_dap[i,]
    d <- load_cell(p$Site, p$Spacing, p$Leaf_type, p$DAP)
    if (!is.null(d)) {
      all_leaflets[[length(all_leaflets) + 1]] <- d
      cat(sprintf("  %s x %s x %s @ DAP=%d: %d leaflets, %d plots\n",
                  p$Site, p$Spacing, p$Leaf_type, p$DAP,
                  nrow(d), length(unique(d$Loc_ID))))
    }
  }
  all_df <- bind_rows(all_leaflets) %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")),
           Spacing   = factor(Spacing,   levels = c(15, 30)))
  cat(sprintf("Combined per-leaf rows: %d\n", nrow(all_df)))

  # Pool the elements of each class and sort them by height from the canopy top. Cumulative LAI is
  # the summed element area divided by the ground area of all pooled plots. The cumulative share of
  # canopy A uses each element's net A times its area.
  cumdat <- all_df %>%
    arrange(Site, Leaf_type, Spacing, desc(z_m)) %>%
    group_by(Site, Leaf_type, Spacing) %>%
    mutate(n_plots = n_distinct(Loc_ID),
           cum_LAI_from_top = cumsum(leaf_area_m2) / (GROUND_AREA * n_plots),
           A_per_element    = A_umol_m2_s * leaf_area_m2,
           cum_A_frac       = cumsum(A_per_element) / sum(A_per_element)) %>%
    ungroup()

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title         = element_text(size = 18, face = "bold", hjust = 0.5,
                                        margin = margin(b = 6)),
      axis.title.x       = element_text(size = 18, face = "bold", color = "black",
                                        margin = margin(t = 6)),
      axis.title.y       = element_text(size = 18, face = "bold", color = "black",
                                        margin = margin(r = 4)),
      axis.text.x        = element_text(size = 14, color = "black"),
      axis.text.y        = element_text(size = 14, color = "black"),
      axis.ticks         = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length  = unit(0.2, "cm"),
      panel.grid.major   = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor   = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background   = element_rect(fill = "white"),
      plot.background    = element_rect(fill = "white", color = NA),
      legend.position    = "top",
      legend.title       = element_text(face = "bold", size = 10),
      legend.text        = element_text(size = 9),
      legend.box         = "horizontal",
      legend.key.width   = unit(1.2, "cm"),
      legend.key.height  = unit(0.4, "cm"),
      legend.margin      = margin(0, 0, 0, 0),
      legend.box.margin  = margin(0, 0, -2, 0),
      plot.margin        = margin(10, 14, 10, 10)
    )

  # Express cumulative LAI as a share of each class's total LAI and draw one panel per site.
  normdat <- cumdat %>%
    group_by(Site, Leaf_type, Spacing) %>%
    mutate(total_LAI = max(cum_LAI_from_top, na.rm = TRUE),
           x_norm    = cum_LAI_from_top / total_LAI) %>%
    ungroup()

  build_panelCnorm <- function(d, site_label) {
    ggplot(d, aes(x = x_norm, y = cum_A_frac,
                  color = Leaf_type, linetype = Spacing)) +
      geom_vline(xintercept = c(0.10, 0.25, 0.50), linetype = "12",
                 color = "gray60", linewidth = 0.3) +
      geom_hline(yintercept = c(0.5, 0.8, 1.0), linetype = "12",
                 color = "gray60", linewidth = 0.3) +
      geom_line(linewidth = 1.2) +
      scale_x_continuous(labels = label_number(scale = 100, accuracy = 1),
                         breaks = seq(0, 1, 0.2), limits = c(0, 1),
                         expand = c(0, 0)) +
      scale_y_continuous(labels = label_number(scale = 100, accuracy = 1),
                         breaks = seq(0, 1.2, 0.2),
                         limits = c(0, max(1.2, ceiling(max(d$cum_A_frac, na.rm = TRUE)*20)/20)),
                         expand = c(0, 0)) +
      scale_color_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_linetype_manual(values = SPACING_LT, name = "Row spacing (in)") +
      labs(title = site_label,
           x = expression(bold("Total canopy LAI from top") ~ "(%)"),
           y = expression(bold("Cumulative share of canopy A") ~ "(%)")) +
      pub_theme
  }
  ggsave(file.path(OUT, "Fig2D_canopy_A_by_depth_SF.png"),
         build_panelCnorm(normdat %>% filter(Site == "SF"), "SoyFACE (SF)"),
         width = 6.5, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)
  ggsave(file.path(OUT, "Fig2D_canopy_A_by_depth_EF.png"),
         build_panelCnorm(normdat %>% filter(Site == "EF"), "Energy Farm (EF)"),
         width = 6.5, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)

  # Share of canopy A in the top 25% of each class's leaf area, taken at the first element at or
  # beyond 25% of the cumulative leaf area.
  top25 <- normdat %>%
    group_by(Site, Spacing, Leaf_type) %>%
    filter(x_norm >= 0.25) %>%
    slice_min(x_norm, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(Site, Spacing, Leaf_type, A_at_top25 = cum_A_frac, total_LAI)
  write_csv(top25, file.path(OUT, "Fig2D_top25_share.csv"))

  cat("\n=== Top 25% LAI -> % canopy A (per cell) ===\n")
  print(top25 %>% arrange(Site, Spacing, Leaf_type))

  # Statistics of each site. For each class, the shares of canopy A in the top 10%, 25% and 50% of
  # leaf area, the peak of the cumulative share and the bottom respiration drag, which is the
  # overshoot of the cumulative share above 100% before net-respiring leaves at the canopy bottom
  # bring it back to 100%. The last block gives the broad-minus-narrow gap in percentage points.
  write_pcnorm_stats <- function(site, normdat_site, top25_site, peak_dap_site, fp) {
    pct_at <- function(d, x_cut) {
      sub <- d %>% filter(x_norm >= x_cut) %>% slice_min(x_norm, n = 1, with_ties = FALSE)
      if (nrow(sub) == 0) NA_real_ else sub$cum_A_frac[1]
    }
    lines <- c(
      "================================================================================",
      "Fig 2D stats - Fraction of canopy A captured vs fraction of total",
      "canopy LAI (from canopy top).",
      sprintf("Panel: %s", if (site == "SF") "SoyFACE (SF)" else "Energy Farm (EF)"),
      "Source: Helios per-leaf outputs of each plot, pooled within each cell at the peak-LAI DAP.",
      "Pooling: leaflets from all plots in the cell sorted by z_m desc, cum-summed.",
      "Drag = (peak cum_A_frac - 1) x 100% (overshoot above 100% before settling to 1).",
      "================================================================================",
      ""
    )
    # One block per leaflet type and row spacing, narrow first.
    per_cell_pct <- list()
    for (leaf in c("Narrow", "Broad")) {
      for (sp in c(15, 30)) {
        d <- normdat_site %>% filter(Leaf_type == leaf, Spacing == sp)
        if (nrow(d) == 0) next
        dap <- peak_dap_site %>% filter(Leaf_type == leaf, Spacing == sp) %>% pull(DAP) %>% .[1]
        tlai <- top25_site %>% filter(Leaf_type == leaf, Spacing == sp) %>% pull(total_LAI) %>% .[1]
        n_pl <- length(unique(d$Loc_ID))
        p10 <- pct_at(d, 0.10); p25 <- pct_at(d, 0.25); p50 <- pct_at(d, 0.50)
        peak_cum <- max(d$cum_A_frac, na.rm = TRUE)
        drag <- (peak_cum - 1.0) * 100.0
        lines <- c(lines,
          sprintf("--- %s, %s ---", leaf, ROW_LAB[[as.character(sp)]]),
          sprintf("  Peak DAP            : %d", dap),
          sprintf("  Plots pooled        : %d", n_pl),
          sprintf("  Total LAI           : %.2f m^2/m^2", tlai),
          sprintf("  Top  10%% LAI -> %5.1f%% of canopy A", 100*p10),
          sprintf("  Top  25%% LAI -> %5.1f%% of canopy A", 100*p25),
          sprintf("  Top  50%% LAI -> %5.1f%% of canopy A", 100*p50),
          sprintf("  Peak cum A from top : %.1f%%", 100*peak_cum),
          sprintf("  Bottom resp drag    : %+.2f%%", drag),
          "")
        per_cell_pct[[sprintf("%s_%s", leaf, sp)]] <- c(p10 = p10, p25 = p25, p50 = p50)
      }
    }
    # Broad-minus-narrow gap in percentage points.
    lines <- c(lines,
      sprintf("--- Architectural gap (Broad - Narrow, percentage points) at %s ---", site),
      "                     Top 10%    Top 25%    Top 50%")
    for (sp in c(15, 30)) {
      bN <- per_cell_pct[[sprintf("Broad_%d", sp)]]
      nN <- per_cell_pct[[sprintf("Narrow_%d", sp)]]
      if (is.null(bN) || is.null(nN)) next
      lines <- c(lines,
        sprintf("  %-15s     %+5.1f      %+5.1f      %+5.1f",
                ROW_LAB[[as.character(sp)]], 100*(bN["p10"]-nN["p10"]), 100*(bN["p25"]-nN["p25"]), 100*(bN["p50"]-nN["p50"])))
    }
    lines <- c(lines, "", "(Positive = Broad more top-heavy than Narrow at this LAI fraction.)")
    writeLines(lines, fp)
  }

  for (site in c("SF", "EF")) {
    fp <- file.path(OUT, sprintf("Fig2D_canopy_A_by_depth_stats_%s.txt", site))
    write_pcnorm_stats(site,
                       normdat %>% filter(Site == site),
                       top25  %>% filter(Site == site),
                       peak_dap %>% filter(Site == site),
                       fp)
    cat(sprintf("  Wrote: %s\n", basename(fp)))
  }

  cat(sprintf("\nWrote 2 panels, the top-25%% table and 2 statistics files to %s\n", OUT))
}

# ==================================================================================================
# Section fig3ab
# Figs 3A-B and S7A-B: Seasonal fAPAR and canopy light-use efficiency of broad- and narrow-leaflet
# canopies
# ==================================================================================================
#
# Purpose
#   Averages the Helios fraction of incident PAR absorbed (fAPAR) and canopy light-use efficiency
#   (LUE, canopy net photosynthesis per unit absorbed PAR) over the plots of each site, row
#   spacing, leaflet type and date, and draws both against days after planting with shaded growth
#   stages. SoyFACE gives Fig. 3A (fAPAR) and Fig. 3B (LUE), and the Energy Farm gives Figs. S7A
#   and S7B. The statistics files give, for each class, the peak and reproductive-stage values
#   and the date of canopy closure (fAPAR 0.90), and compare per-plot peak fAPAR and peak LUE
#   between leaflet types in each row spacing by a two-sided Wilcoxon rank-sum test and Cohen's d
#   (broad minus narrow, pooled SD). These give the n and d values of the panels and the fAPAR
#   and LUE comparisons in the Results. The fAPAR files end with the narrow-minus-broad
#   difference in class-mean fAPAR on the first date of each row spacing.
#
# Inputs
#   outputs/helios/helios_canopy_summary_{SF,EF}.csv   Helios canopy summary, one row per
#                                                      plot and date (simulation group)
#
# Outputs
#   outputs/figures/Figure3/Fig3A_fAPAR_SF.png            Fig. 3A
#   outputs/figures/Figure3/Fig3B_LUE_SF.png              Fig. 3B
#   outputs/figures/FigureS7/FigS7A_fAPAR_EF.png          Fig. S7A
#   outputs/figures/FigureS7/FigS7B_LUE_EF.png            Fig. S7B
#   outputs/figures/Figure3/Fig3A_fAPAR_stats.txt         fAPAR statistics, SoyFACE
#   outputs/figures/Figure3/Fig3B_LUE_stats.txt           canopy LUE statistics, SoyFACE
#   outputs/figures/FigureS7/FigS7A_fAPAR_stats.txt       fAPAR statistics, Energy Farm
#   outputs/figures/FigureS7/FigS7B_LUE_stats.txt         canopy LUE statistics, Energy Farm

fig3ab <- function() {
  HELIOS_DIR <- file.path(ROOT, "outputs", "helios")
  OUT_MAIN   <- file.path(ROOT, "outputs", "figures", "Figure3")
  OUT_SUPP   <- file.path(ROOT, "outputs", "figures", "FigureS7")
  dir.create(OUT_MAIN, showWarnings = FALSE, recursive = TRUE)
  dir.create(OUT_SUPP, showWarnings = FALSE, recursive = TRUE)

  # Panel files, SoyFACE in Fig. 3 and the Energy Farm in Fig. S7.
  PANEL_FILE <- list(
    fAPAR = c(SF = file.path(OUT_MAIN, "Fig3A_fAPAR_SF.png"),
              EF = file.path(OUT_SUPP, "FigS7A_fAPAR_EF.png")),
    LUE   = c(SF = file.path(OUT_MAIN, "Fig3B_LUE_SF.png"),
              EF = file.path(OUT_SUPP, "FigS7B_LUE_EF.png")))

  # Leaflet-type colors (shared by all figures) and row-spacing line types. Spacing is coded in
  # inches in the data (15 = 38-cm rows, 30 = 76-cm rows).
  BROAD_COL  <- "#FFD700"
  NARROW_COL <- "#00BFFF"
  LEAF_COLS  <- c("Broad" = BROAD_COL, "Narrow" = NARROW_COL)
  SPACING_LT <- c("15" = "solid", "30" = "22")
  ROW_LAB    <- c("15" = "38-cm rows", "30" = "76-cm rows")

  # Growth-stage bands in days after planting, as in Fig. 1C.
  stage_boundaries <- data.frame(
    Stage = factor(c("Vegetative", "Reproductive", "Maturity"),
                   levels = c("Vegetative", "Reproductive", "Maturity")),
    xmin = c(10, 48, 82), xmax = c(48, 82, 120))
  STAGE_COLS <- c("Vegetative" = "#009E73",
                  "Reproductive" = "#F0E442",
                  "Maturity" = "#D55E00")
  BG_ALPHA <- 0.10

  seasonal_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title        = element_text(size = 18, face = "bold", hjust = 0.5,
                                       margin = margin(b = 6)),
      axis.title.x      = element_text(size = 18, face = "bold", color = "black",
                                       margin = margin(t = 6)),
      axis.title.y      = element_text(size = 18, face = "bold", color = "black",
                                       margin = margin(r = 4)),
      axis.text         = element_text(size = 14, color = "black"),
      axis.ticks        = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length = unit(0.2, "cm"),
      panel.grid.major  = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      panel.border      = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background  = element_rect(fill = "white"),
      plot.background   = element_rect(fill = "white", color = NA),
      legend.position   = "top",
      legend.title      = element_text(face = "bold", size = 10),
      legend.text       = element_text(size = 9),
      legend.key.width  = unit(1.2, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.margin     = margin(0, 0, 0, 0),
      aspect.ratio      = 0.55,
      plot.margin       = margin(10, 14, 10, 10)
    )

  # Read both sites and average the plots of each site, row spacing, leaflet type and date.
  ef <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_EF.csv"), show_col_types = FALSE)
  sf <- read_csv(file.path(HELIOS_DIR, "helios_canopy_summary_SF.csv"), show_col_types = FALSE)
  per_plot <- bind_rows(ef, sf) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(A_umol_m2_s), !is.na(LAI_used), !is.na(DAP))

  df <- per_plot %>%
    group_by(site = Site, Spacing, Leaf_type, DAP) %>%
    summarize(LAI_used    = mean(LAI_used,                                  na.rm = TRUE),
              A_umol_m2_s = mean(A_umol_m2_s,                               na.rm = TRUE),
              fAPAR       = mean(frac_PAR_absorbed,                         na.rm = TRUE),
              LUE         = mean(inst_canopy_A_per_abs_PAR_umol_per_umol,   na.rm = TRUE),
              .groups = "drop") %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")),
           Spacing   = factor(as.character(Spacing), levels = c("15", "30")))
  cat(sprintf("Loaded %d cell-DAP rows. EF: %d, SF: %d\n",
              nrow(df), sum(df$site == "EF"), sum(df$site == "SF")))

  # Axis ranges shared by the two sites. The LUE axis ends at the highest class mean rounded up
  # to the next 0.005.
  PANEL_X_MIN     <- 10
  PANEL_X_MAX     <- 110
  PANEL_FAPAR_MIN <- 0.00
  PANEL_FAPAR_MAX <- 1.00
  PANEL_LUE_MIN   <- 0.000
  PANEL_LUE_MAX   <- ceiling(max(df$LUE, na.rm = TRUE) * 200) / 200

  # Build one seasonal panel of class means. fAPAR is drawn with a loess smooth (span 0.75)
  # through the class means and LUE with straight lines between them.
  build_seasonal <- function(d, site_label, y_col, y_label,
                             y_min, y_max, y_breaks, smooth = FALSE,
                             smooth_span = 0.75) {
    line_layer <- if (smooth) {
      geom_smooth(data = d,
                  aes(x = DAP, y = .data[[y_col]],
                      color = Leaf_type, linetype = Spacing,
                      group = interaction(Leaf_type, Spacing)),
                  method = "loess", span = smooth_span,
                  se = FALSE, linewidth = 1.2)
    } else {
      geom_line(data = d,
                aes(x = DAP, y = .data[[y_col]],
                    color = Leaf_type, linetype = Spacing,
                    group = interaction(Leaf_type, Spacing)),
                linewidth = 1.2)
    }
    ggplot() +
      geom_rect(data = stage_boundaries,
                aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf,
                    fill = Stage), alpha = BG_ALPHA) +
      scale_fill_manual(values = STAGE_COLS, guide = "none") +
      geom_vline(xintercept = c(48, 82), linetype = "dashed",
                 color = "gray40", linewidth = 0.6, alpha = 0.7) +
      ggnewscale::new_scale_fill() +
      line_layer +
      geom_point(data = d,
                 aes(x = DAP, y = .data[[y_col]],
                     fill = Leaf_type, shape = Spacing),
                 color = "black", size = 2.6, stroke = 0.5) +
      scale_color_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_fill_manual(values = LEAF_COLS,   name = "Leaflet type") +
      scale_linetype_manual(values = SPACING_LT, name = "Row spacing (in)") +
      scale_shape_manual(values = c("15" = 21, "30" = 22),
                         name = "Row spacing (in)") +
      scale_x_continuous(breaks = seq(20, 120, by = 20),
                         limits = c(PANEL_X_MIN, PANEL_X_MAX),
                         expand = c(0, 0)) +
      scale_y_continuous(breaks = y_breaks,
                         limits = c(y_min, y_max),
                         expand = c(0.01, 0)) +
      labs(title = site_label,
           x = "Days After Planting (DAP)",
           y = y_label) +
      seasonal_theme
  }

  # fAPAR panels (Figs. 3A and S7A).
  y_lab_fapar <- "Fraction of incident PAR absorbed"
  fapar_breaks <- seq(0.0, 1.0, 0.2)
  for (s in c("SF", "EF")) {
    d_site    <- df %>% filter(site == s)
    site_long <- if (s == "SF") "SoyFACE (SF)" else "Energy Farm (EF)"
    p <- build_seasonal(d_site, site_long, "fAPAR", y_lab_fapar,
                        PANEL_FAPAR_MIN, PANEL_FAPAR_MAX, fapar_breaks,
                        smooth = TRUE, smooth_span = 0.75)
    ggsave(PANEL_FILE$fAPAR[[s]],
           p, width = 7, height = 5, dpi = 300, bg = "white", device = ragg::agg_png)
    cat(sprintf("Saved %s\n", basename(PANEL_FILE$fAPAR[[s]])))
  }

  # Canopy LUE panels (Figs. 3B and S7B).
  y_lab_lue <- expression(bold("Canopy LUE") ~
                          "(" * mu * mol ~ CO[2] ~ "/" ~ mu * mol ~ aPAR * ")")
  lue_breaks <- seq(0, PANEL_LUE_MAX, 0.005)
  for (s in c("SF", "EF")) {
    d_site    <- df %>% filter(site == s)
    site_long <- if (s == "SF") "SoyFACE (SF)" else "Energy Farm (EF)"
    p <- build_seasonal(d_site, site_long, "LUE", y_lab_lue,
                        PANEL_LUE_MIN, PANEL_LUE_MAX, lue_breaks)
    ggsave(PANEL_FILE$LUE[[s]],
           p, width = 7, height = 5, dpi = 300, bg = "white", device = ragg::agg_png)
    cat(sprintf("Saved %s\n", basename(PANEL_FILE$LUE[[s]])))
  }

  # Class statistics for each site x row spacing x leaflet type, from the class means by date.
  #   fAPAR  peak value and its date, the date at which fAPAR first reaches 0.90 (canopy closure,
  #          interpolated linearly between dates) and the mean over the reproductive stage
  #          (DAP 48-82)
  #   LUE    peak value and its date, the mean over the reproductive stage, and the LUE on the
  #          date of peak LAI
  class_input <- bind_rows(ef, sf) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(frac_PAR_absorbed),
           !is.na(inst_canopy_A_per_abs_PAR_umol_per_umol),
           !is.na(LAI_used), !is.na(DAP))

  class_means <- class_input %>%
    group_by(Site, Spacing, Leaf_type, DAP) %>%
    summarize(LAI_used = mean(LAI_used, na.rm = TRUE),
              fAPAR    = mean(frac_PAR_absorbed, na.rm = TRUE),
              LUE      = mean(inst_canopy_A_per_abs_PAR_umol_per_umol, na.rm = TRUE),
              .groups = "drop")

  DAP_at_threshold <- function(dap, y, thresh = 0.90) {
    o   <- order(dap)
    dap <- dap[o]; y <- y[o]
    hit <- which(y >= thresh)
    if (length(hit) == 0L) return(NA_real_)
    first <- hit[1]
    if (first == 1L) return(dap[1])
    x0 <- dap[first - 1]; x1 <- dap[first]
    y0 <- y[first - 1];   y1 <- y[first]
    x0 + (thresh - y0) * (x1 - x0) / (y1 - y0)
  }

  cell_stats <- class_means %>%
    group_by(Site, Spacing, Leaf_type) %>%
    summarize(
      DAP_n          = n(),
      fAPAR_peak     = max(fAPAR, na.rm = TRUE),
      DAP_fAPAR_peak = DAP[which.max(fAPAR)],
      DAP_closure_90 = DAP_at_threshold(DAP, fAPAR, 0.90),
      fAPAR_REP_mean = mean(fAPAR[DAP >= 48 & DAP <= 82], na.rm = TRUE),
      LAI_peak       = max(LAI_used, na.rm = TRUE),
      DAP_LAI_peak   = DAP[which.max(LAI_used)],
      LUE_peak       = max(LUE, na.rm = TRUE),
      DAP_LUE_peak   = DAP[which.max(LUE)],
      LUE_REP_mean   = mean(LUE[DAP >= 48 & DAP <= 82], na.rm = TRUE),
      LUE_at_LAI_pk  = LUE[which.max(LAI_used)],
      .groups = "drop") %>%
    arrange(Site, Leaf_type, Spacing)

  write_fapar_block <- function(stats, fig_label, site_full, out_path) {
    s <- stats
    sink(out_path)
    cat("================================================================================\n")
    cat(sprintf("%s fAPAR stats - %s\n", fig_label, site_full))
    cat("Source: Helios canopy summaries (cell-mean per Site x Spacing x Leaf_type x DAP)\n")
    cat("================================================================================\n\n")
    for (i in seq_len(nrow(s))) {
      r <- s[i, ]
      cat(sprintf("--- %s, %s ---\n", r$Leaf_type, ROW_LAB[as.character(r$Spacing)]))
      cat(sprintf("  Cell-mean DAPs available     : %d\n", r$DAP_n))
      cat(sprintf("  Peak fAPAR                   : %.3f at DAP %d\n",
                  r$fAPAR_peak, r$DAP_fAPAR_peak))
      cat(sprintf("  DAP at canopy closure (>=0.90): %s\n",
                  if (is.na(r$DAP_closure_90)) "did not reach 0.90"
                  else sprintf("%.1f", r$DAP_closure_90)))
      cat(sprintf("  REP-stage mean fAPAR (DAP 48-82): %.3f\n", r$fAPAR_REP_mean))
      cat("\n")
    }
    cat("--- Four-cell summary ---\n")
    cat("Peak fAPAR | DAP at 0.90 closure | REP-stage mean fAPAR\n")
    for (i in seq_len(nrow(s))) {
      r <- s[i, ]
      cat(sprintf("  %-6s x %s: peak %.2f  | closure DAP %s  | REP mean %.2f\n",
                  r$Leaf_type, ROW_LAB[as.character(r$Spacing)], r$fAPAR_peak,
                  if (is.na(r$DAP_closure_90)) " na "
                  else sprintf("%4.1f", r$DAP_closure_90),
                  r$fAPAR_REP_mean))
    }
    sink()
  }

  write_lue_block <- function(stats, fig_label, site_full, out_path) {
    s <- stats
    sink(out_path)
    cat("================================================================================\n")
    cat(sprintf("%s canopy LUE stats - %s\n", fig_label, site_full))
    cat("Source: Helios canopy summaries (cell-mean per Site x Spacing x Leaf_type x DAP)\n")
    cat("LUE units: umol CO2 / umol absorbed PAR.\n")
    cat("================================================================================\n\n")
    for (i in seq_len(nrow(s))) {
      r <- s[i, ]
      cat(sprintf("--- %s, %s ---\n", r$Leaf_type, ROW_LAB[as.character(r$Spacing)]))
      cat(sprintf("  Peak LUE                       : %.4f at DAP %d\n",
                  r$LUE_peak, r$DAP_LUE_peak))
      cat(sprintf("  REP-stage mean LUE (DAP 48-82) : %.4f\n", r$LUE_REP_mean))
      cat(sprintf("  Peak-LAI DAP                   : %d  (LAI = %.2f)\n",
                  r$DAP_LAI_peak, r$LAI_peak))
      cat(sprintf("  LUE at peak-LAI DAP            : %.4f\n", r$LUE_at_LAI_pk))
      cat("\n")
    }
    cat("--- Four-cell summary ---\n")
    cat("Peak LUE | DAP at peak LUE | REP-stage mean LUE | LUE at peak-LAI DAP\n")
    for (i in seq_len(nrow(s))) {
      r <- s[i, ]
      cat(sprintf("  %-6s x %s: peak %.4f at DAP %d  | REP mean %.4f  | @peakLAI %.4f\n",
                  r$Leaf_type, ROW_LAB[as.character(r$Spacing)], r$LUE_peak, r$DAP_LUE_peak,
                  r$LUE_REP_mean, r$LUE_at_LAI_pk))
    }
    sink()
  }

  STATS_FILE <- list(
    fAPAR = c(SF = file.path(OUT_MAIN, "Fig3A_fAPAR_stats.txt"),
              EF = file.path(OUT_SUPP, "FigS7A_fAPAR_stats.txt")),
    LUE   = c(SF = file.path(OUT_MAIN, "Fig3B_LUE_stats.txt"),
              EF = file.path(OUT_SUPP, "FigS7B_LUE_stats.txt")))

  sf_stats <- cell_stats %>% filter(Site == "SF")
  ef_stats <- cell_stats %>% filter(Site == "EF")
  write_fapar_block(sf_stats, "Fig 3A",  "SoyFACE (SF)",     STATS_FILE$fAPAR[["SF"]])
  write_fapar_block(ef_stats, "Fig S7A", "Energy Farm (EF)", STATS_FILE$fAPAR[["EF"]])
  write_lue_block  (sf_stats, "Fig 3B",  "SoyFACE (SF)",     STATS_FILE$LUE[["SF"]])
  write_lue_block  (ef_stats, "Fig S7B", "Energy Farm (EF)", STATS_FILE$LUE[["EF"]])

  cat("\n=== fAPAR per-cell summary (Figs. 3A and S7A) ===\n")
  print(cell_stats %>%
          select(Site, Spacing, Leaf_type, fAPAR_peak, DAP_fAPAR_peak,
                 DAP_closure_90, fAPAR_REP_mean), n = 8)

  cat("\n=== Canopy LUE per-cell summary (Figs. 3B and S7B) ===\n")
  print(cell_stats %>%
          select(Site, Spacing, Leaf_type, LUE_peak, DAP_LUE_peak,
                 LUE_REP_mean, LUE_at_LAI_pk), n = 8)

  # Broad-versus-narrow comparison of per-plot peak fAPAR and peak LUE (the maximum over the
  # plot's dates) in each row spacing, appended to the four statistics files. Cohen's d is
  # (broad mean - narrow mean) / pooled SD.
  cohens_d <- function(x, y) {
    nx <- length(x); ny <- length(y)
    pooled_sd <- sqrt(((nx-1)*var(x) + (ny-1)*var(y)) / (nx + ny - 2))
    (mean(x) - mean(y)) / pooled_sd
  }

  peak_input <- bind_rows(ef, sf) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(frac_PAR_absorbed),
           !is.na(inst_canopy_A_per_abs_PAR_umol_per_umol))

  plot_peaks <- peak_input %>%
    group_by(Site, Spacing, Leaf_type, Loc_ID) %>%
    summarize(fAPAR_peak = max(frac_PAR_absorbed, na.rm = TRUE),
              LUE_peak   = max(inst_canopy_A_per_abs_PAR_umol_per_umol,
                               na.rm = TRUE),
              .groups = "drop")

  compute_block <- function(site_code, spacing_in, metric) {
    d <- plot_peaks %>% filter(Site == site_code, Spacing == spacing_in)
    b <- d %>% filter(Leaf_type == "Broad")  %>% pull(.data[[metric]])
    n <- d %>% filter(Leaf_type == "Narrow") %>% pull(.data[[metric]])
    if (length(b) < 2 || length(n) < 2) return(NULL)
    w  <- wilcox.test(b, n, exact = FALSE)
    cd <- cohens_d(b, n)
    list(n_Broad     = length(b),  n_Narrow    = length(n),
         mean_Broad  = mean(b),    mean_Narrow = mean(n),
         sd_Broad    = sd(b),      sd_Narrow   = sd(n),
         diff_BminN  = mean(b) - mean(n),
         cohens_d    = cd,
         wilcox_p    = w$p.value)
  }

  format_block <- function(s, spacing, metric_label, unit_str = "") {
    if (is.null(s)) return(sprintf(
      "  %s: insufficient data for Cohen's d\n", ROW_LAB[[spacing]]))
    pv_str <- if (s$wilcox_p < 1e-10) sprintf("P < 1e-10 (%.2e)", s$wilcox_p)
              else sprintf("P = %.4e", s$wilcox_p)
    paste0(
      sprintf("  %s — Broad vs Narrow %s\n", ROW_LAB[[spacing]], metric_label),
      sprintf("    n_Broad = %d, n_Narrow = %d\n", s$n_Broad, s$n_Narrow),
      sprintf("    Broad  mean +/- SD = %.4f +/- %.4f %s\n",
              s$mean_Broad,  s$sd_Broad,  unit_str),
      sprintf("    Narrow mean +/- SD = %.4f +/- %.4f %s\n",
              s$mean_Narrow, s$sd_Narrow, unit_str),
      sprintf("    Mean diff (B - N)  = %+.4f %s\n", s$diff_BminN, unit_str),
      sprintf("    Cohen's d (B - N pooled) = %+.3f\n", s$cohens_d),
      sprintf("    Wilcoxon : %s\n", pv_str),
      "\n")
  }

  append_to_stats <- function(path, site_code, metric, metric_label, unit_str) {
    s15 <- compute_block(site_code, 15, metric)
    s30 <- compute_block(site_code, 30, metric)
    txt <- paste0(
      "\n",
      "================================================================================\n",
      sprintf("Broad-vs-Narrow comparison (per spacing) — per-plot peak %s\n", metric_label),
      "Convention: Cohen's d = (Broad - Narrow) / pooled SD; positive = Broad > Narrow\n",
      "================================================================================\n\n",
      format_block(s15, "15", metric_label, unit_str),
      format_block(s30, "30", metric_label, unit_str)
    )
    cat(txt, file = path, append = TRUE)
  }

  append_to_stats(STATS_FILE$fAPAR[["SF"]], "SF", "fAPAR_peak", "fAPAR", "(unitless)")
  append_to_stats(STATS_FILE$fAPAR[["EF"]], "EF", "fAPAR_peak", "fAPAR", "(unitless)")
  append_to_stats(STATS_FILE$LUE[["SF"]],   "SF", "LUE_peak", "canopy LUE", "umol CO2 / umol aPAR")
  append_to_stats(STATS_FILE$LUE[["EF"]],   "EF", "LUE_peak", "canopy LUE", "umol CO2 / umol aPAR")

  # Narrow-minus-broad difference in class-mean fAPAR on the first date of each row spacing,
  # appended to the two fAPAR statistics files.
  append_first_date_fapar <- function(path, site_code) {
    txt <- paste0(
      "\n",
      "================================================================================\n",
      "Narrow-minus-broad difference in class-mean fAPAR on the first date\n",
      "================================================================================\n\n")
    for (sp in c(15, 30)) {
      cm <- class_means[class_means$Site == site_code & class_means$Spacing == sp, ]
      first_dap <- min(cm$DAP)
      narrow <- cm$fAPAR[cm$DAP == first_dap & cm$Leaf_type == "Narrow"]
      broad  <- cm$fAPAR[cm$DAP == first_dap & cm$Leaf_type == "Broad"]
      txt <- paste0(txt, sprintf("  %s, DAP %d: Narrow %.3f, Broad %.3f, difference %+.3f (%+.1f%%)\n",
                                 ROW_LAB[[as.character(sp)]], as.integer(first_dap), narrow, broad,
                                 narrow - broad, 100 * (narrow - broad) / broad))
    }
    cat(txt, file = path, append = TRUE)
  }
  append_first_date_fapar(STATS_FILE$fAPAR[["SF"]], "SF")
  append_first_date_fapar(STATS_FILE$fAPAR[["EF"]], "EF")

  cat("\nWrote the four statistics files.\n\n")

  for (s in c("SF","EF")) {
    for (m in c("fAPAR_peak", "LUE_peak")) {
      cat(sprintf("=== %s %s ===\n", s, m))
      for (sp in c(15, 30)) {
        b <- compute_block(s, sp, m)
        if (!is.null(b)) {
          cat(sprintf("  %s: d = %+.3f, P = %.3e, n_B = %d, n_N = %d\n",
                      ROW_LAB[[as.character(sp)]], b$cohens_d, b$wilcox_p, b$n_Broad, b$n_Narrow))
        }
      }
    }
  }
}

# ==================================================================================================
# Section fig3cd
# Figs 3C-D and S7C-D: Vertical and within-layer distribution of absorbed PAR in broad- and
# narrow-leaflet canopies
# ==================================================================================================
#
# Purpose
#   Uses the Helios sub-leaf element outputs of every plot of each site x row spacing x leaflet
#   type class on the date of that class's highest mean LAI (the plots and dates of Fig. 2D).
#   Within each plot, elements are sorted by height from the canopy top and cumulative LAI is
#   their summed area divided by the 9 m2 simulated ground area (Methods S1.10).
#   The vertical distribution is the cumulative share of the plot's absorbed PAR against
#   cumulative LAI on a 0.05-LAI grid, averaged across plots (Fig. 3C SoyFACE, Fig. S7C Energy
#   Farm). It is summarized by L50, the cumulative LAI at which the plot's absorbed PAR first
#   reaches half of its total.
#   The within-layer spread is the leaf-area-weighted coefficient of variation (CV) of absorbed
#   PAR per unit leaf area among the elements of each 0.5-LAI layer to a cumulative LAI of 6,
#   drawn as mean and SE of plots (Fig. 3D SoyFACE, Fig. S7D Energy Farm). It is summarized by
#   the mean over the twelve layers for plots with LAI of 6 or more.
#   Leaflet types are compared within each site x row spacing by a two-sided Wilcoxon rank-sum
#   test (normal approximation with continuity and tie corrections) and Cohen's d (pooled SD,
#   positive when broad exceeds narrow). The P value is computed directly because wilcox.test in
#   R 4.6.1 returns 0 for P below about 1e-16. These give the L50, CV and n and d values of the
#   panels and the Results. The section stops unless its pooled shares of canopy A in the top 25%
#   of leaf area and its total LAI reproduce the Fig. 2D table.
#
# Per-plot metrics in Fig3CD_absorbed_PAR_per_plot.csv
#   LAI               plot LAI
#   top25_absPAR      share of absorbed PAR in the top 25% of the plot's leaf area
#   top25_A           the same for net A
#   L50               cumulative LAI from the top at which half of the plot's absorbed PAR is
#                     captured
#   cv_layer_01..12   leaf-area-weighted CV of absorbed PAR among the elements of each 0.5-LAI
#                     layer from the top (layer 1 = LAI 0-0.5, ..., layer 12 = LAI 5.5-6),
#                     empty below the plot's LAI
#   cv_within         mean of cv_layer_01..12 (plots with LAI >= 6)
#
# Inputs
#   outputs/helios/helios_canopy_summary_{SF,EF}.csv          Helios canopy summary, one row per
#                                                             plot and date (simulation group)
#   outputs/helios/{SF,EF}/per_leaf/<Loc_ID>_DAP<ddd>.csv     Helios sub-leaf element outputs of
#                                                             each plot and date (simulation group)
#   outputs/figures/Figure2/Fig2D_top25_share.csv             Fig. 2D top-25% table, used as a
#                                                             check (section fig2d)
#
# Outputs
#   outputs/figures/Figure3/Fig3C_absorbed_PAR_by_depth_SF.png      Fig. 3C
#   outputs/figures/Figure3/Fig3D_within_layer_CV_SF.png            Fig. 3D
#   outputs/figures/FigureS7/FigS7C_absorbed_PAR_by_depth_EF.png    Fig. S7C
#   outputs/figures/FigureS7/FigS7D_within_layer_CV_EF.png          Fig. S7D
#   outputs/figures/Figure3/Fig3CD_absorbed_PAR_top25_share.csv     pooled top-25% shares of
#                                                                   absorbed PAR and net A by class
#   outputs/figures/Figure3/Fig3CD_absorbed_PAR_per_plot.csv        per-plot metrics (above)
#   outputs/figures/Figure3/Fig3CD_absorbed_PAR_stats.txt           shares, L50, within-layer CV and
#                                                                   leaflet-type tests, both sites

fig3cd <- function() {
  HEL       <- file.path(ROOT, "outputs", "helios")
  OUT       <- file.path(ROOT, "outputs", "figures", "Figure3")
  OUT_SUPP  <- file.path(ROOT, "outputs", "figures", "FigureS7")
  TOP25_2D  <- file.path(ROOT, "outputs", "figures", "Figure2", "Fig2D_top25_share.csv")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
  dir.create(OUT_SUPP, showWarnings = FALSE, recursive = TRUE)
  GROUND    <- 9                           # m2, the 3 x 3 m simulated canopy
  DL        <- 0.5                         # layer thickness, LAI units
  NL        <- 12                          # layers to cumulative LAI 6
  LGRID     <- seq(0, 6, by = 0.05)        # cumulative LAI grid for the vertical profiles
  SITE_LAB  <- c(EF = "Energy Farm", SF = "SoyFACE")
  SP_LAB    <- c(`15` = "38 cm", `30` = "76 cm")
  LEAF_COLS <- c(Narrow = "#00BFFF", Broad = "#FFD700")
  SP_LT     <- c(`38 cm` = "solid", `76 cm` = "22")
  SP_SH     <- c(`38 cm` = 21, `76 cm` = 22)

  # Panel files, SoyFACE in Fig. 3 and the Energy Farm in Fig. S7.
  PANEL_FILE <- list(
    depth = c(SF = file.path(OUT, "Fig3C_absorbed_PAR_by_depth_SF.png"),
              EF = file.path(OUT_SUPP, "FigS7C_absorbed_PAR_by_depth_EF.png")),
    cv    = c(SF = file.path(OUT, "Fig3D_within_layer_CV_SF.png"),
              EF = file.path(OUT_SUPP, "FigS7D_within_layer_CV_EF.png")))

  ## 1. Plots and dates, as in Fig. 2D (the date with the highest mean LAI of each class)
  h  <- rbindlist(lapply(c("EF", "SF"), function(s) fread(file.path(HEL, sprintf("helios_canopy_summary_%s.csv", s)))), fill = TRUE)
  h  <- h[Leaf_type %in% c("Broad", "Narrow")]
  pk <- h[, .(LAI = mean(LAI_used, na.rm = TRUE)), by = .(Site, Spacing, Leaf_type, DAP)]
  pk <- pk[order(Site, Spacing, Leaf_type, -LAI)][, .SD[1], by = .(Site, Spacing, Leaf_type)]
  cat("Peak-LAI DAP of each class\n"); print(pk)

  ## 2. Per-leaf files and per-plot metrics
  cv_w <- function(v, w) { m <- sum(w * v) / sum(w); sqrt(sum(w * (v - m)^2) / sum(w)) / m }
  plot_metrics <- function(d) {                       # one plot's elements, sorted from the top
    L   <- cumsum(d$leaf_area_m2) / GROUND; Lt <- L[length(L)]
    par <- d$abs_PAR_W_m2 * d$leaf_area_m2; F <- cumsum(par) / sum(par)
    a   <- d$A_umol_m2_s * d$leaf_area_m2
    k   <- which(L / Lt >= 0.25)[1]
    lay <- ceiling(L / DL)
    cvl <- vapply(seq_len(NL), function(i) if (i * DL <= Lt) cv_w(d$abs_PAR_W_m2[lay == i], d$leaf_area_m2[lay == i]) else NA_real_, 0)
    Fg  <- ifelse(LGRID <= Lt, c(0, F)[findInterval(LGRID, c(0, L))], NA_real_)
    list(stats = c(list(LAI = Lt, top25_absPAR = F[k], top25_A = sum(a[1:k]) / sum(a), L50 = L[which(F >= 0.5)[1]],
                        cv_within = if (Lt >= NL * DL) mean(cvl) else NA_real_),
                   setNames(as.list(cvl), sprintf("cv_layer_%02d", seq_len(NL)))),
         curve = Fg)
  }
  top25 <- list(); per_plot <- list(); curves <- list()
  for (i in seq_len(nrow(pk))) {
    g <- pk[i]
    locs <- unique(h[Site == g$Site & Spacing == g$Spacing & Leaf_type == g$Leaf_type & DAP == g$DAP, Loc_ID])
    fps  <- file.path(HEL, g$Site, "per_leaf", sprintf("%s_DAP%03d.csv", locs, g$DAP))
    stopifnot(all(file.exists(fps)))
    d <- rbindlist(lapply(seq_along(fps), function(j)
      fread(fps[j], select = c("z_m", "leaf_area_m2", "abs_PAR_W_m2", "A_umol_m2_s"))[, Loc_ID := locs[j]]))
    d <- d[order(-z_m)]                                # stable sort, so tied heights keep the file order as with dplyr::arrange
    key <- g[, .(Site, Spacing, Leaf_type, DAP)]
    # Pooled shares of the whole class, computed as in Fig. 2D, to check against the Fig. 2D table.
    x  <- cumsum(d$leaf_area_m2) / sum(d$leaf_area_m2); k <- which(x >= 0.25)[1]
    cp <- cumsum(d$abs_PAR_W_m2 * d$leaf_area_m2); cA <- cumsum(d$A_umol_m2_s * d$leaf_area_m2)
    top25[[i]] <- cbind(key, n_plots = length(locs), total_LAI = sum(d$leaf_area_m2) / (GROUND * length(locs)),
                        absPAR_top25 = cp[k] / cp[length(cp)], A_top25 = cA[k] / cA[length(cA)])
    res <- lapply(split(d, by = "Loc_ID", keep.by = FALSE)[locs], plot_metrics)
    per_plot[[i]] <- cbind(key[rep(1, length(locs))], Loc_ID = locs, rbindlist(lapply(res, `[[`, "stats")))
    cm <- do.call(cbind, lapply(res, `[[`, "curve"))
    curves[[i]] <- cbind(key, LAI_from_top = LGRID, absPAR_frac = rowMeans(cm, na.rm = TRUE), n_plots = rowSums(!is.na(cm)))
    cat(sprintf("  %s %s %-6s DAP %d: %d plots, %d elements\n", g$Site, SP_LAB[as.character(g$Spacing)], g$Leaf_type, g$DAP, length(locs), nrow(d)))
    rm(d, res); invisible(gc())
  }
  top25 <- rbindlist(top25); per_plot <- rbindlist(per_plot); curves <- rbindlist(curves)

  ## 3. Check that the plots, dates and pooling are those of Fig. 2D
  chk <- merge(top25, fread(TOP25_2D), by = c("Site", "Spacing", "Leaf_type"))
  stopifnot(nrow(chk) == 8, max(abs(chk$A_top25 - chk$A_at_top25)) < 1e-6, max(abs(chk$total_LAI.x - chk$total_LAI.y)) < 1e-6)

  ## 4. Leaflet-type tests per site x row spacing
  wilcox_p <- function(b, n) {                        # two-sided, normal approximation with continuity and tie corrections
    r <- rank(c(b, n)); n1 <- length(b); n2 <- length(n); N <- n1 + n2
    W <- sum(r[seq_len(n1)]) - n1 * (n1 + 1) / 2; tt <- table(r)
    s <- sqrt(n1 * n2 / 12 * ((N + 1) - sum(tt^3 - tt) / (N * (N - 1))))
    z <- W - n1 * n2 / 2; z <- (z - sign(z) * 0.5) / s
    2 * pnorm(-abs(z))
  }
  d_coh <- function(b, n) (mean(b) - mean(n)) / sqrt(((length(b) - 1) * var(b) + (length(n) - 1) * var(n)) / (length(b) + length(n) - 2))
  METRICS <- c("LAI", "top25_absPAR", "top25_A", "L50", "cv_within", sprintf("cv_layer_%02d", seq_len(NL)))
  tests <- rbindlist(lapply(METRICS, function(m) per_plot[, {
    b <- na.omit(get(m)[Leaf_type == "Broad"]); n <- na.omit(get(m)[Leaf_type == "Narrow"])
    .(metric = m, n_broad = length(b), n_narrow = length(n), mean_broad = mean(b), mean_narrow = mean(n),
      P_wilcoxon = wilcox_p(b, n), cohens_d = d_coh(b, n))
  }, by = .(Site, Spacing)]))

  ## 5. Tables and statistics
  fwrite(top25, file.path(OUT, "Fig3CD_absorbed_PAR_top25_share.csv"))
  fwrite(per_plot, file.path(OUT, "Fig3CD_absorbed_PAR_per_plot.csv"))
  lab <- function(s, sp) paste(SITE_LAB[s], SP_LAB[as.character(sp)])
  fmtp <- function(p) ifelse(p < 1e-3, sprintf("%.1e", p), sprintf("%.3f", p))
  tl <- function(m, title, scale = 1, fmt = "%.3f") {
    x <- tests[metric == m]
    c(title, sprintf(paste0("  %-18s n %3d/%3d  Broad ", fmt, "  Narrow ", fmt, "  P = %s  d = %+.2f"),
                     lab(x$Site, x$Spacing), x$n_broad, x$n_narrow, scale * x$mean_broad, scale * x$mean_narrow,
                     fmtp(x$P_wilcoxon), x$cohens_d), "")
  }
  lay <- tests[grepl("^cv_layer_", metric)]
  txt <- c("Figs 3C-D and S7C-D: absorbed PAR in broad- and narrow-leaflet canopies at each class's peak-LAI date (Helios per-leaf outputs)",
           "Plots, dates and pooling checked against Fig 2D (its canopy A shares and total LAI reproduced)",
           "Per-plot means; two-sided Wilcoxon rank-sum P; Cohen's d (pooled SD, positive = Broad > Narrow)",
           "",
           "Pooled shares, Fig 2D definition (share in the top 25% of leaf area), absorbed PAR and net A",
           sprintf("  %-18s %-6s DAP %d, %3d plots, LAI %5.2f: absorbed PAR %4.1f%%, net A %4.1f%%",
                   lab(top25$Site, top25$Spacing), top25$Leaf_type, top25$DAP, top25$n_plots, top25$total_LAI,
                   100 * top25$absPAR_top25, 100 * top25$A_top25),
           "",
           tl("LAI", "Plot LAI (m2 m-2)", fmt = "%.2f"),
           tl("top25_absPAR", "Share of absorbed PAR in the top 25% of the plot's leaf area (%)", 100, "%.1f"),
           tl("L50", "Cumulative LAI from the top above which half of the plot's absorbed PAR is captured (L50)"),
           tl("cv_within", "Within-layer CV of absorbed PAR, mean of the twelve 0.5-LAI layers to LAI 6 (plots with LAI >= 6)"),
           "Within-layer CV by layer (LAI from the top): Broad / Narrow, P",
           sprintf("  %-18s %s", lab(unique(lay[, .(Site, Spacing)])$Site, unique(lay[, .(Site, Spacing)])$Spacing),
                   vapply(split(lay, by = c("Site", "Spacing")), function(x)
                     paste(sprintf("%.2f/%.2f%s", x$mean_broad, x$mean_narrow, ifelse(x$P_wilcoxon < 0.05, "*", "")), collapse = " "), "")),
           "  (* P < 0.05; layers 0-0.5, 0.5-1, ..., 5.5-6)",
           sprintf("  Layers with Narrow < Broad and P < 0.05: %d of %d", sum(lay$mean_narrow < lay$mean_broad & lay$P_wilcoxon < 0.05), nrow(lay)))
  con <- file(file.path(OUT, "Fig3CD_absorbed_PAR_stats.txt"), open = "w", encoding = "UTF-8"); writeLines(txt, con); close(con)
  cat(txt, sep = "\n")

  ## 6. Panels, with the theme of Fig. 2D
  pub_theme <- theme_minimal(base_size = 12) +
    theme(plot.title = element_text(size = 18, face = "bold", hjust = 0.5, margin = margin(b = 6)),
          axis.title.x = element_text(size = 18, face = "bold", color = "black", margin = margin(t = 6)),
          axis.title.y = element_text(size = 18, face = "bold", color = "black", margin = margin(r = 4)),
          axis.text.x = element_text(size = 14, color = "black"), axis.text.y = element_text(size = 14, color = "black"),
          axis.ticks = element_line(color = "black", linewidth = 0.8), axis.ticks.length = unit(0.2, "cm"),
          panel.grid.major = element_line(color = "gray90", linewidth = 0.3), panel.grid.minor = element_blank(),
          panel.border = element_rect(color = "black", fill = NA, linewidth = 1.0),
          panel.background = element_rect(fill = "white"), plot.background = element_rect(fill = "white", color = NA),
          legend.position = "top", legend.title = element_text(face = "bold", size = 10), legend.text = element_text(size = 9),
          legend.box = "horizontal", legend.key.width = unit(0.9, "cm"), legend.key.height = unit(0.4, "cm"),
          legend.margin = margin(0, 0, 0, 0), legend.box.margin = margin(0, 0, -2, 0), plot.margin = margin(10, 14, 10, 10))
  fac <- function(x) x[, `:=`(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")),
                              Row_spacing = factor(SP_LAB[as.character(Spacing)], levels = c("38 cm", "76 cm")))]
  fac(curves)
  lp <- melt(per_plot, id.vars = c("Site", "Spacing", "Leaf_type", "Loc_ID"), measure.vars = sprintf("cv_layer_%02d", seq_len(NL)),
             variable.name = "layer", value.name = "cv", na.rm = TRUE)
  lp <- lp[, .(cv = mean(cv), se = sd(cv) / sqrt(.N), n = .N), by = .(Site, Spacing, Leaf_type, layer)]
  lp[, LAI_mid := (as.integer(sub("cv_layer_", "", layer)) - 0.5) * DL]
  fac(lp)
  for (s in c("EF", "SF")) {
    pE <- ggplot(curves[Site == s & n_plots > 0], aes(LAI_from_top, absPAR_frac, color = Leaf_type, linetype = Row_spacing,
                                                      group = interaction(Leaf_type, Row_spacing))) +
      geom_hline(yintercept = c(0.5, 0.8), linetype = "12", color = "gray60", linewidth = 0.3) +
      geom_line(linewidth = 1.2) +
      scale_x_continuous(breaks = 0:6, limits = c(0, 6), expand = c(0, 0)) +
      scale_y_continuous(labels = function(v) round(100 * v), breaks = seq(0, 1, 0.2), limits = c(0, 1), expand = c(0, 0)) +
      scale_color_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_linetype_manual(values = SP_LT, name = "Row spacing") +
      labs(title = SITE_LAB[[s]], x = expression(bold("Cumulative LAI from canopy top") ~ "(" * m^2 ~ m^-2 * ")"),
           y = expression(bold("Cumulative share of absorbed PAR") ~ "(%)")) +
      pub_theme
    ggsave(PANEL_FILE$depth[[s]], pE, width = 6.5, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)
    pF <- ggplot(lp[Site == s], aes(LAI_mid, cv, color = Leaf_type, linetype = Row_spacing, shape = Row_spacing,
                                    group = interaction(Leaf_type, Row_spacing))) +
      geom_errorbar(aes(ymin = cv - se, ymax = cv + se), width = 0.12, linetype = "solid", linewidth = 0.5) +
      geom_line(linewidth = 1.1) +
      geom_point(aes(fill = Leaf_type), color = "black", size = 2.6, stroke = 0.5) +
      scale_x_continuous(breaks = 0:6, limits = c(0, 6), expand = c(0, 0)) +
      scale_color_manual(values = LEAF_COLS, name = "Leaflet type") +
      scale_fill_manual(values = LEAF_COLS, guide = "none") +
      scale_linetype_manual(values = SP_LT, name = "Row spacing") +
      scale_shape_manual(values = SP_SH, name = "Row spacing") +
      labs(title = SITE_LAB[[s]], x = expression(bold("Cumulative LAI from canopy top") ~ "(" * m^2 ~ m^-2 * ")"),
           y = "Within-layer CV of absorbed PAR") +
      pub_theme
    ggsave(PANEL_FILE$cv[[s]], pF, width = 6.5, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)
  }
  cat("\nWrote Figs. 3C-D and S7C-D panels, Fig3CD_absorbed_PAR_top25_share.csv,",
      "Fig3CD_absorbed_PAR_per_plot.csv and Fig3CD_absorbed_PAR_stats.txt\n")
}

# ==================================================================================================
# Section fig4a
# Fig 4A: Helios three-dimensional against one-dimensional sun-shade canopy net photosynthesis
# ==================================================================================================
#
# Purpose
#   Plots Helios canopy net photosynthesis (canopy A) against the canopy A of the one-dimensional
#   sun-shade model of de Pury & Farquhar (1997), run with the Helios leaf energy balance and
#   Buckley-Mott-Farquhar stomatal model, for all 5,299 plot-dates with the 1:1 line (Fig. 4A).
#   The statistics file gives the Pearson r, R2, RMSE, mean bias (3D minus 1D) and the
#   least-squares line of 3D on 1D. The r and RMSE are quoted in Fig. 4A and the Results.
#
# Inputs
#   outputs/one_dimensional_model/helios_vs_1D_per_plot.csv   Helios and 1D canopy A for each plot
#                                                             and date (simulation group)
#
# Outputs
#   outputs/figures/Figure4/Fig4A_helios_vs_1D.png         Fig. 4A
#   outputs/figures/Figure4/Fig4A_helios_vs_1D_stats.txt   agreement statistics

fig4a <- function() {
  COMP_CSV  <- file.path(ROOT, "outputs", "one_dimensional_model", "helios_vs_1D_per_plot.csv")
  OUT       <- file.path(ROOT, "outputs", "figures", "Figure4")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type colors, shared by all figures of the paper.
  BROAD_COL  <- "#FFD700"
  NARROW_COL <- "#00BFFF"
  LEAF_COLS  <- c("Broad" = BROAD_COL, "Narrow" = NARROW_COL)

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title        = element_text(size = 14, face = "bold", hjust = 0.5,
                                       margin = margin(b = 6)),
      plot.subtitle     = element_text(size = 11, hjust = 0.5, color = "gray25"),
      axis.title.x      = element_text(size = 16, face = "bold", color = "black",
                                       margin = margin(t = 6)),
      axis.title.y      = element_text(size = 16, face = "bold", color = "black",
                                       margin = margin(r = 4)),
      axis.text         = element_text(size = 13, color = "black"),
      axis.ticks        = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length = unit(0.2, "cm"),
      panel.grid.major  = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      panel.border      = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background  = element_rect(fill = "white"),
      plot.background   = element_rect(fill = "white", color = NA),
      legend.position   = "top",
      legend.title      = element_text(face = "bold", size = 10),
      legend.text       = element_text(size = 9),
      legend.key.width  = unit(0.8, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.margin     = margin(0, 0, 0, 0),
      plot.margin       = margin(10, 14, 10, 10)
    )

  # One row per plot and date. Spacing is coded in inches (15 = 38-cm rows, 30 = 76-cm rows).
  d <- read_csv(COMP_CSV, show_col_types = FALSE) %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Narrow", "Broad")),
           Spacing   = factor(as.character(Spacing), levels = c("15", "30")))
  cat(sprintf("Loaded %d plot-DAP rows (Helios and 1D sun-shade canopy A)\n", nrow(d)))

  # Agreement between the two models over all plot-dates.
  fit_stats <- function(x) {
    a3D <- x$A_umol_m2_s
    a1D <- x$canopy_A_DePuryEB
    r    <- cor(a3D, a1D)
    rmse <- sqrt(mean((a3D - a1D)^2))
    bias <- mean(a3D - a1D)
    fit  <- lm(a3D ~ a1D)
    list(r = r, r2 = r^2, rmse = rmse, bias = bias, n = nrow(x),
         slope = unname(coef(fit)[2]), intercept = unname(coef(fit)[1]))
  }
  s_all <- fit_stats(d)

  # Panel with equal axes and the 1:1 line.
  ax_min <- floor(min(c(d$A_umol_m2_s, d$canopy_A_DePuryEB), na.rm = TRUE) - 1)
  ax_max <- ceiling(max(c(d$A_umol_m2_s, d$canopy_A_DePuryEB), na.rm = TRUE) + 1)

  # The 1:1 line is drawn after the points, in red, so that it stays visible on top of them.
  p <- ggplot(d, aes(x = canopy_A_DePuryEB, y = A_umol_m2_s)) +
    geom_point(aes(fill = Leaf_type, shape = Spacing),
               color = "black", size = 1.4, stroke = 0.2, alpha = 0.55) +
    geom_abline(slope = 1, intercept = 0,
                linetype = "dashed", color = "red", linewidth = 0.8) +
    scale_fill_manual(values = LEAF_COLS, name = "Leaflet type",
                      guide = guide_legend(override.aes = list(shape = 21, size = 3.5, alpha = 1))) +
    scale_shape_manual(values = c("15" = 21, "30" = 22),
                       name = "Row spacing (in)",
                       guide = guide_legend(override.aes = list(alpha = 1))) +
    scale_x_continuous(limits = c(ax_min, ax_max),
                       breaks = seq(-30, 60, 10), expand = c(0.01, 0)) +
    scale_y_continuous(limits = c(ax_min, ax_max),
                       breaks = seq(-30, 60, 10), expand = c(0.01, 0)) +
    coord_fixed() +
    labs(x = expression(bold("sun-shade 1D+EB canopy A") ~
                         "(" * mu * mol ~ CO[2] ~ m^-2 ~ s^-1 * ")"),
         y = expression(bold("Helios 3D canopy A") ~
                         "(" * mu * mol ~ CO[2] ~ m^-2 ~ s^-1 * ")")) +
    pub_theme

  ggsave(file.path(OUT, "Fig4A_helios_vs_1D.png"),
         p, width = 6.5, height = 7.0, dpi = 300, bg = "white", device = ragg::agg_png)

  # Statistics file. The values are reported here and not drawn on the panel.
  sink(file.path(OUT, "Fig4A_helios_vs_1D_stats.txt"))
  cat("================================================================================\n")
  cat("Fig 4A stats - Helios 3D vs sun-shade 1D+EB per-plot agreement\n")
  cat("Source: outputs/one_dimensional_model/helios_vs_1D_per_plot.csv\n")
  cat("1D model: de Pury sun/shade light scheme + Helios-matched energy balance + BMF stomata.\n")
  cat("Unit of replication: one observation per plot-DAP pair (Loc_ID x DAP).\n")
  cat("Bias convention: mean(3D - 1D); positive => 3D > 1D.\n")
  cat("================================================================================\n\n")
  cat("--- All plot-DAP pairs ---\n")
  cat(sprintf("  n           : %d\n", s_all$n))
  cat(sprintf("  Pearson r   : %+.4f\n", s_all$r))
  cat(sprintf("  R^2         : %.4f\n", s_all$r2))
  cat(sprintf("  RMSE        : %.3f umol CO2 m-2 s-1\n", s_all$rmse))
  cat(sprintf("  Bias (3D-1D): %+.3f umol CO2 m-2 s-1\n", s_all$bias))
  cat(sprintf("  Linear fit  : 3D = %.4f * 1D + %+.4f\n", s_all$slope, s_all$intercept))
  sink()

  cat(sprintf("\nWrote: %s\n", file.path(OUT, "Fig4A_helios_vs_1D.png")))
  cat(sprintf("Fig 4A: n=%d, r=%+.3f, R^2=%.3f, RMSE=%.2f, bias=%+.2f\n",
              s_all$n, s_all$r, s_all$r2, s_all$rmse, s_all$bias))
}

# ==================================================================================================
# Section fig4b
# Fig 4B: Narrow-minus-broad canopy net photosynthesis from the one-dimensional and Helios models
# and the 3D architectural residual
# ==================================================================================================
#
# Purpose
#   Averages canopy net photosynthesis (canopy A) of each model over the plots of each site, row
#   spacing, leaflet type and date, then over the dates of each site x row spacing x leaflet
#   type. For each site x row spacing, the narrow-minus-broad difference is computed for the 1D
#   sun-shade model and for Helios, and their difference (Helios minus 1D) is the 3D
#   architectural residual. The three values are drawn as grouped bars (Fig. 4B). The statistics
#   file gives the class means, the three differences and the residual as a share of the Helios
#   difference. These values are quoted in the Results and listed in Table S19.
#
# Inputs
#   outputs/one_dimensional_model/helios_vs_1D_per_plot.csv   Helios and 1D canopy A for each plot
#                                                             and date (simulation group)
#
# Outputs
#   outputs/figures/Figure4/Fig4B_architectural_residual.png         Fig. 4B
#   outputs/figures/Figure4/Fig4B_architectural_residual_stats.txt   decomposition by site x row
#                                                                    spacing

fig4b <- function() {
  COMP_CSV <- file.path(ROOT, "outputs", "one_dimensional_model", "helios_vs_1D_per_plot.csv")
  OUT      <- file.path(ROOT, "outputs", "figures", "Figure4")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title        = element_text(size = 16, face = "bold", hjust = 0.5,
                                       margin = margin(b = 6)),
      axis.title.x      = element_text(size = 17, face = "bold", color = "black",
                                       margin = margin(t = 6)),
      axis.title.y      = element_text(size = 17, face = "bold", color = "black",
                                       margin = margin(r = 4)),
      axis.text         = element_text(size = 13, color = "black"),
      axis.ticks        = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length = unit(0.2, "cm"),
      panel.grid.major  = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      panel.border      = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background  = element_rect(fill = "white"),
      plot.background   = element_rect(fill = "white", color = NA),
      legend.position   = "top",
      legend.title      = element_text(face = "bold", size = 10),
      legend.text       = element_text(size = 9),
      legend.key.width  = unit(0.9, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.margin     = margin(0, 0, 0, 0),
      plot.margin       = margin(10, 14, 10, 10)
    )

  metric_cols <- c("sun-shade 1D+EB"            = "#888888",
                   "Helios 3D"                  = "#222222",
                   "3D architectural residual"  = "#D55E00")

  # Two-step averaging. Plots are averaged within each site x row spacing x leaflet type x date,
  # and these means are averaged over the dates of each site x row spacing x leaflet type.
  per_plot <- read_csv(COMP_CSV, show_col_types = FALSE) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(A_umol_m2_s), !is.na(canopy_A_DePuryEB))

  loc_sp_leaf_dap <- per_plot %>%
    group_by(Site, Spacing, Leaf_type, DAP) %>%
    summarize(Helios = mean(A_umol_m2_s),
              DePury = mean(canopy_A_DePuryEB),
              .groups = "drop")

  loc_sp_leaf <- loc_sp_leaf_dap %>%
    group_by(Site, Spacing, Leaf_type) %>%
    summarize(Helios_mean = mean(Helios),
              DePury_mean = mean(DePury),
              .groups = "drop")

  # Narrow-minus-broad difference of each model and the architectural residual. The bar groups
  # are labeled <site>-<spacing code>in in the panel (Spacing 15 = 38-cm rows, 30 = 76-cm rows).
  gap <- loc_sp_leaf %>%
    pivot_wider(names_from = Leaf_type,
                values_from = c(Helios_mean, DePury_mean)) %>%
    mutate(Helios_NB = Helios_mean_Narrow - Helios_mean_Broad,
           DePury_NB = DePury_mean_Narrow - DePury_mean_Broad,
           arch3D_NB = Helios_NB - DePury_NB,
           Group     = paste0(Site, "-", Spacing, "in"))

  cat("\n=== Per Location x Spacing, Narrow-Broad gap decomposition ===\n")
  print(gap %>%
          select(Site, Spacing, Helios_NB, DePury_NB, arch3D_NB) %>%
          mutate(across(where(is.numeric), ~ round(.x, 2))))

  gap_long <- gap %>%
    select(Group, Site, Spacing, Helios_NB, DePury_NB, arch3D_NB) %>%
    pivot_longer(c(Helios_NB, DePury_NB, arch3D_NB),
                 names_to = "metric", values_to = "value") %>%
    mutate(metric = factor(metric,
                           levels = c("DePury_NB", "Helios_NB", "arch3D_NB"),
                           labels = c("sun-shade 1D+EB",
                                      "Helios 3D",
                                      "3D architectural residual")),
           Group  = factor(Group,
                           levels = c("EF-15in","EF-30in","SF-15in","SF-30in")))

  p <- ggplot(gap_long, aes(x = Group, y = value, fill = metric)) +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    geom_col(position = position_dodge(width = 0.78),
             color = "black", linewidth = 0.4, width = 0.72) +
    scale_fill_manual(values = metric_cols,
                      name = "Narrow - Broad gap source",
                      guide = guide_legend(nrow = 1)) +
    scale_y_continuous(breaks = seq(-2, 5, 1)) +
    labs(x = "Location x Row spacing",
         y = expression(bold("Narrow - Broad canopy A gap") ~
                         "(" * mu * mol ~ CO[2] ~ m^-2 ~ s^-1 * ")")) +
    pub_theme

  ggsave(file.path(OUT, "Fig4B_architectural_residual.png"),
         p, width = 8.0, height = 5.5, dpi = 300, bg = "white", device = ragg::agg_png)

  # Statistics file.
  ROW_LAB <- c("15" = "38-cm rows", "30" = "76-cm rows")
  sink(file.path(OUT, "Fig4B_architectural_residual_stats.txt"))
  cat("================================================================================\n")
  cat("Fig 4B stats - Narrow - Broad canopy A gap, decomposed by model\n")
  cat("Source: outputs/one_dimensional_model/helios_vs_1D_per_plot.csv\n")
  cat("1D model: de Pury sun/shade + Helios-matched energy balance + BMF stomata.\n")
  cat("Aggregation: per-plot -> mean within (Location x Spacing x Leaflet shape x DAP)\n")
  cat("            -> mean over DAPs within (Location x Spacing x Leaflet shape)\n")
  cat("Decomposition: per Location x Spacing,\n")
  cat("  Helios_NB   = mean(Helios)_Narrow - mean(Helios)_Broad\n")
  cat("  DePury_NB   = mean(1D+EB)_Narrow - mean(1D+EB)_Broad\n")
  cat("  arch_NB     = Helios_NB - DePury_NB  (3D gain beyond what 1D+EB explains)\n")
  cat("================================================================================\n\n")

  for (i in seq_len(nrow(gap))) {
    r <- gap[i, ]
    cat(sprintf("--- %s x %s ---\n", r$Site, ROW_LAB[[as.character(r$Spacing)]]))
    cat(sprintf("  Helios Narrow mean : %.2f umol CO2 m-2 s-1\n", r$Helios_mean_Narrow))
    cat(sprintf("  Helios Broad  mean : %.2f\n", r$Helios_mean_Broad))
    cat(sprintf("  Helios_NB          : %+.2f  (3D total Narrow-Broad gap)\n", r$Helios_NB))
    cat(sprintf("  1D+EB Narrow mean  : %.2f\n", r$DePury_mean_Narrow))
    cat(sprintf("  1D+EB Broad  mean  : %.2f\n", r$DePury_mean_Broad))
    cat(sprintf("  DePury_NB          : %+.2f  (1D+EB total Narrow-Broad gap)\n", r$DePury_NB))
    cat(sprintf("  arch3D_NB          : %+.2f  (architectural residual = Helios_NB - DePury_NB)\n",
                r$arch3D_NB))
    cat(sprintf("  Architectural share: %.1f%%  (arch3D_NB / Helios_NB)\n",
                100 * r$arch3D_NB / r$Helios_NB))
    cat("\n")
  }

  cat("--- Cross-group summary ---\n")
  cat(sprintf("  Helios_NB    range : %.2f to %.2f (across 4 Location x Spacing combinations)\n",
              min(gap$Helios_NB), max(gap$Helios_NB)))
  cat(sprintf("  DePury_NB    range : %.2f to %.2f\n",
              min(gap$DePury_NB), max(gap$DePury_NB)))
  cat(sprintf("  arch3D_NB    range : %.2f to %.2f\n",
              min(gap$arch3D_NB), max(gap$arch3D_NB)))
  cat(sprintf("  Mean architectural share across 4 groups: %.1f%%\n",
              100 * mean(gap$arch3D_NB / gap$Helios_NB)))
  sink()

  cat(sprintf("\nWrote the panel and statistics file to %s\n", OUT))
}

# ==================================================================================================
# Section fig5a
# Fig 5A: Measured and modeled light profiles against cumulative LAI at SoyFACE
# ==================================================================================================
#
# Purpose
#   Draws Fig. 5A. The measured profile is the LITES fraction of PAR intercepted, fIPAR(z) =
#   1 - PAR(z)/PAR(140 cm), at the six within-canopy heights (5-100 cm) of the 33 BC3 NIL plots
#   scanned at SoyFACE in 76-cm rows on 20-22 August 2024 (DAP 77-79), plotted against the SunScan
#   cumulative LAI above the same heights. Points are leaflet-type means with SE on both axes,
#   and the orange line is a Mitscherlich fit, f = A(1 - exp(-k L)), to all plot-height pairs. The
#   black line is the same fit to the per-bin median of the Helios cumulative fAPAR curves of the
#   31 of these plots simulated on DAP 76 (bins with at least five plots). The shaded band between
#   the two curves is the canopy reflectance to the sky, R_sky = fIPAR - fAPAR (Methods S1.9).
#
# Inputs
#   data/lites_sunscan/lites_sunscan_SF.xlsx    sheets plots, LITE and LAI
#   outputs/field_validation/lites_sunscan/helios_depth_curves_DAP076.csv
#                                                Helios cumulative fAPAR against cumulative LAI per
#                                                plot (03_lites_helios_pairing.R)
#
# Outputs
#   outputs/figures/Figure5/Fig5A_lites_helios_depth.png   panel without annotations

fig5a <- function() {
  XL   <- file.path(ROOT, "data", "lites_sunscan", "lites_sunscan_SF.xlsx")
  GC   <- file.path(ROOT, "outputs", "field_validation", "lites_sunscan", "helios_depth_curves_DAP076.csv")
  OUT_DIR <- file.path(ROOT, "outputs", "figures", "Figure5")
  OUT  <- file.path(OUT_DIR, "Fig5A_lites_helios_depth.png")
  dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
  H_CM <- c(H1 = 5, H2 = 20, H3 = 40, H4 = 60, H5 = 80, H6 = 100); REP_H <- c(`1` = 5, `2` = 20, `3` = 40, `4` = 60, `5` = 80, `6` = 100)

  ## ---- Measured: LITES fIPAR (mean of scans) paired with SunScan LAI above each height ----
  plots <- read.xlsx(XL, sheet = "plots"); plots$plot <- as.character(plots$ID)
  lite <- read.xlsx(XL, sheet = "LITE"); lite$plot <- as.character(lite$plot)
  lite <- lite[grepl("^[0-9]+$", lite$plot), ]
  fip <- do.call(rbind, lapply(1:6, function(i) data.frame(
    plot = lite$plot, height_cm = unname(H_CM[i]),
    fIPAR = pmin(pmax(1 - lite[[paste0("PAR_Den_H", i, "_Avg")]] / lite$PAR_Den_H8_Avg, 0), 1))))
  lites <- aggregate(fIPAR ~ plot + height_cm, fip, mean)
  lai <- read.xlsx(XL, sheet = "LAI"); lai$plot <- as.character(lai$plot)
  sun <- aggregate(LAI ~ plot + rep, lai[grepl("^[0-9]+$", lai$plot), ], mean)
  sun$height_cm <- unname(REP_H[as.character(sun$rep)])
  pair <- merge(lites, sun[c("plot", "height_cm", "LAI")], by = c("plot", "height_cm"))
  pair$Leaf_type <- plots$Leaf_type[match(pair$plot, plots$plot)]
  pair <- pair[!is.na(pair$Leaf_type), ]
  pair$shape <- factor(pair$Leaf_type, levels = c("Narrow", "Broad"))
  litfit <- nls(fIPAR ~ A * (1 - exp(-k * LAI)), data = pair, start = list(A = 0.98, k = 0.6))
  A <- unname(coef(litfit)["A"]); k <- unname(coef(litfit)["k"])

  ## ---- Modeled: median Helios curve across the paired plots, Mitscherlich fit ----
  hc  <- read.csv(GC)
  bin <- round(hc$LAI_above / 0.05)
  med <- data.frame(LAI_above = sort(unique(bin)) * 0.05,
                    fAPAR_median = tapply(hc$fAPAR_cum, bin, median), n = tapply(hc$fAPAR_cum, bin, length))
  med <- med[med$n >= 5, ]
  hfit <- nls(fAPAR_median ~ A_max * (1 - exp(-k_h * LAI_above)), data = med, start = list(A_max = 0.9, k_h = 0.5))
  hA <- unname(coef(hfit)["A_max"]); hk <- unname(coef(hfit)["k_h"])
  cat(sprintf("LITES fit: A = %.3f, k = %.3f (%d plots) | Helios fit: A = %.3f, k = %.3f (%d plots)\n",
              A, k, length(unique(pair$plot)), hA, hk, length(unique(hc$Loc_ID))))

  g    <- seq(0, 9, length.out = 400)
  hel  <- data.frame(LAI = g, f = hA * (1 - exp(-hk * g)))
  lit  <- data.frame(LAI = g, f = pmin(A * (1 - exp(-k * g)), 1))
  rsky <- data.frame(LAI = g, hel = hel$f, lit = lit$f)
  agg <- do.call(rbind, lapply(split(pair, list(pair$shape, pair$height_cm), drop = TRUE), function(d) data.frame(
    shape = d$shape[1], height_cm = d$height_cm[1], n = nrow(d),
    fIPAR = mean(d$fIPAR), LAI = mean(d$LAI),
    fIPAR_se = sd(d$fIPAR) / sqrt(nrow(d)), LAI_se = sd(d$LAI) / sqrt(nrow(d)))))

  ## ---- Plot ----
  HEL <- "#000000"; LIT <- "#D55E00"; RSKY <- "#C0C6CC"; NAR_F <- "#00BFFF"; BRO_F <- "#FFD700"
  pub_theme <- theme_minimal(base_size = 12) + theme(
    axis.title.x = element_text(size = 16, face = "bold", color = "black", margin = margin(t = 6)),
    axis.title.y = element_text(size = 16, face = "bold", color = "black", margin = margin(r = 4)),
    axis.text = element_text(size = 13, color = "black"),
    axis.ticks = element_line(color = "black", linewidth = 0.8), axis.ticks.length = unit(0.2, "cm"),
    panel.grid.major = element_line(color = "gray90", linewidth = 0.3), panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 1.0),
    panel.background = element_rect(fill = "white"), plot.background = element_rect(fill = "white", color = NA),
    legend.position = "top", legend.box = "vertical", legend.box.just = "left",
    legend.spacing.y = unit(0.02, "cm"), legend.margin = margin(0, 4, 2, 4),
    legend.title = element_text(face = "bold", size = 10), legend.text = element_text(size = 10),
    legend.key = element_blank(), plot.margin = margin(10, 14, 10, 10))

  p <- ggplot() +
    geom_ribbon(data = rsky, aes(y = LAI, xmin = hel, xmax = lit), fill = RSKY, alpha = 0.65, orientation = "y") +
    geom_path(data = hel, aes(x = f, y = LAI, color = "Helios fAPAR (modeled)"), linewidth = 1.3) +
    geom_path(data = lit, aes(x = f, y = LAI, color = "LITES fIPAR (measured)"), linewidth = 1.3) +
    geom_errorbar(data = agg, aes(x = fIPAR, ymin = LAI - LAI_se, ymax = LAI + LAI_se),
                  color = "gray35", width = 0.014, linewidth = 0.5) +
    geom_errorbar(data = agg, aes(y = LAI, xmin = fIPAR - fIPAR_se, xmax = fIPAR + fIPAR_se),
                  color = "gray35", width = 0.12, linewidth = 0.5, orientation = "y") +
    geom_point(data = agg, aes(x = fIPAR, y = LAI, fill = shape), shape = 21, size = 3.4, color = "black", stroke = 0.5) +
    scale_color_manual(values = c("Helios fAPAR (modeled)" = HEL, "LITES fIPAR (measured)" = LIT), name = NULL) +
    scale_fill_manual(values = c("Narrow" = NAR_F, "Broad" = BRO_F), name = "Leaflet type") +
    scale_x_continuous(limits = c(0, 1.02), breaks = seq(0, 1, 0.2), expand = c(0.005, 0)) +
    scale_y_reverse(limits = c(9, 0), breaks = seq(0, 9, 1), expand = c(0.01, 0)) +
    labs(x = "Fraction of PAR", y = "Cumulative LAI from top of canopy") +
    guides(color = guide_legend(order = 1, override.aes = list(linewidth = 1.3)),
           fill = guide_legend(order = 2, override.aes = list(size = 4))) +
    pub_theme
  ggsave(OUT, p, width = 6.1, height = 6.4, dpi = 300, bg = "white", device = ragg::agg_png)
  cat("Wrote outputs/figures/Figure5/Fig5A_lites_helios_depth.png\n")
}

# ==================================================================================================
# Section fig5b
# Fig 5B: SunScan leaf-area profiles of broad- and narrow-leaflet canopies at SoyFACE
# ==================================================================================================
#
# Purpose
#   Draws Fig. 5B. For each of the 39 plots of the SoyFACE field validation (76-cm rows, 20-22
#   August 2024, 22 Narrow and 17 Broad plots, the Broad class including six plots of the
#   recurrent parent LD11-2170), the SunScan cumulative LAI above each of six heights (5-100 cm) is
#   averaged over the two pole positions. Points are leaflet-type means with SE, and lines are
#   natural cubic splines through the means. Diamonds and dashed guides mark each class's
#   leaf-area median height, the height above which half of the class-mean total LAI lies,
#   interpolated linearly between measurement heights.
#
# Inputs
#   data/lites_sunscan/lites_sunscan_SF.xlsx    sheets LAI (SunScan cumulative LAI per plot, pole
#                                                position and height) and plots (plot sheet)
#
# Outputs
#   outputs/figures/Figure5/Fig5B_leaf_area_profile.png   panel without annotations

fig5b <- function() {
  XL   <- file.path(ROOT, "data", "lites_sunscan", "lites_sunscan_SF.xlsx")
  OUT  <- file.path(ROOT, "outputs", "figures", "Figure5")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
  REP_H <- c(`1`=5,`2`=20,`3`=40,`4`=60,`5`=80,`6`=100)                 # SunScan heights (cm)

  # Leaflet-type colors (fill and line), as in Fig. 5A.
  BROAD_COL<-"#FFD700"; NARROW_COL<-"#00BFFF"; BROAD_LINE<-"#FFD700"; NARROW_LINE<-"#00BFFF"
  LEAF_FILL<-c("Broad"=BROAD_COL,"Narrow"=NARROW_COL); LEAF_LINE<-c("Broad"=BROAD_LINE,"Narrow"=NARROW_LINE)
  pub_theme <- theme_minimal(base_size=12) + theme(
    axis.title.x=element_text(size=16,face="bold",color="black",margin=margin(t=6)),
    axis.title.y=element_text(size=16,face="bold",color="black",margin=margin(r=4)),
    axis.text=element_text(size=13,color="black"),
    axis.ticks=element_line(color="black",linewidth=0.8), axis.ticks.length=unit(0.2,"cm"),
    panel.grid.major=element_line(color="gray90",linewidth=0.3), panel.grid.minor=element_blank(),
    panel.border=element_rect(color="black",fill=NA,linewidth=1.0),
    panel.background=element_rect(fill="white"), plot.background=element_rect(fill="white",color=NA),
    legend.position="top", legend.title=element_text(face="bold",size=10), legend.text=element_text(size=9),
    legend.key.width=unit(0.9,"cm"), plot.margin=margin(10,14,10,10))

  # BC3 NIL (numeric names) and LD11-2170 plots, mean of the two pole positions per height.
  lai   <- read_excel(XL, sheet="LAI")   %>% mutate(plot=as.character(plot))
  plots <- read_excel(XL, sheet="plots") %>% mutate(plot=as.character(ID))
  sun <- lai %>% filter(grepl("^[0-9]+$",plot) | grepl("^LD11",plot)) %>%
    group_by(plot, rep) %>% summarize(LAI_above=mean(LAI,na.rm=TRUE), .groups="drop") %>%
    mutate(height_cm=REP_H[as.character(rep)]) %>%
    inner_join(plots %>% select(plot,Leaf_type), by="plot") %>%
    mutate(shape=factor(ifelse(Leaf_type=="Narrow","Narrow","Broad"), levels=c("Narrow","Broad")))
  profB <- sun %>% group_by(shape, height_cm) %>%
    summarize(LAI=mean(LAI_above), se=sd(LAI_above)/sqrt(n()), .groups="drop") %>% arrange(shape, height_cm)
  hg <- seq(5,100,length.out=400)
  smB <- profB %>% group_by(shape) %>% reframe(height=hg, LAI=pmax(spline(height_cm, LAI, xout=hg, method="natural")$y,0))

  # The leaf-area median height is where the class-mean cumulative LAI above reaches 50% of its total.
  med <- profB %>% group_by(shape) %>% group_modify(~{
    d <- arrange(.x, height_cm); tot <- d$LAI[d$height_cm==5]; tgt <- 0.5*tot
    dd <- arrange(d, desc(height_cm)); h <- NA_real_
    for (i in 1:(nrow(dd)-1)) { a<-dd[i,]; b<-dd[i+1,]
      if (a$LAI<tgt && b$LAI>=tgt) { h<-a$height_cm+(b$height_cm-a$height_cm)*(tgt-a$LAI)/(b$LAI-a$LAI); break } }
    tibble(median_h=h, x=tgt) }) %>% ungroup()
  cat("median leaf-area height: Narrow", round(med$median_h[med$shape=="Narrow"],1),
      "cm vs Broad", round(med$median_h[med$shape=="Broad"],1), "cm\n")

  p <- ggplot() +
    # median-height guide lines and diamond markers
    geom_segment(data=med, aes(x=0, xend=x, y=median_h, yend=median_h, color=shape),
                 linetype="22", linewidth=0.7, show.legend=FALSE) +
    geom_path(data=smB, aes(x=LAI, y=height, color=shape), linewidth=1.2) +
    geom_errorbarh(data=profB, aes(y=height_cm, xmin=LAI-se, xmax=LAI+se, color=shape),
                   height=2.4, linewidth=0.6, show.legend=FALSE) +
    geom_point(data=profB, aes(x=LAI, y=height_cm, fill=shape), shape=21, size=2.8, color="black", stroke=0.4) +
    geom_point(data=med, aes(x=x, y=median_h, fill=shape), shape=23, size=3.6, color="black", stroke=0.6, show.legend=FALSE) +
    scale_color_manual(values=LEAF_LINE, name="Leaflet type") +
    scale_fill_manual(values=LEAF_FILL, name="Leaflet type", guide=guide_legend(override.aes=list(size=4, shape=21))) +
    scale_x_continuous(limits=c(0,7.6), breaks=seq(0,7,1), expand=c(0.01,0)) +
    scale_y_continuous(limits=c(0,103), breaks=seq(0,100,20), expand=c(0.01,0)) +
    labs(x=expression(bold("Cumulative LAI above height ("*m^2~m^-2*")")), y="Height above ground (cm)") +
    guides(color="none") + pub_theme

  ggsave(file.path(OUT, "Fig5B_leaf_area_profile.png"), p, width=6.5, height=7.0, dpi=300, bg="white", device=grDevices::png)
  cat("Wrote outputs/figures/Figure5/Fig5B_leaf_area_profile.png\n")
}

# ==================================================================================================
# Section fig5c
# Fig 5C: LiDAR foliage share by relative canopy height at the Energy Farm, canopy closure
# ==================================================================================================
#
# Purpose
#   Draws Fig. 5C, the share of overhead LiDAR foliage returns in each 0.05 bin of relative canopy
#   height for broad- and narrow-leaflet BC3 NILs in 76-cm rows (Spacing = 30) on 13 August 2024
#   (DAP 75), as class means with SE bands (56 plots per class). The plotted values are also
#   written to a table. The section prints the class-mean median foliage height (fraction of
#   canopy height) and its Welch two-sample t-test P on the same date.
#
# Inputs
#   outputs/field_validation/lidar/group_relative_height_profiles.csv   class-mean profiles
#                                                                        (04_leaflet_type_contrasts.R)
#   outputs/field_validation/lidar/plot_metrics.csv                     per-plot metrics
#                                                                        (03_canopy_structure_metrics.R)
#
# Outputs
#   outputs/figures/Figure5/Fig5C_lidar_foliage_profile.png   panel without annotations
#   outputs/figures/Figure5/Fig5C_data.csv                    plotted values (leaflet type,
#                                                             relative height at the bin midpoint,
#                                                             foliage share in % and its SE in %)

fig5c <- function() {
  LIDAR <- file.path(ROOT, "outputs", "field_validation", "lidar")
  OUT   <- file.path(ROOT, "outputs", "figures", "Figure5")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
  DATE <- "Aug13"; SP <- "30"                              # 13 August 2024 (DAP 75), 76-cm rows
  BROAD <- "#E0A100"; NARROW <- "#1C9EC2"                 # Broad = gold, Narrow = cyan
  BBAND <- adjustcolor(BROAD, 0.16); NBAND <- adjustcolor(NARROW, 0.16)

  ## Profile bands (share of foliage per relative-height layer)
  b <- read.csv(file.path(LIDAR, "group_relative_height_profiles.csv")); b$spacing <- as.character(b$spacing)
  B <- subset(b, spacing==SP & date==DATE & leaf=="Broad");  B <- B[order(B$relbin), ]
  N <- subset(b, spacing==SP & date==DATE & leaf=="Narrow"); N <- N[order(N$relbin), ]

  ## Median foliage height (fraction of canopy height) and Welch P, printed with the panel
  M <- read.csv(file.path(LIDAR, "plot_metrics.csv")); M$helios <- M$helios %in% c(TRUE,"TRUE","True")
  M <- subset(M, date==DATE & spacing==SP & helios)
  mb <- M$rel_median[M$leaf_type=="Broad"];  mb <- mb[is.finite(mb)]
  mn <- M$rel_median[M$leaf_type=="Narrow"]; mn <- mn[is.finite(mn)]
  medB <- mean(mb); medN <- mean(mn); pmed <- t.test(mb, mn)$p.value

  ## Plotted values
  write.csv(data.frame(leaf=c(rep("Broad",nrow(B)),rep("Narrow",nrow(N))),
                       rel_height=c(B$relbin,N$relbin),
                       foliage_share_pct=c(B$share_mean,N$share_mean)*100,
                       se_pct=c(B$share_se,N$share_se)*100),
            file.path(OUT,"Fig5C_data.csv"), row.names=FALSE)

  draw <- function() {
    par(mar=c(4.0,4.2,2.8,1.0), mgp=c(2.4,0.6,0), las=1, xaxs="i", yaxs="i",
        cex.axis=0.95, cex.lab=1.05, family="sans", lend=1, ljoin=1)
    xmax <- max((B$share_mean+B$share_se)*100, (N$share_mean+N$share_se)*100)*1.06
    plot(NA, xlim=c(0,xmax), ylim=c(0,1), axes=FALSE, xlab="Foliage share (%)",
         ylab="Relative canopy height")
    # faint horizontal guides
    abline(h=seq(0,1,0.2), col="gray92", lwd=0.8)
    band <- function(d, col) polygon(c((d$share_mean-d$share_se)*100, rev((d$share_mean+d$share_se)*100)),
                                     c(d$relbin, rev(d$relbin)), col=col, border=NA)
    band(N, NBAND); band(B, BBAND)
    lines(N$share_mean*100, N$relbin, col=NARROW, lwd=2.6)
    lines(B$share_mean*100, B$relbin, col=BROAD,  lwd=2.6)
    # axes and a full border, leaving the panel free of annotations
    axis(1, at=pretty(c(0,xmax)), tck=-0.02); axis(2, at=seq(0,1,0.2), tck=-0.02)
    box(bty="o", lwd=1.1)
    legend("top", c("Broad","Narrow"), col=c(BROAD,NARROW), lwd=2.8, bty="n", cex=0.9,
           horiz=TRUE, xpd=NA, inset=c(0,-0.12), seg.len=1.6, text.width=xmax*0.14)
  }

  png(file.path(OUT,"Fig5C_lidar_foliage_profile.png"), width=1180, height=1180, res=320); draw(); dev.off()
  cat(sprintf("Fig 5C: median foliage height Broad %.3f vs Narrow %.3f, Welch P = %.4f\n",
              medB, medN, pmed))
}

# ==================================================================================================
# Section fig5d
# Fig 5D: LiDAR return density of one broad- and one narrow-leaflet plot at canopy closure
# ==================================================================================================
#
# Purpose
#   Draws the two parts of Fig. 5D from the point clouds of two Energy Farm plots in 76-cm rows on
#   13 August 2024 (DAP 75), a broad-leaflet plot (SpiderCam block Soybean_1, plot 1) and a
#   narrow-leaflet plot (plot 220). Point heights are divided by the plot's 99th-percentile height
#   to give relative canopy height (capped at 1.05). The left panel is a heatmap of
#   log(1 + return count) across the row (62 bins over 0-1.02 m) and with relative height
#   (42 bins over 0-1.05), on a color scale shared by the two plots. The right panel is the share
#   of foliage returns (more than 0.05 m above the ground) in 0.05 bins of relative height, on a
#   shared axis. The dashed line in both panels is the plot's median foliage height.
#
# Inputs
#   data/lidar/point_cloud_broad_plot1_2024-08-13.ply     example point cloud, broad-leaflet plot
#   data/lidar/point_cloud_narrow_plot220_2024-08-13.ply  example point cloud, narrow-leaflet plot
#
# Outputs
#   outputs/figures/Figure5/Fig5D_lidar_density_broad.png    broad-leaflet plot, without annotations
#   outputs/figures/Figure5/Fig5D_lidar_density_narrow.png   narrow-leaflet plot, without annotations

fig5d <- function() {
  PLY  <- file.path(ROOT, "data", "lidar")
  FIG  <- file.path(ROOT, "outputs", "figures", "Figure5")
  dir.create(FIG, showWarnings = FALSE, recursive = TRUE)
  BROAD <- "#E0A100"; NARROW <- "#1F6FB2"
  rampB <- colorRampPalette(c("#fbf7ea","#f0d98a","#E0A100","#8a5712","#3d2708"))
  rampN <- colorRampPalette(c("#eef4fb","#9dc3e6","#1F6FB2","#134a78","#0a2740"))

  # Read a PLY point cloud (seven values per point, of which columns 2 and 3 are y and z in m) and return
  # across-row position v, height z and relative height rel = z / 99th-percentile height.
  rd <- function(f){ raw <- readLines(file.path(PLY,f)); h <- which(raw=="end_header")[1]
    m <- matrix(scan(text=raw[(h+1):length(raw)], what=double(), quiet=TRUE), ncol=7, byrow=TRUE)
    z <- m[,3]; ztop <- as.numeric(quantile(z,0.99)); data.frame(v=m[,2]-min(m[,2]), z=z, rel=pmin(z/ztop,1.05)) }
  # Share of foliage returns (z > 0.05 m) in 0.05 bins of relative height.
  prof <- function(d){ r <- d$rel[d$z>0.05]; br <- seq(0,1.05,0.05)
    h <- hist(r, breaks=br, plot=FALSE)$counts; data.frame(mid=br[-1]-0.025, share=h/sum(h)) }
  B <- rd("point_cloud_broad_plot1_2024-08-13.ply");    pB <- prof(B); mB <- median(B$rel[B$z>0.05])
  N <- rd("point_cloud_narrow_plot220_2024-08-13.ply"); pN <- prof(N); mN <- median(N$rel[N$z>0.05])
  BX <- seq(0,1.02,length.out=63); BY <- seq(0,1.05,length.out=43)
  grid <- function(d) log1p(unclass(table(cut(d$v,BX), cut(d$rel,BY))))
  gB <- grid(B); gN <- grid(N); ZMAX <- max(gB,gN)
  PMAX <- max(pB$share,pN$share); PK <- signif(PMAX*100,2)

  # Dashed median line spanning the plotting region.
  medline <- function(m){ u <- par("usr"); segments(u[1], m, u[2], m, lty=2, lwd=1.3, col="gray30") }
  panel <- function(g, p, m, ttl, ramp, pcol){
    layout(matrix(c(1,2),1,2), widths=c(3.2,1))
    par(mar=c(3.8,3.9,2.2,0.3), mgp=c(2.4,0.6,0), las=1, xaxs="i", yaxs="i")
    image(BX[-1],BY[-1],g, col=ramp(80), zlim=c(0,ZMAX), xlim=c(0,1.02), ylim=c(0,1.05),
          xlab="Across-row position (m)", ylab="Relative canopy height", main=ttl, cex.lab=1.05)
    medline(m); box(lwd=1.1)
    par(mar=c(3.8,0.3,2.2,1.6), xaxs="r", yaxs="r")
    plot(NA, xlim=c(0,PK*1.22), ylim=c(0,1.05), axes=FALSE, xlab="Foliage\nshare (%)", ylab="")
    polygon(c(0,p$share*100,0), c(p$mid[1],p$mid,p$mid[nrow(p)]),
            col=adjustcolor(pcol,0.55), border=pcol, lwd=1.6)
    medline(m)
    tk <- c(0,PK/2,PK); axis(1, at=tk, labels=format(tk), tck=-0.03, cex.axis=0.75, mgp=c(2,0.5,0))
    box(lwd=1.1); layout(1)
  }
  png(file.path(FIG,"Fig5D_lidar_density_broad.png"), 1500,950, res=300); panel(gB,pB,mB,"Broad",  rampB, BROAD);  dev.off()
  png(file.path(FIG,"Fig5D_lidar_density_narrow.png"),1500,950, res=300); panel(gN,pN,mN,"Narrow", rampN, NARROW); dev.off()
  cat(sprintf("Fig 5D panels written. Median foliage height (fraction of canopy height): Broad %.2f, Narrow %.2f\n", mB, mN))
}

# ==================================================================================================
# Section fig6a
# Fig 6A: Slopegraph of per-plot peak leaf area index and grain yield
# ==================================================================================================
#
# Purpose
#   Draws Fig. 6A. Each broad- and narrow-leaflet NIL plot with a yield record is reduced to
#   one row. Its peak within-season LAI and its grain yield are each scaled from 0 (minimum)
#   to 1 (maximum) within its site x row spacing combination, and the two scaled values are
#   joined by a thin line. Thick lines with circles join the leaflet-type means, scaled with
#   the same within-combination ranges. The panel is written twice, once with the inch spacing
#   codes of the data in the strip labels (EF-15in) and once with centimeters (EF-38cm).
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   as-run per-plot inputs,
#                                                                    SoyFACE (yield_bu_ac, max_LAI_m2_m2)
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   as above, Energy Farm
#
# Outputs
#   outputs/figures/Figure6/Fig6A_slopegraph.png          strip labels with inch spacing codes
#   outputs/figures/Figure6/Fig6A_slopegraph_metric.png   strip labels for 38-cm and 76-cm rows
#   The PNG files are written with the ragg device (ragg::agg_png), which rendered the
#   published panels.

fig6a <- function() {
  SF_CSV <- file.path(ROOT, "data", "simulation_inputs", "canopy_inputs_per_plot_per_DAP_SF.csv")
  EF_CSV <- file.path(ROOT, "data", "simulation_inputs", "canopy_inputs_per_plot_per_DAP_EF.csv")
  OUT    <- file.path(ROOT, "outputs", "figures", "Figure6")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type colors used in all figures (fill and line).
  BROAD_FILL  <- "#FFD700"; BROAD_LINE  <- "#B8860B"
  NARROW_FILL <- "#00BFFF"; NARROW_LINE <- "#006D9C"
  LEAF_FILL <- c("Broad" = BROAD_FILL,  "Narrow" = NARROW_FILL)
  LEAF_LINE <- c("Broad" = BROAD_LINE,  "Narrow" = NARROW_LINE)

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(size = 14, face = "bold", hjust = 0.5,
                                      margin = margin(b = 6)),
      axis.title       = element_text(size = 14, face = "bold", color = "black"),
      axis.text        = element_text(size = 11, color = "black"),
      axis.ticks       = element_line(color = "black", linewidth = 0.7),
      axis.ticks.length = unit(0.18, "cm"),
      panel.grid.major = element_line(color = "gray92", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background = element_rect(fill = "white"),
      plot.background  = element_rect(fill = "white", color = NA),
      strip.text       = element_text(size = 12, face = "bold", color = "black"),
      strip.background = element_rect(fill = "gray95", color = "black",
                                      linewidth = 0.5),
      legend.position  = "top",
      legend.title     = element_text(size = 11, face = "bold"),
      legend.text      = element_text(size = 11),
      plot.margin      = margin(10, 14, 10, 10)
    )

  # The input files hold one row per plot and date. Keep one row per plot (Loc_ID), the
  # broad- and narrow-leaflet NILs (the parents are excluded) and plots with yield and peak LAI.
  keep_cols <- c("Loc_ID", "Location", "Spacing", "Leaf_type",
                 "yield_bu_ac", "max_LAI_m2_m2")
  sf <- read_csv(SF_CSV, show_col_types = FALSE)[, keep_cols]
  ef <- read_csv(EF_CSV, show_col_types = FALSE)[, keep_cols]
  d <- bind_rows(sf, ef) %>%
    distinct(Loc_ID, .keep_all = TRUE) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(yield_bu_ac), !is.na(max_LAI_m2_m2)) %>%
    mutate(
      Spacing = as.character(Spacing),
      cell = paste0(Location, "-", Spacing, "in"),
      Leaf_type = factor(Leaf_type, levels = c("Broad", "Narrow")),
      cell = factor(cell, levels = c("EF-15in", "EF-30in", "SF-15in", "SF-30in")),
      yield_per_LAI = yield_bu_ac / max_LAI_m2_m2
    )

  cat(sprintf("n plots (one row per plot, broad and narrow NILs): %d\n", nrow(d)))
  print(d %>% count(cell, Leaf_type))

  # Scale peak LAI and yield to [0, 1] within each site x row spacing combination so that both
  # share one axis. Each plot contributes one line from its LAI position to its yield position.
  d_long <- d %>%
    group_by(cell) %>%
    mutate(
      lai_std   = (max_LAI_m2_m2 - min(max_LAI_m2_m2)) /
                  (max(max_LAI_m2_m2) - min(max_LAI_m2_m2) + 1e-9),
      yield_std = (yield_bu_ac    - min(yield_bu_ac)) /
                  (max(yield_bu_ac)  - min(yield_bu_ac) + 1e-9)
    ) %>%
    ungroup() %>%
    pivot_longer(c(lai_std, yield_std),
                 names_to = "axis", values_to = "value") %>%
    mutate(axis = factor(axis, levels = c("lai_std", "yield_std"),
                         labels = c("Max LAI", "Yield")))

  # Leaflet-type means, scaled with the same within-combination ranges as the plots so that
  # the means fall on the same axis.
  d_means <- d %>% group_by(cell, Leaf_type) %>%
    summarize(lai = mean(max_LAI_m2_m2), yield = mean(yield_bu_ac),
              .groups = "drop") %>%
    group_by(cell) %>%
    mutate(
      lai_std   = (lai   - min(d$max_LAI_m2_m2[d$cell == cell[1]])) /
                  (max(d$max_LAI_m2_m2[d$cell == cell[1]]) -
                   min(d$max_LAI_m2_m2[d$cell == cell[1]])),
      yield_std = (yield - min(d$yield_bu_ac[d$cell == cell[1]])) /
                  (max(d$yield_bu_ac[d$cell == cell[1]]) -
                   min(d$yield_bu_ac[d$cell == cell[1]]))
    ) %>%
    ungroup() %>%
    pivot_longer(c(lai_std, yield_std), names_to = "axis", values_to = "value") %>%
    mutate(axis = factor(axis, levels = c("lai_std", "yield_std"),
                         labels = c("Max LAI", "Yield")))

  # Strip labels in centimeters for the metric version (15 in = 38 cm, 30 in = 76 cm).
  CELL_LABELS_CM <- c(
    "EF-15in" = "EF-38cm",
    "EF-30in" = "EF-76cm",
    "SF-15in" = "SF-38cm",
    "SF-30in" = "SF-76cm"
  )

  build_slopegraph <- function(d_long, d_means, cell_labels = NULL) {
    facet_layer <- if (is.null(cell_labels)) {
      facet_wrap(~ cell, ncol = 4)
    } else {
      facet_wrap(~ cell, ncol = 4,
                 labeller = labeller(cell = cell_labels))
    }
    ggplot() +
      geom_line(data = d_long,
                aes(x = axis, y = value,
                    group = Loc_ID, color = Leaf_type),
                alpha = 0.18, linewidth = 0.3) +
      geom_line(data = d_means,
                aes(x = axis, y = value,
                    group = interaction(cell, Leaf_type),
                    color = Leaf_type),
                linewidth = 1.6) +
      geom_point(data = d_means,
                 aes(x = axis, y = value, fill = Leaf_type),
                 shape = 21, size = 4.0, color = "black", stroke = 0.6) +
      scale_color_manual(values = LEAF_LINE, name = "Leaf type") +
      scale_fill_manual(values = LEAF_FILL,   name = "Leaf type") +
      facet_layer +
      scale_y_continuous(limits = c(-0.02, 1.02),
                         expand = c(0, 0),
                         breaks = c(0, 0.5, 1),
                         labels = c("min", "median", "max")) +
      labs(x = NULL,
           y = "Within-cell rank position") +
      pub_theme +
      theme(panel.grid.major.x = element_blank())
  }

  p_imperial <- build_slopegraph(d_long, d_means)
  p_metric   <- build_slopegraph(d_long, d_means, cell_labels = CELL_LABELS_CM)

  ggsave(file.path(OUT, "Fig6A_slopegraph.png"),
         p_imperial, device = ragg::agg_png, width = 12, height = 4.5, dpi = 300, bg = "white")
  ggsave(file.path(OUT, "Fig6A_slopegraph_metric.png"),
         p_metric,   device = ragg::agg_png, width = 12, height = 4.5, dpi = 300, bg = "white")

  cat(sprintf("\nWrote 2 panels to %s\n", OUT))
  cat("  Fig6A_slopegraph.png          (strip labels with inch spacing codes)\n")
  cat("  Fig6A_slopegraph_metric.png   (strip labels in centimeters)\n")
}

# ==================================================================================================
# Section fig6b
# Fig 6B: Raincloud plot of per-plot grain yield per unit peak leaf area index
# ==================================================================================================
#
# Purpose
#   Draws Fig. 6B. For each broad- and narrow-leaflet NIL plot with a yield record, yield per
#   unit peak LAI is grain yield divided by the plot's maximum within-season LAI
#   (max_LAI_m2_m2, the peak of a LOWESS fit to its LAI time course). Each site x row spacing
#   combination is one facet with a half-violin density, a box plot (median and interquartile
#   range) and jittered points for each leaflet type. The panel is written in bu/ac per LAI
#   with inch spacing codes in the strip labels, and in kg/ha per LAI with centimeter labels.
#   The n, Cohen's |d| and Welch P given in each published facet are taken from the statistics
#   file written by section fig6_stats. They are not drawn by this section.
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   as-run per-plot inputs,
#                                                                    SoyFACE (yield_bu_ac,
#                                                                    yield_Mg_ha, max_LAI_m2_m2)
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   as above, Energy Farm
#
# Outputs
#   outputs/figures/Figure6/Fig6B_yield_per_lai_raincloud.png          bu/ac per LAI
#   outputs/figures/Figure6/Fig6B_yield_per_lai_raincloud_metric.png   kg/ha per LAI, 38-cm and
#                                                                        76-cm row labels
#   The PNG files are written with the ragg device (ragg::agg_png), which rendered the
#   published panels.

fig6b <- function() {
  SF_CSV <- file.path(ROOT, "data", "simulation_inputs", "canopy_inputs_per_plot_per_DAP_SF.csv")
  EF_CSV <- file.path(ROOT, "data", "simulation_inputs", "canopy_inputs_per_plot_per_DAP_EF.csv")
  OUT    <- file.path(ROOT, "outputs", "figures", "Figure6")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Leaflet-type colors used in all figures (fill and line).
  BROAD_FILL  <- "#FFD700"
  BROAD_LINE  <- "#B8860B"
  NARROW_FILL <- "#00BFFF"
  NARROW_LINE <- "#006D9C"
  LEAF_FILL   <- c("Broad" = BROAD_FILL,  "Narrow" = NARROW_FILL)
  LEAF_LINE   <- c("Broad" = BROAD_LINE,  "Narrow" = NARROW_LINE)

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(size = 16, face = "bold", hjust = 0.5,
                                      margin = margin(b = 6)),
      axis.title.x     = element_text(size = 18, face = "bold", color = "black",
                                      margin = margin(t = 6)),
      axis.title.y     = element_text(size = 18, face = "bold", color = "black",
                                      margin = margin(r = 4)),
      axis.text        = element_text(size = 14, color = "black"),
      axis.ticks       = element_line(color = "black", linewidth = 0.8),
      axis.ticks.length = unit(0.2, "cm"),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background = element_rect(fill = "white"),
      plot.background  = element_rect(fill = "white", color = NA),
      strip.text       = element_text(size = 13, face = "bold", color = "black"),
      strip.background = element_rect(fill = "gray95", color = "black",
                                      linewidth = 0.5),
      legend.position  = "none",
      plot.margin      = margin(10, 14, 10, 10)
    )

  # One row per plot (Loc_ID), broad- and narrow-leaflet NILs only, plots with yield and peak
  # LAI. Yield in kg/ha is the Mg/ha column times 1000 (1 bu/ac = 0.06725 Mg/ha).
  keep_cols <- c("Loc_ID", "Location", "Spacing", "Leaf_type",
                 "yield_bu_ac", "yield_Mg_ha", "max_LAI_m2_m2")
  sf <- read_csv(SF_CSV, show_col_types = FALSE)[, keep_cols]
  ef <- read_csv(EF_CSV, show_col_types = FALSE)[, keep_cols]

  plots <- bind_rows(sf, ef) %>%
    distinct(Loc_ID, .keep_all = TRUE) %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           !is.na(yield_bu_ac), !is.na(max_LAI_m2_m2)) %>%
    mutate(yield_kg_ha           = yield_Mg_ha * 1000,
           yield_per_LAI_imperial = yield_bu_ac / max_LAI_m2_m2,
           yield_per_LAI_metric   = yield_kg_ha / max_LAI_m2_m2,
           Site          = factor(Location, levels = c("EF", "SF")),
           Spacing       = factor(Spacing,  levels = c(15, 30)),
           Cell          = factor(paste0(Site, "-", Spacing, "in"),
                                  levels = c("EF-15in", "EF-30in",
                                             "SF-15in", "SF-30in")),
           # Broad is drawn on the left of each facet.
           Leaf_type     = factor(Leaf_type, levels = c("Broad", "Narrow")))

  cat(sprintf("NIL plots: %d\n", nrow(plots)))
  cat("Plots per site x row spacing and leaflet type\n")
  print(plots %>% count(Cell, Leaf_type))

  # Raincloud layers. stat_halfeye draws the half-violin density beside the box
  # (justification = -0.18), with a narrow box plot in the center and jittered points beneath.
  # The jitter is drawn without a fixed seed, so point positions vary between runs.
  build_raincloud <- function(d, value_col, y_label, cell_labels = NULL) {
    facet_layer <- if (is.null(cell_labels)) {
      facet_wrap(~ Cell, nrow = 1)
    } else {
      facet_wrap(~ Cell, nrow = 1,
                 labeller = labeller(Cell = cell_labels))
    }
    ggplot(d, aes(x = Leaf_type, y = .data[[value_col]],
                  fill = Leaf_type, color = Leaf_type)) +
      ggdist::stat_halfeye(adjust = 0.6, .width = 0, justification = -0.18,
                           point_color = NA, alpha = 0.8,
                           linewidth = 0.4, slab_color = "black",
                           slab_linewidth = 0.4) +
      geom_jitter(width = 0.07, alpha = 0.45, size = 0.9, shape = 16) +
      geom_boxplot(width = 0.14, outlier.shape = NA,
                   fill = "white", color = "black", linewidth = 0.5,
                   alpha = 0.85) +
      facet_layer +
      scale_fill_manual(values = LEAF_FILL) +
      scale_color_manual(values = LEAF_LINE) +
      scale_y_continuous(limits = c(0, NA),
                         expand = expansion(mult = c(0, 0.05))) +
      labs(title = "Per-plot yield-per-LAI by Site x Spacing x NIL class",
           x = "Leaflet type",
           y = y_label) +
      pub_theme
  }

  # Strip labels in centimeters for the metric version (15 in = 38 cm, 30 in = 76 cm).
  CELL_LABELS_CM <- c(
    "EF-15in" = "EF-38cm",
    "EF-30in" = "EF-76cm",
    "SF-15in" = "SF-38cm",
    "SF-30in" = "SF-76cm"
  )

  # Version in bu/ac per LAI with the inch spacing codes.
  p_imperial <- build_raincloud(
    plots, "yield_per_LAI_imperial",
    expression(bold("Yield per unit LAI") ~ "(bu ac"^-1 * "/ LAI)"))
  ggsave(file.path(OUT, "Fig6B_yield_per_lai_raincloud.png"),
         p_imperial, device = ragg::agg_png, width = 12.0, height = 4.5, dpi = 300, bg = "white")

  # Version in kg/ha per LAI with centimeter spacing labels.
  p_metric <- build_raincloud(
    plots, "yield_per_LAI_metric",
    expression(bold("Yield per unit LAI") ~ "(kg ha"^-1 * "/ LAI)"),
    cell_labels = CELL_LABELS_CM)
  ggsave(file.path(OUT, "Fig6B_yield_per_lai_raincloud_metric.png"),
         p_metric, device = ragg::agg_png, width = 12.0, height = 4.5, dpi = 300, bg = "white")

  cat(sprintf("\nWrote 2 panels to %s\n", OUT))
  cat("  Fig6B_yield_per_lai_raincloud.png          (bu/ac per LAI)\n",
      "  Fig6B_yield_per_lai_raincloud_metric.png   (kg/ha per LAI)\n",
      sep = "")
}

# ==================================================================================================
# Section fig6b_kgha
# Fig 6B values in kg/ha: Yield per unit peak LAI of narrow- versus broad-leaflet NILs
# ==================================================================================================
#
# Purpose
#   Gives the yield-per-LAI comparison reported in the Results and Discussion in kg/ha per
#   unit LAI (for example the pooled narrow advantage of +80.4 kg/ha per LAI, +13.7%).
#   Per-plot yield in bu/ac is converted to kg/ha (x 67.25) and divided by the plot's peak
#   within-season LAI (max_LAI_m2_m2, the maximum of a LOWESS fit to its LAI time course,
#   spatially adjusted as in Tamang et al. 2026). Narrow and broad plots are compared within
#   each site x row spacing combination and pooled, with Welch t-tests and Cohen's d (pooled
#   SD). The same comparison in bu/ac is in section fig6_stats.
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   as-run per-plot inputs,
#                                                                    SoyFACE (yield_bu_ac, max_LAI_m2_m2)
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   as above, Energy Farm
#
# Outputs
#   outputs/figures/Figure6/Fig6B_yield_per_lai_kg_ha.txt   per-combination and pooled values

fig6b_kgha <- function() {
  IN_DIR <- file.path(ROOT, "data", "simulation_inputs")
  OUT_FILE <- file.path(ROOT, "outputs", "figures", "Figure6", "Fig6B_yield_per_lai_kg_ha.txt")
  dir.create(dirname(OUT_FILE), showWarnings = FALSE, recursive = TRUE)

  # One row per plot. Yield and peak LAI repeat on every date of a plot, so unique() leaves one
  # row per plot. Keep the broad- and narrow-leaflet NILs with a yield record.
  cols <- c("Loc_ID", "Location", "Spacing", "Leaf_type", "yield_bu_ac", "max_LAI_m2_m2")
  p <- unique(do.call(rbind, lapply(c("SF", "EF"), function(s)
    read.csv(file.path(IN_DIR, sprintf("canopy_inputs_per_plot_per_DAP_%s.csv", s)))[, cols])))
  p <- p[p$Leaf_type %in% c("Broad", "Narrow") & !is.na(p$yield_bu_ac), ]

  # Yield per unit peak LAI in kg/ha (1 bu/ac of soybean = 67.25 kg/ha).
  p$ypl <- p$yield_bu_ac * 67.25 / p$max_LAI_m2_m2

  # Cohen's d with the pooled SD, positive when Broad > Narrow.
  d_pooled <- function(b, n) (mean(b) - mean(n)) / sqrt(((length(b) - 1) * var(b) + (length(n) - 1) * var(n)) / (length(b) + length(n) - 2))

  # One formatted line per group with n, means, the narrow-minus-broad difference, Cohen's d
  # and the Welch t-test P.
  line <- function(g, lab) {
    b <- g$ypl[g$Leaf_type == "Broad"]; n <- g$ypl[g$Leaf_type == "Narrow"]
    sprintf("%-8s n %3d/%3d  Broad %6.1f  Narrow %6.1f  N-B %+6.1f kg ha-1 per LAI (%+5.1f%%)  Cohen's d %+5.2f  Welch P %.2g",
            lab, length(b), length(n), mean(b), mean(n), mean(n) - mean(b), 100 * (mean(n) / mean(b) - 1), d_pooled(b, n), t.test(n, b)$p.value)
  }

  # Row labels give the site and the row spacing in cm (Spacing 15 = 38 cm, 30 = 76 cm).
  spacing_cm <- function(x) ifelse(x == 15, "38 cm", "76 cm")
  out <- c("Yield per unit peak LAI (kg ha-1 per LAI), narrow vs broad; plots with yield and peak LAI.",
           "Spacing 15 = 38-cm rows, 30 = 76-cm rows. Cohen's d = (Broad - Narrow) / pooled SD.", "",
           vapply(split(p, paste(p$Location, p$Spacing)), function(g) line(g, paste(g$Location[1], spacing_cm(g$Spacing[1]))), ""),
           line(p, "pooled"))
  writeLines(out, OUT_FILE)
  cat(out, sep = "\n")
}

# ==================================================================================================
# Section fig6_stats
# Fig 6 statistics: Grain yield and yield per unit peak LAI of broad- and narrow-leaflet NILs
# ==================================================================================================
#
# Purpose
#   Compares narrow- with broad-leaflet NIL plots for grain yield (bu/ac) and for yield per
#   unit peak LAI (yield_bu_ac / max_LAI_m2_m2), within each site x row spacing combination
#   and pooled over all plots. Each comparison gives group means, the narrow-minus-broad
#   difference, Cohen's d (pooled SD, positive = Broad > Narrow), a Welch t-test and a
#   Wilcoxon rank-sum test. The yield results support the Results text on yield parity
#   (per-combination differences and P >= 0.083). The yield-per-LAI results give the n,
#   Cohen's |d| and Welch P shown in Fig. 6B and the per-combination values in the Results.
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   as-run per-plot inputs,
#                                                                    SoyFACE (yield_bu_ac, max_LAI_m2_m2)
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   as above, Energy Farm
#
# Outputs
#   outputs/figures/Figure6/Fig6_yield_statistics.txt   per-combination and pooled statistics

fig6_stats <- function() {
  SF_CSV <- file.path(ROOT, "data", "simulation_inputs", "canopy_inputs_per_plot_per_DAP_SF.csv")
  EF_CSV <- file.path(ROOT, "data", "simulation_inputs", "canopy_inputs_per_plot_per_DAP_EF.csv")
  OUT    <- file.path(ROOT, "outputs", "figures", "Figure6")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Row spacing labels for the statistics file (the data code row spacing in inches).
  SPACING_CM <- c("15" = "38 cm", "30" = "76 cm")

  # Read both sites and keep the columns the comparison needs.
  sf <- read_csv(SF_CSV, show_col_types = FALSE)
  ef <- read_csv(EF_CSV, show_col_types = FALSE)

  keep_cols <- c("Loc_ID", "Location", "Spacing", "Leaf_type",
                 "yield_bu_ac", "max_LAI_m2_m2")
  sf_k <- sf[, keep_cols]
  ef_k <- ef[, keep_cols]

  raw <- bind_rows(sf_k, ef_k)
  cat(sprintf("Concatenated rows (one per plot and date): %d\n", nrow(raw)))

  # Yield and peak LAI are per-plot values repeated on every date, so keep one row per plot.
  plots <- raw %>% distinct(Loc_ID, .keep_all = TRUE)
  cat(sprintf("After keeping one row per Loc_ID: %d plots\n", nrow(plots)))

  # Keep the broad- and narrow-leaflet NILs (drops the donor and recurrent parents).
  plots <- plots %>%
    filter(Leaf_type %in% c("Broad", "Narrow"))
  cat(sprintf("After Leaf_type ∈ {Broad, Narrow} filter: %d plots\n", nrow(plots)))

  # Yield per unit peak LAI. Plots without yield are dropped.
  plots <- plots %>%
    mutate(yield_per_LAI = yield_bu_ac / max_LAI_m2_m2)

  plots_yield <- plots %>% filter(!is.na(yield_bu_ac))
  plots_ypl   <- plots %>% filter(!is.na(yield_per_LAI),
                                  is.finite(yield_per_LAI))
  cat(sprintf("Plots with non-NA yield: %d\n",          nrow(plots_yield)))
  cat(sprintf("Plots with non-NA yield-per-LAI: %d\n",  nrow(plots_ypl)))

  # Site, spacing and combination factors (Energy Farm first, then SoyFACE, 38-cm rows first).
  to_cell <- function(d) {
    d %>%
      mutate(Site    = factor(Location, levels = c("EF", "SF")),
             Spacing = factor(Spacing,  levels = c(15, 30)),
             Cell    = factor(paste0(Site, "-", Spacing, "in"),
                              levels = c("EF-15in", "EF-30in",
                                         "SF-15in", "SF-30in")),
             Leaf_type = factor(Leaf_type, levels = c("Broad", "Narrow")))
  }
  plots_yield <- to_cell(plots_yield)
  plots_ypl   <- to_cell(plots_ypl)

  # Cohen's d with the pooled SD, signed so that positive means Broad > Narrow.
  cohen_d <- function(narrow_vals, broad_vals) {
    if (length(narrow_vals) < 2 || length(broad_vals) < 2) return(NA_real_)
    s_n <- sd(narrow_vals); s_b <- sd(broad_vals)
    pooled <- sqrt(((length(narrow_vals)-1)*s_n^2 +
                    (length(broad_vals)-1)*s_b^2) /
                   (length(narrow_vals) + length(broad_vals) - 2))
    (mean(broad_vals) - mean(narrow_vals)) / pooled
  }

  # Narrow versus broad within each site x row spacing combination.
  per_cell_stats <- function(d, val_col) {
    cells <- d %>%
      group_by(Site, Spacing) %>%
      group_split()
    out <- lapply(cells, function(s) {
      nn <- s[[val_col]][s$Leaf_type == "Narrow"]
      bb <- s[[val_col]][s$Leaf_type == "Broad"]
      if (length(nn) < 2 || length(bb) < 2) return(NULL)
      wt   <- suppressWarnings(wilcox.test(nn, bb))
      welch<- suppressWarnings(t.test(nn, bb, var.equal = FALSE))
      diff <- mean(nn) - mean(bb)
      pct  <- 100 * diff / mean(bb)
      data.frame(
        Site         = unique(s$Site),
        Spacing      = unique(s$Spacing),
        n_Narrow     = length(nn),
        n_Broad      = length(bb),
        mean_Narrow  = mean(nn),
        mean_Broad   = mean(bb),
        diff_NminusB = diff,
        pct_NminusB  = pct,
        cohens_d     = cohen_d(nn, bb),
        welch_t      = unname(welch$statistic),
        welch_df     = unname(welch$parameter),
        welch_P      = welch$p.value,
        wilcox_W     = unname(wt$statistic),
        wilcox_P     = wt$p.value
      )
    })
    bind_rows(out)
  }

  # Narrow versus broad pooled over all plots.
  pooled_stats <- function(d, val_col) {
    nn <- d[[val_col]][d$Leaf_type == "Narrow"]
    bb <- d[[val_col]][d$Leaf_type == "Broad"]
    welch <- suppressWarnings(t.test(nn, bb, var.equal = FALSE))
    wt    <- suppressWarnings(wilcox.test(nn, bb))
    data.frame(
      n_Narrow     = length(nn),
      n_Broad      = length(bb),
      mean_Narrow  = mean(nn),
      mean_Broad   = mean(bb),
      diff_NminusB = mean(nn) - mean(bb),
      pct_NminusB  = 100 * (mean(nn) - mean(bb)) / mean(bb),
      cohens_d     = cohen_d(nn, bb),
      welch_t      = unname(welch$statistic),
      welch_df     = unname(welch$parameter),
      welch_P      = welch$p.value,
      wilcox_P     = wt$p.value
    )
  }

  stats_yield <- per_cell_stats(plots_yield, "yield_bu_ac")
  stats_ypl   <- per_cell_stats(plots_ypl,   "yield_per_LAI")
  pool_yield  <- pooled_stats(plots_yield,  "yield_bu_ac")
  pool_ypl    <- pooled_stats(plots_ypl,    "yield_per_LAI")

  # Print the results to the console.
  cat("\n================================================================================\n")
  cat("Fig 6A: yield (bu / ac), per site x row spacing and pooled\n")
  cat("================================================================================\n")
  print(stats_yield %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
  cat("\nPooled\n")
  print(pool_yield %>% mutate(across(where(is.numeric), ~ round(.x, 3))))

  cat("\n================================================================================\n")
  cat("Fig 6B: yield-per-LAI (bu / ac / LAI), per site x row spacing and pooled\n")
  cat("================================================================================\n")
  print(stats_ypl %>% mutate(across(where(is.numeric), ~ round(.x, 3))))
  cat("\nPooled\n")
  print(pool_ypl %>% mutate(across(where(is.numeric), ~ round(.x, 3))))

  # Write the statistics file.
  sink(file.path(OUT, "Fig6_yield_statistics.txt"))
  cat("================================================================================\n")
  cat("Figure 6 statistics (per-plot, deduplicated by Loc_ID)\n")
  cat("Source: data/simulation_inputs/canopy_inputs_per_plot_per_DAP_{SF,EF}.csv\n")
  cat("Filter: Leaf_type ∈ {Broad, Narrow} (donor/recurrent parents excluded)\n")
  cat("Tests: Wilcoxon rank-sum (Narrow vs Broad) + Welch t-test + Cohen's d\n")
  cat("Cohen's d sign convention: positive = Broad > Narrow\n")
  cat("================================================================================\n\n")

  cat("================================================================================\n")
  cat("Fig 6A — YIELD (bu / ac), per site x row spacing\n")
  cat("================================================================================\n\n")
  for (i in seq_len(nrow(stats_yield))) {
    s <- stats_yield[i, ]
    cat(sprintf("  %s %s : Broad mean=%.2f (n=%d), Narrow mean=%.2f (n=%d)\n",
                s$Site, SPACING_CM[as.character(s$Spacing)], s$mean_Broad, s$n_Broad,
                s$mean_Narrow, s$n_Narrow))
    cat(sprintf("           N-B=%+.2f bu/ac (%+.1f%%)  d=%+.2f  Welch t=%+.2f, df=%.1f, P=%.4f  Wilcox P=%.4f\n\n",
                s$diff_NminusB, s$pct_NminusB, s$cohens_d,
                s$welch_t, s$welch_df, s$welch_P, s$wilcox_P))
  }
  cat(sprintf("Pooled: Broad mean=%.2f (n=%d), Narrow mean=%.2f (n=%d)\n",
              pool_yield$mean_Broad, pool_yield$n_Broad,
              pool_yield$mean_Narrow, pool_yield$n_Narrow))
  cat(sprintf("        N-B=%+.2f bu/ac (%+.1f%%)  d=%+.2f  Welch t=%+.2f, df=%.1f, P=%.4f  Wilcox P=%.4f\n",
              pool_yield$diff_NminusB, pool_yield$pct_NminusB,
              pool_yield$cohens_d, pool_yield$welch_t, pool_yield$welch_df,
              pool_yield$welch_P, pool_yield$wilcox_P))

  cat("\n================================================================================\n")
  cat("Fig 6B — YIELD-PER-LAI (bu / ac / LAI), per site x row spacing\n")
  cat("================================================================================\n\n")
  for (i in seq_len(nrow(stats_ypl))) {
    s <- stats_ypl[i, ]
    cat(sprintf("  %s %s : Broad mean=%.2f (n=%d), Narrow mean=%.2f (n=%d)\n",
                s$Site, SPACING_CM[as.character(s$Spacing)], s$mean_Broad, s$n_Broad,
                s$mean_Narrow, s$n_Narrow))
    cat(sprintf("           N-B=%+.2f (%+.1f%%)  d=%+.2f  Welch t=%+.2f, df=%.1f, P=%.4f  Wilcox P=%.4f\n\n",
                s$diff_NminusB, s$pct_NminusB, s$cohens_d,
                s$welch_t, s$welch_df, s$welch_P, s$wilcox_P))
  }
  cat(sprintf("Pooled: Broad mean=%.2f (n=%d), Narrow mean=%.2f (n=%d)\n",
              pool_ypl$mean_Broad, pool_ypl$n_Broad,
              pool_ypl$mean_Narrow, pool_ypl$n_Narrow))
  cat(sprintf("        N-B=%+.2f (%+.1f%%)  d=%+.2f  Welch t=%+.2f, df=%.1f, P=%.4f  Wilcox P=%.4f\n",
              pool_ypl$diff_NminusB, pool_ypl$pct_NminusB,
              pool_ypl$cohens_d, pool_ypl$welch_t, pool_ypl$welch_df,
              pool_ypl$welch_P, pool_ypl$wilcox_P))
  sink()

  cat(sprintf("\nWrote %s\n", file.path(OUT, "Fig6_yield_statistics.txt")))
}

# ==================================================================================================
# Section fig7a
# Fig 7A: Distributions of line BLUPs for the four traits of the association analysis
# ==================================================================================================
#
# Purpose
#   Draws the density panels of Fig. 7A, one per trait, from the line BLUPs used in the
#   association scans. The traits are leaflet length-to-maximum-width ratio (Leaflet L:W),
#   yield per unit peak LAI, and reproductive-stage Helios canopy net photosynthesis
#   (Canopy A) and canopy light-use efficiency (Canopy LUE). The Leaflet L:W BLUPs are
#   zero-centered line effects, so the panel adds the mean per-plot leaflet ratio of the
#   companion study to show them on the ratio scale. Yield per LAI is drawn in bu/ac per LAI
#   and in kg/ha per LAI. A text file lists the number of lines, the BLUP range and the
#   Cullis heritability of each trait (the H2 values in Fig. 7A and Table S18).
#
# Inputs
#   outputs/genetics/blups_canopy.csv               canopy A and LUE BLUPs (genetics step)
#   outputs/genetics/blups_yield_per_lai.csv        yield-per-LAI BLUPs (genetics step)
#   outputs/genetics/blups_leaflet_lw.csv           Leaflet L:W BLUPs (genetics step)
#   outputs/genetics/heritability_canopy.csv        Cullis heritability of the canopy traits
#   data/genetics/leaflet_shape_per_plot.csv        per-plot leaflet shape of the companion study
#
# Outputs
#   outputs/figures/Figure7/Fig7A_leaflet_lw_density.png
#   outputs/figures/Figure7/Fig7A_yield_per_lai_density.png          bu/ac per LAI
#   outputs/figures/Figure7/Fig7A_yield_per_lai_density_metric.png   kg/ha per LAI
#   outputs/figures/Figure7/Fig7A_canopy_A_density.png
#   outputs/figures/Figure7/Fig7A_canopy_LUE_density.png
#   outputs/figures/Figure7/Fig7A_statistics.txt     lines, BLUP ranges and heritabilities
#   The PNG files are written with the ragg device (ragg::agg_png), which rendered the
#   published panels.

fig7a <- function() {
  IN_BLUP_CANOPY   <- file.path(ROOT, "outputs", "genetics", "blups_canopy.csv")
  IN_BLUP_YIELD    <- file.path(ROOT, "outputs", "genetics", "blups_yield_per_lai.csv")
  IN_BLUP_LW       <- file.path(ROOT, "outputs", "genetics", "blups_leaflet_lw.csv")
  IN_LEAFLET_SHAPE <- file.path(ROOT, "data", "genetics", "leaflet_shape_per_plot.csv")
  IN_H2_CANOPY     <- file.path(ROOT, "outputs", "genetics", "heritability_canopy.csv")

  OUT <- file.path(ROOT, "outputs", "figures", "Figure7")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  FILL_COL    <- "#8AB4D5"
  OUTLINE_COL <- "#1F3A5F"
  RUG_COL     <- "#1F3A5F"

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      aspect.ratio     = 1,
      plot.title       = element_text(size = 13, face = "bold", hjust = 0.5,
                                      margin = margin(b = 4)),
      axis.title.x     = element_text(size = 14, face = "bold", color = "black",
                                      margin = margin(t = 6)),
      axis.title.y     = element_text(size = 14, face = "bold", color = "black",
                                      margin = margin(r = 4)),
      axis.text        = element_text(size = 11, color = "black"),
      axis.ticks       = element_line(color = "black", linewidth = 0.7),
      axis.ticks.length = unit(0.18, "cm"),
      panel.grid.major = element_line(color = "gray92", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background = element_rect(fill = "white"),
      plot.background  = element_rect(fill = "white", color = NA),
      plot.margin      = margin(8, 12, 8, 8)
    )

  b_canopy <- read_csv(IN_BLUP_CANOPY,   show_col_types = FALSE)
  b_yield  <- read_csv(IN_BLUP_YIELD,    show_col_types = FALSE)
  b_lr     <- read_csv(IN_BLUP_LW,       show_col_types = FALSE)
  lr_raw   <- read_csv(IN_LEAFLET_SHAPE, show_col_types = FALSE)

  cat(sprintf("Canopy BLUPs        : %d lines x %d cols\n", nrow(b_canopy), ncol(b_canopy)))
  cat(sprintf("Yield-per-LAI BLUPs : %d lines x %d cols\n", nrow(b_yield), ncol(b_yield)))
  cat(sprintf("Leaflet L:W BLUPs   : %d lines x %d cols\n", nrow(b_lr), ncol(b_lr)))

  # Shift the zero-centered Leaflet L:W line effects by the mean per-plot ratio (column lr).
  lr_pop_mean <- mean(lr_raw$lr, na.rm = TRUE)
  b_lr$leaf_ratio_LR_display <- b_lr$leaf_ratio_LR + lr_pop_mean

  # Density of one trait's BLUPs with a rug of the line values. The x range is the data range
  # padded by 5% on each side.
  mk_density <- function(d, var_col, x_label, title_lab) {
    vals <- d[[var_col]]
    vals <- vals[!is.na(vals) & is.finite(vals)]
    if (length(vals) < 5) return(NULL)
    xr <- range(vals)
    pad <- diff(xr) * 0.05
    ggplot(data.frame(v = vals), aes(x = v)) +
      geom_density(fill = FILL_COL, alpha = 0.70,
                   color = OUTLINE_COL, linewidth = 0.5) +
      geom_rug(color = RUG_COL, alpha = 0.55, length = unit(0.04, "npc")) +
      scale_x_continuous(limits = c(xr[1] - pad, xr[2] + pad),
                         expand = expansion(mult = c(0, 0))) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
      labs(title = title_lab, x = x_label, y = "Density") +
      pub_theme
  }

  p_A <- mk_density(b_canopy, "A_mean_repro",
    expression(bold("Canopy A") ~ "(" * mu * mol ~ CO[2] ~ m^-2 ~ s^-1 * ")"),
    expression(A[mean]^reproductive))
  p_L <- mk_density(b_canopy, "L_mean_repro",
    expression(bold("Canopy LUE") ~ "(" * mu * mol ~ CO[2] ~ "/" * mu * mol ~ PAR * ")"),
    expression(LUE[mean]^reproductive))

  # Yield-per-LAI BLUPs of the model fitted to both sites and all lines, in bu/ac per LAI and
  # converted to kg/ha per LAI (1 bu/ac = 67.25 kg/ha).
  b_yield$yield_per_LAI        <- b_yield$yield_per_LAI_BOTH_all_lines
  b_yield$yield_per_LAI_metric <- b_yield$yield_per_LAI * 67.25
  p_Y <- mk_density(b_yield, "yield_per_LAI",
    expression(bold("Yield per unit LAI") ~ "(bu ac"^-1 ~ "/ LAI)"),
    "Yield-per-LAI")
  p_Y_metric <- mk_density(b_yield, "yield_per_LAI_metric",
    expression(bold("Yield per unit LAI") ~ "(kg ha"^-1 ~ "/ LAI)"),
    "Yield-per-LAI")
  p_LR <- mk_density(b_lr, "leaf_ratio_LR_display",
    expression(bold("Leaflet length:max-width ratio")),
    "Leaflet L:W")

  W <- 4.0; H <- 4.0; DPI <- 300
  ggsave(file.path(OUT, "Fig7A_leaflet_lw_density.png"),          p_LR,       device = ragg::agg_png, width = W, height = H, dpi = DPI, bg = "white")
  ggsave(file.path(OUT, "Fig7A_yield_per_lai_density.png"),       p_Y,        device = ragg::agg_png, width = W, height = H, dpi = DPI, bg = "white")
  ggsave(file.path(OUT, "Fig7A_yield_per_lai_density_metric.png"), p_Y_metric, device = ragg::agg_png, width = W, height = H, dpi = DPI, bg = "white")
  ggsave(file.path(OUT, "Fig7A_canopy_A_density.png"),            p_A,        device = ragg::agg_png, width = W, height = H, dpi = DPI, bg = "white")
  ggsave(file.path(OUT, "Fig7A_canopy_LUE_density.png"),          p_L,        device = ragg::agg_png, width = W, height = H, dpi = DPI, bg = "white")

  # Cullis heritability of canopy A and LUE from the model fitted to both sites and all lines.
  h2_canopy <- read_csv(IN_H2_CANOPY, show_col_types = FALSE) %>%
    filter(model == "BOTH-all-lines")
  h2_A <- h2_canopy$H2_Cullis[h2_canopy$response == "A_mean_repro"]
  h2_L <- h2_canopy$H2_Cullis[h2_canopy$response == "L_mean_repro"]

  # Write the statistics file. The Leaflet L:W (0.95) and yield-per-LAI (0.39) heritabilities
  # are printed as fixed values. They are the H2_Cullis values, rounded to two decimals, in
  # outputs/genetics/heritability_leaflet_lw.csv and in the BOTH-all-lines row of
  # outputs/genetics/heritability_yield_per_lai.csv.
  sink(file.path(OUT, "Fig7A_statistics.txt"))
  cat("================================================================================\n")
  cat("Fig 7A - Line BLUP distributions, with the number of lines, range and Cullis heritability\n")
  cat("================================================================================\n\n")
  cat("Leaflet L:W (field morphology)\n")
  cat(sprintf("  n_lines = %d; range = [%.3f, %.3f]\n",
              sum(!is.na(b_lr$leaf_ratio_LR_display)),
              min(b_lr$leaf_ratio_LR_display, na.rm = TRUE),
              max(b_lr$leaf_ratio_LR_display, na.rm = TRUE)))
  cat("  Cullis h2 (Leaflet L:W model, Methods S1.7) = 0.95\n\n")
  cat("Yield per LAI (field measurement)\n")
  cat(sprintf("  n_lines = %d; range = [%.3f, %.3f] bu/ac per LAI\n",
              sum(!is.na(b_yield$yield_per_LAI)),
              min(b_yield$yield_per_LAI, na.rm = TRUE),
              max(b_yield$yield_per_LAI, na.rm = TRUE)))
  cat("  Cullis h2 (BOTH-all-lines) = 0.39\n\n")
  cat("Canopy A (A_mean_repro, Helios with per-plot A-Ci biochemistry, combination-mean Rd25 and per-plot PROSPECT-D optics)\n")
  cat(sprintf("  n_lines = %d; range = [%.3f, %.3f] umol CO2 / m2 / s\n",
              sum(!is.na(b_canopy$A_mean_repro)),
              min(b_canopy$A_mean_repro, na.rm = TRUE),
              max(b_canopy$A_mean_repro, na.rm = TRUE)))
  cat(sprintf("  Cullis h2 (BOTH-all-lines) = %.2f\n", h2_A))
  cat("\nCanopy LUE (L_mean_repro, Helios with per-plot A-Ci biochemistry, combination-mean Rd25 and per-plot PROSPECT-D optics)\n")
  cat(sprintf("  n_lines = %d; range = [%.4f, %.4f] umol CO2 / umol PAR\n",
              sum(!is.na(b_canopy$L_mean_repro)),
              min(b_canopy$L_mean_repro, na.rm = TRUE),
              max(b_canopy$L_mean_repro, na.rm = TRUE)))
  cat(sprintf("  Cullis h2 (BOTH-all-lines) = %.2f\n", h2_L))
  cat("\n--- Panel annotations ---\n")
  cat(sprintf("  Leaflet L:W: 'h2 = 0.95, n = %d lines'\n", sum(!is.na(b_lr$leaf_ratio_LR_display))))
  cat(sprintf("  Yield per LAI: 'h2 = 0.39, n = %d lines'\n", sum(!is.na(b_yield$yield_per_LAI))))
  cat(sprintf("  Canopy A: 'h2 = %.2f, n = %d lines'\n", h2_A, sum(!is.na(b_canopy$A_mean_repro))))
  cat(sprintf("  Canopy LUE: 'h2 = %.2f, n = %d lines'\n", h2_L, sum(!is.na(b_canopy$L_mean_repro))))
  sink()

  cat(sprintf("\nWrote 5 panels and Fig7A_statistics.txt to %s\n", OUT))
}

# ==================================================================================================
# Section fig7b
# Fig 7B: Manhattan plot of the association scans for the four traits
# ==================================================================================================
#
# Purpose
#   Draws the Manhattan plot of Fig. 7B from the marker-trait association scans of Leaflet
#   L:W, Canopy A, Canopy LUE and yield per LAI. All four scans used the same test, the
#   kinship-corrected mixed-model slope (rrBLUP::mixed.solve) with the standard error and
#   two-sided P from ordinary least squares. Markers at or above the Bonferroni threshold
#   (P = 0.05 / number of markers) are colored by trait and the others are gray. A text file
#   gives the threshold and the top marker of each trait (the top-marker P values in the
#   Results and Table S20). The quantile-quantile inset of Fig. 7B is not drawn here.
#
# Inputs
#   outputs/genetics/gwas_leaflet_lw.csv      association scan, Leaflet L:W (genetics step)
#   outputs/genetics/gwas_canopy_A.csv        association scan, Canopy A
#   outputs/genetics/gwas_canopy_LUE.csv      association scan, Canopy LUE
#   outputs/genetics/gwas_yield_per_lai.csv   association scan, yield per LAI
#
# Outputs
#   outputs/figures/Figure7/Fig7B_manhattan.png
#   outputs/figures/Figure7/Fig7B_top_hits.txt   Bonferroni threshold and top marker per trait
#   The PNG file is written with the ragg device (ragg::agg_png), which rendered the
#   published panel.

fig7b <- function() {
  GWAS_DIR <- file.path(ROOT, "outputs", "genetics")
  OUT <- file.path(ROOT, "outputs", "figures", "Figure7")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  TRAIT_COLS <- c(
    "Leaflet L:W" = "#2E7D32",
    "Canopy A"    = "#2E86AB",
    "Canopy LUE"  = "#A23B72",
    "Yield/LAI"   = "#F18F01"
  )
  TRAIT_SHAPES <- c(
    "Leaflet L:W" = 18,
    "Canopy A"    = 16,
    "Canopy LUE"  = 17,
    "Yield/LAI"   = 15
  )
  BONF_COL <- "#666666"

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(size = 14, face = "bold", hjust = 0.5,
                                      margin = margin(b = 4)),
      axis.title.x     = element_text(size = 14, face = "bold", color = "black",
                                      margin = margin(t = 6)),
      axis.title.y     = element_text(size = 14, face = "bold", color = "black",
                                      margin = margin(r = 4)),
      axis.text.x      = element_text(size = 11, color = "black"),
      axis.text.y      = element_text(size = 11, color = "black"),
      axis.ticks       = element_line(color = "black", linewidth = 0.7),
      axis.ticks.length = unit(0.18, "cm"),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background = element_rect(fill = "white"),
      plot.background  = element_rect(fill = "white", color = NA),
      legend.position  = "top",
      legend.title     = element_text(face = "bold", size = 11),
      legend.text      = element_text(size = 10),
      legend.key.width = unit(0.5, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.margin    = margin(0, 0, 0, 0),
      plot.margin      = margin(8, 12, 8, 8)
    )

  # Read one association scan. The -log10(P) stored in the file is used when present, so that
  # very small P values do not depend on how the reader parses them. P values of zero or NA are
  # set to the smallest positive double.
  load_qtl <- function(fp, label) {
    if (!file.exists(fp)) stop(sprintf("Missing: %s", fp))
    d <- read.csv(fp, stringsAsFactors = FALSE)
    d$minuslog10p_src <- if ("minuslog10p" %in% names(d)) d$minuslog10p else NA_real_
    d %>% mutate(chr_num = as.numeric(gsub("[^0-9]", "", chr)),
                 pvalue = ifelse(is.na(pvalue) | pvalue <= 0,
                                  .Machine$double.xmin, pvalue),
                 Trait = label)
  }

  qtl_all <- bind_rows(
    load_qtl(file.path(GWAS_DIR, "gwas_leaflet_lw.csv"),    "Leaflet L:W"),
    load_qtl(file.path(GWAS_DIR, "gwas_canopy_A.csv"),      "Canopy A"),
    load_qtl(file.path(GWAS_DIR, "gwas_canopy_LUE.csv"),    "Canopy LUE"),
    load_qtl(file.path(GWAS_DIR, "gwas_yield_per_lai.csv"), "Yield/LAI")
  )
  qtl_all$Trait <- factor(qtl_all$Trait,
                          levels = c("Leaflet L:W", "Canopy A", "Canopy LUE", "Yield/LAI"))

  n_markers <- length(unique(qtl_all$marker))
  cat(sprintf("Loaded %d points across 4 traits (%d unique markers)\n",
              nrow(qtl_all), n_markers))

  # Cumulative genome position. Chromosomes are laid end to end with a gap of 4% of the mean
  # chromosome span, and each chromosome label sits at the center of its span.
  chr_lens <- qtl_all %>% group_by(chr_num) %>%
    summarize(len = max(pos_bp) - min(pos_bp) + 1, .groups = "drop") %>%
    arrange(chr_num)
  gap <- mean(chr_lens$len) * 0.04
  chr_lens <- chr_lens %>%
    mutate(start = cumsum(c(0, head(len, -1) + gap)),
           center = start + len / 2)

  qtl_all <- qtl_all %>%
    left_join(chr_lens[, c("chr_num", "start")], by = "chr_num") %>%
    mutate(pos_cum     = start + pos_bp,
           minuslog10p = ifelse(!is.na(minuslog10p_src),
                                 minuslog10p_src,
                                 -log10(pvalue)))

  # Bonferroni threshold on the -log10 scale and the y-axis limit.
  bonf_line <- -log10(0.05 / n_markers)
  y_max <- ceiling(max(qtl_all$minuslog10p, na.rm = TRUE)) + 4

  top_per_trait <- qtl_all %>% group_by(Trait) %>%
    slice_min(pvalue, n = 1) %>% ungroup()
  cat("\nTop marker per trait\n")
  print(top_per_trait %>%
        select(Trait, marker, chr, pos_bp, pvalue, minuslog10p) %>%
        mutate(pvalue = signif(pvalue, 3),
               minuslog10p = signif(minuslog10p, 3)))

  qtl_below <- qtl_all %>% filter(minuslog10p <  bonf_line)
  qtl_above <- qtl_all %>% filter(minuslog10p >= bonf_line)

  BELOW_COL  <- "gray70"
  BASE_SIZE  <- 2.6
  ABOVE_SIZE <- BASE_SIZE * 2

  p <- ggplot() +
    geom_hline(yintercept = bonf_line, linetype = "dashed",
               color = BONF_COL, linewidth = 0.5, alpha = 0.7) +
    geom_point(data = qtl_below,
               aes(x = pos_cum, y = minuslog10p),
               color = BELOW_COL, shape = 16,
               size = BASE_SIZE, alpha = 0.55, stroke = 0) +
    geom_point(data = qtl_above,
               aes(x = pos_cum, y = minuslog10p,
                   color = Trait, shape = Trait),
               size = ABOVE_SIZE, alpha = 0.85, stroke = 0) +
    scale_color_manual(values = TRAIT_COLS, name = "Trait", drop = FALSE) +
    scale_shape_manual(values = TRAIT_SHAPES, name = "Trait", drop = FALSE) +
    guides(color = guide_legend(override.aes = list(size = 4.0, alpha = 1)),
           shape  = guide_legend(override.aes = list(size = 4.0, alpha = 1))) +
    scale_x_continuous(breaks = chr_lens$center, labels = chr_lens$chr_num,
                       expand = expansion(mult = c(0.005, 0.005))) +
    scale_y_continuous(limits = c(0, y_max),
                       breaks = seq(0, y_max, 10),
                       expand = expansion(mult = c(0.005, 0.02))) +
    labs(x = "Chromosome",
         y = expression(bold("-log"[10] * "(P)"))) +
    pub_theme

  ggsave(file.path(OUT, "Fig7B_manhattan.png"),
         p, device = ragg::agg_png, width = 6.5, height = 4.0, dpi = 300, bg = "white")

  # Write the threshold and the top marker of each trait.
  sink(file.path(OUT, "Fig7B_top_hits.txt"))
  cat("================================================================================\n")
  cat("Fig 7B - Manhattan plot of the four traits (mixed-model slope, OLS standard error and P)\n")
  cat("================================================================================\n\n")
  cat(sprintf("Bonferroni threshold (-log10P at 0.05 / %d markers): %.3f\n\n",
              n_markers, bonf_line))
  cat("Top hits per trait:", "\n", sep = "")
  print(top_per_trait %>%
        select(Trait, marker, chr, pos_bp, pvalue, beta, se, minuslog10p) %>%
        mutate(pvalue = signif(pvalue, 3),
               minuslog10p = signif(minuslog10p, 3),
               beta = signif(beta, 4),
               se = signif(se, 4)))
  sink()

  cat(sprintf("\nWrote Fig7B_manhattan.png and Fig7B_top_hits.txt to %s\n", OUT))
}

# ==================================================================================================
# Section fig7b_qq
# Fig 7B inset: Quantile-quantile plot of the Leaflet L:W association scan
# ==================================================================================================
#
# Purpose
#   Draws the inset of Fig. 7B. The observed -log10(P) of each quality-controlled marker in the
#   Leaflet L:W scan is plotted against the value expected under the null hypothesis of no
#   association, with the 1:1 line dashed and its pointwise 95% interval shaded. The expected
#   values are -log10 of the uniform plotting positions (i - 0.5) / n, and the interval comes
#   from the beta distribution of the i-th order statistic of n uniform P-values. Observed
#   values are taken from the scan's minuslog10p column, which stays finite for the P-values
#   that underflow to zero.
#
# Inputs
#   outputs/genetics/gwas_leaflet_lw.csv   Leaflet L:W scan (code/5_genetics/06_gwas_leaflet_lw.R)
#
# Outputs
#   outputs/figures/Figure7/Fig7B_qq_inset_leaflet_lw.png
#   The PNG file is written with the ragg device (ragg::agg_png).

fig7b_qq <- function() {
  IN   <- file.path(ROOT, "outputs", "genetics", "gwas_leaflet_lw.csv")
  OUT  <- file.path(ROOT, "outputs", "figures", "Figure7")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Trait color and point shape of Leaflet L:W in the Manhattan plot (section fig7b).
  LW_COLOR <- "#2E7D32"
  LW_SHAPE <- 18

  g <- read.csv(IN)
  obs <- sort(g$minuslog10p[is.finite(g$minuslog10p)])
  n <- length(obs)
  i <- seq_len(n)

  # Expected -log10(P) and the pointwise 95% interval, both ordered from the smallest to the
  # largest value so that they align with the sorted observed values.
  q <- data.frame(
    expected = rev(-log10(ppoints(n))),
    observed = obs,
    lower    = rev(-log10(qbeta(0.975, i, n - i + 1))),
    upper    = rev(-log10(qbeta(0.025, i, n - i + 1)))
  )

  p <- ggplot(q, aes(expected, observed)) +
    geom_ribbon(aes(ymin = lower, ymax = upper), fill = "gray80", alpha = 0.7) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray40") +
    geom_point(color = LW_COLOR, shape = LW_SHAPE, size = 2.2) +
    scale_x_continuous(breaks = seq(0, 2.5, 0.5)) +
    labs(x = expression(bold("Expected") ~ bold("-log"[10] * "(P)")),
         y = expression(bold("Observed") ~ bold("-log"[10] * "(P)"))) +
    theme_minimal(base_size = 11) +
    theme(axis.title = element_text(size = 10, face = "bold", color = "black"),
          axis.text = element_text(size = 9, color = "black"),
          panel.grid.major = element_line(color = "gray92", linewidth = 0.3),
          panel.grid.minor = element_blank(),
          panel.border = element_rect(color = "black", fill = NA, linewidth = 0.8),
          panel.background = element_rect(fill = "white"),
          plot.background = element_rect(fill = "white", color = NA))

  ggsave(file.path(OUT, "Fig7B_qq_inset_leaflet_lw.png"), p, width = 3.2, height = 2.9, dpi = 300,
         bg = "white", device = ragg::agg_png)
  cat(sprintf("Wrote the Fig 7B Q-Q inset: %d markers, largest observed -log10(P) = %.1f\n", n, max(obs)))
}

# ==================================================================================================
# Section fig7c
# Fig 7C: Standardized per-allele effect at SNP1293 for the four traits
# ==================================================================================================
#
# Purpose
#   Draws Fig. 7C. For each trait (Leaflet L:W, Canopy A, Canopy LUE and yield per LAI) the
#   per-allele effect at SNP1293 (Gm20:34,667,185, within GmJAG1) is taken from the
#   association scan and divided by the SD of the trait's line BLUPs,
#   beta_std = beta / SD(BLUP), with a 95% confidence interval of beta_std +/- 1.96 SE_std.
#   A text file lists the raw and standardized effects (the beta_std values and confidence
#   intervals in the Results).
#
# Inputs
#   outputs/genetics/gwas_leaflet_lw.csv      association scan, Leaflet L:W (genetics step)
#   outputs/genetics/gwas_canopy_A.csv        association scan, Canopy A
#   outputs/genetics/gwas_canopy_LUE.csv      association scan, Canopy LUE
#   outputs/genetics/gwas_yield_per_lai.csv   association scan, yield per LAI
#   outputs/genetics/blups_leaflet_lw.csv     Leaflet L:W BLUPs
#   outputs/genetics/blups_canopy.csv         canopy A and LUE BLUPs
#   outputs/genetics/blups_yield_per_lai.csv  yield-per-LAI BLUPs
#
# Outputs
#   outputs/figures/Figure7/Fig7C_snp1293_effects.png
#   outputs/figures/Figure7/Fig7C_statistics.txt   raw and standardized effects at SNP1293
#   The PNG file is written with the ragg device (ragg::agg_png), which rendered the
#   published panel.

fig7c <- function() {
  GEN_DIR <- file.path(ROOT, "outputs", "genetics")

  OUT <- file.path(ROOT, "outputs", "figures", "Figure7")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  TARGET_SNP <- "SNP1293"

  BAR_FILL    <- "#5B8FB9"
  BAR_OUTLINE <- "#1F3A5F"
  ERROR_COL   <- "black"

  pub_theme <- theme_minimal(base_size = 12) +
    theme(
      aspect.ratio     = 0.62,
      plot.title       = element_text(size = 13, face = "bold", hjust = 0.5,
                                      margin = margin(b = 6)),
      axis.title.x     = element_blank(),
      axis.title.y     = element_text(size = 13, face = "bold", color = "black",
                                      margin = margin(r = 4)),
      axis.text.x      = element_text(size = 12, face = "bold", color = "black"),
      axis.text.y      = element_text(size = 11, color = "black"),
      axis.ticks       = element_line(color = "black", linewidth = 0.7),
      axis.ticks.length = unit(0.18, "cm"),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.border     = element_rect(color = "black", fill = NA, linewidth = 1.0),
      panel.background = element_rect(fill = "white"),
      plot.background  = element_rect(fill = "white", color = NA),
      plot.margin      = margin(8, 12, 8, 8)
    )

  # Effect (beta) and standard error of one marker in an association scan.
  get_betaSE <- function(qtl_fp, snp_id) {
    d <- read.csv(qtl_fp, stringsAsFactors = FALSE)
    row <- d[d$marker == snp_id, ]
    if (nrow(row) != 1) stop(sprintf("SNP %s not unique in %s", snp_id, qtl_fp))
    list(beta = as.numeric(row$beta), se = as.numeric(row$se))
  }
  # SD of a trait's line BLUPs (finite values only).
  get_blupSD <- function(blup_fp, trait_col) {
    b <- read_csv(blup_fp, show_col_types = FALSE)
    if (!trait_col %in% names(b))
      stop(sprintf("Column %s missing in %s", trait_col, blup_fp))
    v <- b[[trait_col]]; v <- v[!is.na(v) & is.finite(v)]
    sd(v)
  }

  # Scan file, BLUP file and BLUP column of each trait. The source text is printed in the
  # statistics file.
  trait_specs <- list(
    list(trait = "leaf_ratio_LR", label = "Leaflet L:W",
         qtl  = file.path(GEN_DIR, "gwas_leaflet_lw.csv"),
         blup = file.path(GEN_DIR, "blups_leaflet_lw.csv"),
         blup_col = "leaf_ratio_LR",
         source = "field morphology"),
    list(trait = "A_mean_repro",  label = "Canopy A",
         qtl  = file.path(GEN_DIR, "gwas_canopy_A.csv"),
         blup = file.path(GEN_DIR, "blups_canopy.csv"),
         blup_col = "A_mean_repro",
         source = "Helios with per-plot A-Ci biochemistry, combination-mean Rd25 and per-plot PROSPECT-D optics"),
    list(trait = "L_mean_repro",  label = "Canopy LUE",
         qtl  = file.path(GEN_DIR, "gwas_canopy_LUE.csv"),
         blup = file.path(GEN_DIR, "blups_canopy.csv"),
         blup_col = "L_mean_repro",
         source = "Helios with per-plot A-Ci biochemistry, combination-mean Rd25 and per-plot PROSPECT-D optics"),
    list(trait = "yield_per_LAI", label = "Yield/LAI",
         qtl  = file.path(GEN_DIR, "gwas_yield_per_lai.csv"),
         blup = file.path(GEN_DIR, "blups_yield_per_lai.csv"),
         blup_col = "yield_per_LAI_BOTH_all_lines",
         source = "field yield measurement")
  )

  # Standardize beta and its SE by the SD of the BLUPs and form the 95% confidence interval.
  rows <- lapply(trait_specs, function(s) {
    bs <- get_betaSE(s$qtl, TARGET_SNP)
    sd_blup <- get_blupSD(s$blup, s$blup_col)
    beta_std <- bs$beta / sd_blup
    se_std   <- bs$se   / sd_blup
    data.frame(trait = s$trait, label = s$label,
               source = s$source,
               beta_raw = bs$beta, se_raw = bs$se, sd_blup = sd_blup,
               beta_std = beta_std, se_std = se_std,
               ci_lo = beta_std - 1.96 * se_std,
               ci_hi = beta_std + 1.96 * se_std)
  })
  df <- do.call(rbind, rows)
  df$label <- factor(df$label,
                     levels = c("Leaflet L:W","Canopy A","Canopy LUE","Yield/LAI"))

  cat("=== SNP1293 per-allele beta (raw and standardized) ===\n")
  print(df %>%
        transmute(label, source,
                  beta_raw = signif(beta_raw, 3),
                  se_raw   = signif(se_raw, 3),
                  sd_blup  = signif(sd_blup, 3),
                  beta_std = signif(beta_std, 3),
                  ci95     = sprintf("[%.3f, %.3f]", ci_lo, ci_hi)))

  y_max <- max(df$ci_hi, na.rm = TRUE) + 0.10
  y_min <- min(0, min(df$ci_lo, na.rm = TRUE) - 0.10)

  p <- ggplot(df, aes(x = label, y = beta_std)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_col(fill = BAR_FILL, color = BAR_OUTLINE,
             linewidth = 0.5, width = 0.55) +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                  width = 0.18, linewidth = 0.6, color = ERROR_COL) +
    scale_y_continuous(limits = c(y_min, y_max),
                       expand = expansion(mult = c(0.02, 0.02))) +
    labs(y = expression(bold("Per-allele " * beta * " (SD units, ±95% CI)"))) +
    pub_theme

  ggsave(file.path(OUT, "Fig7C_snp1293_effects.png"),
         p, device = ragg::agg_png, width = 6.0, height = 4.5, dpi = 300, bg = "white")

  # Write the statistics file.
  sink(file.path(OUT, "Fig7C_statistics.txt"))
  cat("================================================================================\n")
  cat("Fig 7C - Per-allele effect at SNP1293 for the four traits\n")
  cat("================================================================================\n\n")
  cat("Target SNP: ", TARGET_SNP, " (GmJAG1 locus on Chr 20)\n\n", sep = "")
  cat("Standardized beta (per-allele effect in SD units of trait BLUPs):\n\n")
  for (i in seq_len(nrow(df))) {
    r <- df[i, ]
    cat(sprintf("  %-12s [%s]\n", r$label, r$source))
    cat(sprintf("    raw beta = %+.4f, raw SE = %.4f\n", r$beta_raw, r$se_raw))
    cat(sprintf("    SD(BLUPs) = %.4f\n", r$sd_blup))
    cat(sprintf("    std beta = %+.3f, 95%% CI = [%+.3f, %+.3f]\n\n",
                r$beta_std, r$ci_lo, r$ci_hi))
  }
  cat("--- Summary of standardized effects ---\n")
  cat(sprintf("  Leaflet L:W %+.2f, Canopy A %+.2f, Canopy LUE %+.2f, Yield/LAI %+.2f\n",
              df$beta_std[df$label == "Leaflet L:W"],
              df$beta_std[df$label == "Canopy A"],
              df$beta_std[df$label == "Canopy LUE"],
              df$beta_std[df$label == "Yield/LAI"]))
  cat("  All four values are positive, so the narrow-leaflet (Ln) allele at SNP1293\n")
  cat("  increases each trait.\n")
  sink()

  cat(sprintf("\nWrote Fig7C_snp1293_effects.png and Fig7C_statistics.txt to %s\n", OUT))
}

# ==================================================================================================
# Section figS1
# Fig S1: Per-plot plant height, leaf photosynthetic capacity, SPAD and LMA inputs
# ==================================================================================================
#
# Purpose
#   Draws Fig. S1 at its final size for the broad- and narrow-leaflet NIL plots in each
#   site x row spacing combination. (A) Plant height against DAP, interpolated to each
#   simulated date, with plot lines and leaflet-type means with 95% confidence intervals.
#   (B-E) Vcmax25, Jmax25, Rd25 and Tp25 from the per-plot A-Ci curve fits. (F) SPAD-502
#   readings. (G) Leaf mass per area. Panels B-G show only plots with a direct measurement.
#   Biochemistry values are kept where the plot's source flag is "measured", and SPAD and
#   LMA values where they come from the July A-Ci leaves or the August survey. Plots that
#   received a combination mean are left out. The finished figure stacks the seven panels,
#   and each panel is also written on its own canvas.
#
# Inputs
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_SF.csv   per-plot per-date canopy inputs with
#                                                          leaf optics and per-plot Rd25 fits,
#                                                          SoyFACE (leaf-inputs step)
#   outputs/leaf_inputs/canopy_inputs_leaf_optics_EF.csv   as above, Energy Farm
#   code/7_figures/supp_figure_style.R                     shared style of Figs. S1-S6 and S8
#
# Outputs
#   outputs/figures/FigureS1/FigS1_combined.png        the finished figure, panels A-G
#   outputs/figures/FigureS1/FigS1A_plant_height_*.png
#   outputs/figures/FigureS1/FigS1B_vcmax25_*.png
#   outputs/figures/FigureS1/FigS1C_jmax25_*.png
#   outputs/figures/FigureS1/FigS1D_rd25_*.png
#   outputs/figures/FigureS1/FigS1E_tp25_*.png
#   outputs/figures/FigureS1/FigS1F_spad_*.png
#   outputs/figures/FigureS1/FigS1G_lma_*.png
#   Each single panel is written twice, as *_annotated.png with the plot numbers and as
#   *_not_annotated.png without them.
#   outputs/figures/FigureS1/FigS1_plot_numbers.csv    number of plots written on each panel,
#                                                      per combination and leaflet type
#   The PNG files are written with the ragg device (ragg::agg_png).

figS1 <- function() {
  SF_FP <- file.path(ROOT, "outputs", "leaf_inputs", "canopy_inputs_leaf_optics_SF.csv")
  EF_FP <- file.path(ROOT, "outputs", "leaf_inputs", "canopy_inputs_leaf_optics_EF.csv")
  OUT   <- file.path(ROOT, "outputs", "figures", "FigureS1")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Read the per-plot per-date inputs of both sites and keep the broad- and narrow-leaflet
  # NILs. A trait value is kept only where it was measured on the plot and is positive.
  sf <- read_csv(SF_FP, show_col_types = FALSE) %>% mutate(Site = "SoyFACE")
  ef <- read_csv(EF_FP, show_col_types = FALSE) %>% mutate(Site = "Energy Farm")

  cols_keep <- c("Site", "Loc_ID", "Spacing", "Leaf_type", "DAP", "height_m_interp",
                 "vcmax", "jmax", "rd25", "tp25",
                 "vcmax_source", "jmax_source", "rd25_source", "tp25_source",
                 "spad", "SPAD_source", "lma_gm2", "LMA_source")
  d <- bind_rows(sf %>% select(any_of(cols_keep)), ef %>% select(any_of(cols_keep))) %>%
    filter(Leaf_type %in% c("Broad", "Narrow")) %>%
    mutate(
      Leaf_type  = factor(Leaf_type, levels = c("Broad", "Narrow")),
      Cell       = cell_factor(Site, Spacing),
      height_cm  = height_m_interp * 100,
      vcmax_meas = ifelse(vcmax_source == "measured" & is.finite(vcmax) & vcmax > 0, vcmax, NA_real_),
      jmax_meas  = ifelse(jmax_source  == "measured" & is.finite(jmax)  & jmax  > 0, jmax,  NA_real_),
      rd25_meas  = ifelse(rd25_source  == "measured" & is.finite(rd25)  & rd25  > 0, rd25,  NA_real_),
      tp25_meas  = ifelse(tp25_source  == "measured" & is.finite(tp25)  & tp25  > 0, tp25,  NA_real_),
      spad_meas  = ifelse(SPAD_source %in% c("baseline_aug", "cascade_jul") &
                            is.finite(spad)    & spad    > 0, spad,    NA_real_),
      lma_meas   = ifelse(LMA_source  %in% c("baseline_aug", "cascade_jul") &
                            is.finite(lma_gm2) & lma_gm2 > 0, lma_gm2, NA_real_)
    )

  # One row per plot for the scalar traits (they repeat on every date of a plot).
  plot_lvl <- d %>%
    group_by(Cell, Leaf_type, Loc_ID) %>%
    summarize(vcmax = first(vcmax_meas), jmax = first(jmax_meas), rd25 = first(rd25_meas),
              tp25 = first(tp25_meas), spad = first(spad_meas), lma = first(lma_meas),
              .groups = "drop") %>%
    as.data.frame()

  # Console summary of the rows, plots and measured values per group.
  cat("\n=== Rows (plot-dates) per site x row spacing and leaflet type ===\n")
  print(as.data.frame(d %>% count(Cell, Leaf_type, name = "rows")))

  cat("\n=== Plots per site x row spacing and leaflet type, with measured values ===\n")
  n_cell <- plot_lvl %>%
    group_by(Cell, Leaf_type) %>%
    summarize(
      n_plots       = n(),
      n_vcmax_meas  = sum(!is.na(vcmax)),
      n_jmax_meas   = sum(!is.na(jmax)),
      n_rd25_meas   = sum(!is.na(rd25)),
      n_tp25_meas   = sum(!is.na(tp25)),
      n_spad_meas   = sum(!is.na(spad)),
      n_lma_meas    = sum(!is.na(lma)),
      vcmax_mean    = round(mean(vcmax, na.rm = TRUE), 1),
      jmax_mean     = round(mean(jmax,  na.rm = TRUE), 1),
      rd25_mean     = round(mean(rd25,  na.rm = TRUE), 3),
      tp25_mean     = round(mean(tp25,  na.rm = TRUE), 2),
      spad_mean     = round(mean(spad,  na.rm = TRUE), 1),
      lma_mean      = round(mean(lma,   na.rm = TRUE), 1),
      .groups = "drop"
    )
  print(as.data.frame(n_cell))

  # Panel A. Per-plot height trajectories with leaflet-type means and 95% confidence
  # intervals (mean +/- 1.96 SE) at each date.
  height_summary <- d %>%
    group_by(Cell, Leaf_type, DAP) %>%
    summarize(n = n(), mean = mean(height_cm, na.rm = TRUE), sd = sd(height_cm, na.rm = TRUE),
              se = sd / sqrt(n), lo95 = mean - 1.96 * se, hi95 = mean + 1.96 * se,
              .groups = "drop")
  height_n <- d %>% distinct(Cell, Leaf_type, Loc_ID) %>% count(Cell, Leaf_type)
  height_n_labels <- height_n %>%
    pivot_wider(names_from = Leaf_type, values_from = n) %>%
    mutate(label = sprintf("Broad, n = %d\nNarrow, n = %d", Broad, Narrow))

  height_panel <- function(notes = TRUE, legend = FALSE) {
    p <- ggplot() +
      geom_line(data = d, aes(x = DAP, y = height_cm, group = Loc_ID, color = Leaf_type),
                alpha = 0.15, linewidth = 0.2, show.legend = FALSE) +
      geom_ribbon(data = height_summary,
                  aes(x = DAP, ymin = lo95, ymax = hi95, group = Leaf_type, fill = Leaf_type),
                  alpha = 0.30, color = NA, show.legend = FALSE) +
      geom_line(data = height_summary,
                aes(x = DAP, y = mean, color = Leaf_type, group = Leaf_type),
                linewidth = 0.6, show.legend = legend) +
      scale_color_manual(values = LEAF_LINE, name = LEAF_NAME) +
      scale_fill_manual(values = LEAF_FILL, name = LEAF_NAME) +
      facet_wrap(~ Cell, nrow = 1) +
      scale_x_continuous(breaks = seq(0, 100, 14)) +
      labs(x = ttl("Days After Planting", "(DAP)"), y = NULL) +
      supp_theme
    if (notes) p <- p + geom_text(data = height_n_labels, aes(x = -Inf, y = Inf, label = label),
                                  hjust = -0.07, vjust = 1.25, size = NOTE_MM, family = FONT,
                                  lineheight = 0.95, color = "black", inherit.aes = FALSE)
    p
  }

  # Panels B-G. Column of the per-plot table, file name and two-line y title of each panel.
  BOXES <- list(
    B = list(col = "vcmax", file = "FigS1B_vcmax25", title = list(quote(bold("Vcmax"[25])), U$flux)),
    C = list(col = "jmax",  file = "FigS1C_jmax25",  title = list(quote(bold("Jmax"[25])),  U$flux)),
    D = list(col = "rd25",  file = "FigS1D_rd25",    title = list(quote(bold("Rd"[25])),    U$flux)),
    E = list(col = "tp25",  file = "FigS1E_tp25",    title = list(quote(bold("Tp"[25])),    U$flux)),
    F = list(col = "spad",  file = "FigS1F_spad",    title = list("SPAD-502", "reading")),
    G = list(col = "lma",   file = "FigS1G_lma",     title = list("LMA", U$g_m2)))
  HEIGHT_TITLE <- list("Plant height", pl("(cm)"))

  # Finished figure, with facet headers on the top row and x labels on the bottom row.
  box_plots <- lapply(names(BOXES), function(k) {
    box_panel(plot_lvl, BOXES[[k]]$col, xlabels = k == "G")
  })
  names(box_plots) <- names(BOXES)
  panels <- c(list(panel_cells("A", HEIGHT_TITLE, height_panel(), lift = STRIP_H)),
              lapply(names(BOXES), function(k) panel_cells(k, BOXES[[k]]$title, box_plots[[k]])))
  save_png(assemble(panels), file.path(OUT, "FigS1_combined.png"), height = 9.0)

  # Single panels.
  save_panel(function(notes) single_panel(HEIGHT_TITLE, height_panel(notes, legend = TRUE)),
             file.path(OUT, "FigS1A_plant_height"), height = 2.1)
  for (k in names(BOXES)) local({
    pn <- BOXES[[k]]
    save_panel(function(notes) single_panel(pn$title, box_panel(plot_lvl, pn$col, strips = TRUE,
                                                                xlabels = TRUE, notes = notes)),
               file.path(OUT, pn$file), height = 1.9)
  })

  # Number of plots written on each panel.
  plot_numbers <- rbind(
    cbind(panel = "A", as.data.frame(height_n)),
    do.call(rbind, lapply(names(BOXES), function(k) {
      cbind(panel = k, attr(box_plots[[k]], "plot_numbers"))
    })))
  write.csv(plot_numbers, file.path(OUT, "FigS1_plot_numbers.csv"), row.names = FALSE)

  cat(sprintf("\nWrote the finished figure, the single panels and FigS1_plot_numbers.csv to %s\n",
              OUT))
}

# ==================================================================================================
# Section figS2
# Fig S2: Per-plot leaflet dimensions of broad- and narrow-leaflet NILs
# ==================================================================================================
#
# Purpose
#   Draws Fig. S2 at its final size for the 530 simulated broad- and narrow-leaflet NIL
#   plots in each site x row spacing combination. (A) Leaflet length, (B) average width,
#   (C) maximum width, (D) area and (E) length-to-maximum-width ratio, the Leaflet L:W trait
#   of the text and the association analysis. Each plot has one leaflet measurement, which
#   repeats on every date in the input files. Box plots show medians and interquartile ranges
#   with jittered plots and the number of plots above each box. The finished figure stacks
#   the five panels, and each panel is also written on its own canvas.
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   as-run per-plot inputs,
#                                                                    SoyFACE (length_m, avwidth_m,
#                                                                    mxwidth_m, area_m2)
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   as above, Energy Farm
#   code/7_figures/supp_figure_style.R                             shared style of Figs. S1-S6
#                                                                    and S8
#
# Outputs
#   outputs/figures/FigureS2/FigS2_combined.png        the finished figure, panels A-E
#   outputs/figures/FigureS2/FigS2A_leaflet_length_*.png
#   outputs/figures/FigureS2/FigS2B_leaflet_average_width_*.png
#   outputs/figures/FigureS2/FigS2C_leaflet_maximum_width_*.png
#   outputs/figures/FigureS2/FigS2D_leaflet_area_*.png
#   outputs/figures/FigureS2/FigS2E_leaflet_length_to_maximum_width_*.png
#   Each single panel is written twice, as *_annotated.png with the plot numbers and as
#   *_not_annotated.png without them.
#   outputs/figures/FigureS2/FigS2_plot_numbers.csv    number of plots written on each panel,
#                                                      per combination and leaflet type
#   The PNG files are written with the ragg device (ragg::agg_png).

figS2 <- function() {
  INP <- file.path(ROOT, "data", "simulation_inputs")
  OUT <- file.path(ROOT, "outputs", "figures", "FigureS2")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # One row per plot (530 NIL plots). Leaflet dimensions are converted from m to cm and m2 to
  # cm2, and Leaflet L:W is length divided by maximum width.
  rd <- function(site) {
    x <- read.csv(file.path(INP, sprintf("canopy_inputs_per_plot_per_DAP_%s.csv", site)))
    x <- x[x$Leaf_type %in% c("Broad", "Narrow"),
           c("Loc_ID", "Spacing", "Leaf_type", "length_m", "avwidth_m", "mxwidth_m", "area_m2")]
    x$Site <- site
    x[!duplicated(x$Loc_ID), ]
  }
  d <- rbind(rd("SF"), rd("EF"))
  stopifnot(nrow(d) == 530, !anyNA(d[c("length_m", "avwidth_m", "mxwidth_m", "area_m2")]))
  d$Leaf_type  <- factor(d$Leaf_type, levels = c("Broad", "Narrow"))
  d$Cell       <- cell_factor(d$Site, d$Spacing)
  d$length_cm  <- d$length_m * 100
  d$avwidth_cm <- d$avwidth_m * 100
  d$mxwidth_cm <- d$mxwidth_m * 100
  d$area_cm2   <- d$area_m2 * 1e4
  d$LW_max     <- d$length_m / d$mxwidth_m

  # Console summary of the group means.
  print(aggregate(cbind(length_cm, avwidth_cm, mxwidth_cm, area_cm2, LW_max) ~ Cell + Leaf_type, d,
                  function(v) round(mean(v), 2)))

  # Column of the per-plot table, file name and two-line y title of each panel.
  PANELS <- list(
    A = list(col = "length_cm",  file = "FigS2A_leaflet_length",
             title = list("Leaflet length", pl("(cm)"))),
    B = list(col = "avwidth_cm", file = "FigS2B_leaflet_average_width",
             title = list("Leaflet average", ttl("width", "(cm)"))),
    C = list(col = "mxwidth_cm", file = "FigS2C_leaflet_maximum_width",
             title = list("Leaflet maximum", ttl("width", "(cm)"))),
    D = list(col = "area_cm2",   file = "FigS2D_leaflet_area",
             title = list("Leaflet area", U$cm2)),
    E = list(col = "LW_max",     file = "FigS2E_leaflet_length_to_maximum_width",
             title = list("Leaflet length /", "maximum width")))

  # Finished figure, with facet headers on the top row and x labels on the bottom row.
  n_rows <- length(PANELS)
  plots <- lapply(seq_len(n_rows), function(i) {
    box_panel(d, PANELS[[i]]$col, strips = i == 1, xlabels = i == n_rows)
  })
  fig <- assemble(lapply(seq_len(n_rows), function(i) {
    panel_cells(names(PANELS)[i], PANELS[[i]]$title, plots[[i]],
                lift = if (i == 1) STRIP_H else 0)
  }))
  save_png(fig, file.path(OUT, "FigS2_combined.png"), height = 6.5)

  # Single panels.
  for (k in names(PANELS)) local({
    pn <- PANELS[[k]]
    save_panel(function(notes) single_panel(pn$title, box_panel(d, pn$col, strips = TRUE,
                                                                xlabels = TRUE, notes = notes)),
               file.path(OUT, pn$file), height = 1.9)
  })

  # Number of plots written on each panel.
  plot_numbers <- do.call(rbind, lapply(seq_len(n_rows), function(i) {
    cbind(panel = names(PANELS)[i], attr(plots[[i]], "plot_numbers"))
  }))
  write.csv(plot_numbers, file.path(OUT, "FigS2_plot_numbers.csv"), row.names = FALSE)

  cat("Wrote the finished figure, the single panels and FigS2_plot_numbers.csv to", OUT, "\n")
}

# ==================================================================================================
# Section figS3
# Fig S3: Per-plot leaf reflectance spectra and PROSPECT-D leaf optical inputs
# ==================================================================================================
#
# Purpose
#   Draws Fig. S3 at its final size for the broad- and narrow-leaflet NIL plots in each site
#   x row spacing combination. (A) Per-plot leaf reflectance spectra R(lambda), 400-2500 nm,
#   with the number of broad (B) and narrow (N) plots in each facet header. (B) Leaf
#   chlorophyll content (LCC = 1.26 x SPAD + 6.63) for plots with a measured SPAD reading.
#   (C-F) PAR and NIR reflectance and transmittance from the per-plot PROSPECT-D runs, for
#   plots whose optics were anchored to a measured SPAD or LMA value. Box plots show medians
#   and interquartile ranges with the number of plots above each box. The finished figure
#   stacks the six panels, and each panel is also written on its own canvas.
#
# Inputs
#   outputs/leaf_inputs/leaf_optical_per_plot.csv       per-plot LCC, PROSPECT-D bands and
#                                                        source flags (leaf-inputs step)
#   outputs/leaf_inputs/spectra_combined_per_plot.csv   per-plot reflectance spectra, one
#                                                        column per nm (leaf-inputs step)
#   code/7_figures/supp_figure_style.R                  shared style of Figs. S1-S6 and S8
#
# Outputs
#   outputs/figures/FigureS3/FigS3_combined.png              the finished figure, panels A-F
#   outputs/figures/FigureS3/FigS3A_reflectance_spectra.png  single panel A
#   outputs/figures/FigureS3/FigS3B_lcc_*.png
#   outputs/figures/FigureS3/FigS3C_par_reflectance_*.png
#   outputs/figures/FigureS3/FigS3D_par_transmittance_*.png
#   outputs/figures/FigureS3/FigS3E_nir_reflectance_*.png
#   outputs/figures/FigureS3/FigS3F_nir_transmittance_*.png
#   Each single panel B-F is written twice, as *_annotated.png with the plot numbers and as
#   *_not_annotated.png without them.
#   outputs/figures/FigureS3/FigS3_plot_numbers.csv          number of plots written on each
#                                                            panel, per combination and
#                                                            leaflet type
#   The PNG files are written with the ragg device (ragg::agg_png).

figS3 <- function() {
  MASTER_FP <- file.path(ROOT, "outputs", "leaf_inputs", "leaf_optical_per_plot.csv")
  SPEC_FP   <- file.path(ROOT, "outputs", "leaf_inputs", "spectra_combined_per_plot.csv")
  OUT       <- file.path(ROOT, "outputs", "figures", "FigureS3")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Per-plot leaf-optics table (530 plots), broad- and narrow-leaflet NILs only.
  master <- read_csv(MASTER_FP, show_col_types = FALSE) %>%
    filter(Leaf_type %in% c("Broad", "Narrow")) %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Broad", "Narrow")),
           Cell = cell_factor(Site, Spacing))

  # The spectra are keyed by Loc_ID. Attach the combination and leaflet type of each plot and
  # reshape the R_<nm> columns to long form.
  spec_wide <- read_csv(SPEC_FP, show_col_types = FALSE)
  spec_long <- spec_wide %>%
    left_join(master %>% select(Loc_ID, Cell, Leaf_type), by = "Loc_ID") %>%
    filter(!is.na(Leaf_type)) %>%
    select(Loc_ID, Cell, Leaf_type, starts_with("R_")) %>%
    pivot_longer(starts_with("R_"), names_to = "wl", values_to = "R") %>%
    mutate(wavelength = as.numeric(sub("R_", "", wl)))

  # Panel A. Per-plot spectra in one facet per combination, with the plot numbers in the
  # facet header.
  n_spec <- spec_long %>% distinct(Loc_ID, Cell, Leaf_type) %>% count(Cell, Leaf_type)
  cell_labels <- n_spec %>%
    pivot_wider(names_from = Leaf_type, values_from = n, values_fill = 0) %>%
    mutate(facet_lbl = sprintf("%s\nB = %d, N = %d", Cell, Broad, Narrow))
  relabel <- setNames(cell_labels$facet_lbl, as.character(cell_labels$Cell))
  spec_long <- spec_long %>%
    mutate(Cell_lbl = factor(relabel[as.character(Cell)], levels = relabel[CELL_LEVELS]))

  spectra_panel <- function(legend = FALSE) {
    spec_long %>%
      filter(wavelength >= 400, wavelength <= 2500) %>%
      ggplot(aes(x = wavelength, y = R, group = Loc_ID, color = Leaf_type)) +
      geom_line(alpha = 0.18, linewidth = 0.15, show.legend = legend) +
      scale_color_manual(values = LEAF_LINE, name = LEAF_NAME) +
      scale_x_continuous(breaks = c(600, 1400, 2200)) +
      facet_wrap(~ Cell_lbl, nrow = 1) +
      labs(x = ttl("Wavelength", "(nm)"), y = NULL) +
      supp_theme +
      theme(strip.text = element_text(lineheight = 0.95)) +
      guides(color = guide_legend(override.aes = list(alpha = 1, linewidth = 0.8)))
  }
  SPECTRA_TITLE <- list("Leaf reflectance", quote(bold("R") * plain("(λ)")))

  # Panel B. LCC for plots with a SPAD reading from the July A-Ci leaves (cascade_jul) or the
  # August survey (baseline_aug). Plots flagged "missing" are left out. Panels C-F. Band
  # reflectance and transmittance for plots whose PROSPECT-D run was anchored to the plot's
  # own SPAD or LMA (leaf_optical_source == "measured"). Plots with combination-mean optics
  # are left out.
  lcc_dat <- master %>%
    filter(SPAD_source %in% c("baseline_aug", "cascade_jul"),
           is.finite(LCC_ugcm2), LCC_ugcm2 > 0) %>%
    as.data.frame()
  bands_dat <- master %>% filter(leaf_optical_source == "measured") %>% as.data.frame()

  # Console summary of the plot counts and group means.
  cat("\n=== Plots in the leaf-optics table and source flags ===\n")
  cat(sprintf("  rows in the leaf-optics table (Broad/Narrow only): %d\n", nrow(master)))
  cat(sprintf("  rows in the per-plot spectra: %d\n", nrow(spec_wide)))
  cat("\nleaf_optical_source distribution\n")
  print(table(master$leaf_optical_source, useNA = "ifany"))
  cat("\nSPAD_source distribution\n")
  print(table(master$SPAD_source, useNA = "ifany"))

  cat("\n=== Plots with spectra per combination (panel A) ===\n")
  print(as.data.frame(n_spec))

  cat("\n=== Plots and mean LCC per combination (panel B) ===\n")
  print(as.data.frame(lcc_dat %>% group_by(Cell, Leaf_type) %>%
                        summarize(n = n(),
                                  LCC_mean = round(mean(LCC_ugcm2), 2),
                                  LCC_sd   = round(sd(LCC_ugcm2),   2),
                                  .groups = "drop")))

  cat("\n=== Plots and mean band optics per combination (panels C-F) ===\n")
  print(as.data.frame(bands_dat %>% group_by(Cell, Leaf_type) %>%
                        summarize(n = n(),
                                  R_PAR = round(mean(R_PAR_leaf), 4),
                                  T_PAR = round(mean(T_PAR_leaf), 4),
                                  R_NIR = round(mean(R_NIR_leaf), 4),
                                  T_NIR = round(mean(T_NIR_leaf), 4),
                                  .groups = "drop")))

  # Data, column, file name and two-line y title of panels B-F.
  BOXES <- list(
    B = list(data = lcc_dat,   col = "LCC_ugcm2",  file = "FigS3B_lcc",
             title = list("LCC", U$ug_cm2)),
    C = list(data = bands_dat, col = "R_PAR_leaf", file = "FigS3C_par_reflectance",
             title = list("PAR", "reflectance")),
    D = list(data = bands_dat, col = "T_PAR_leaf", file = "FigS3D_par_transmittance",
             title = list("PAR", "transmittance")),
    E = list(data = bands_dat, col = "R_NIR_leaf", file = "FigS3E_nir_reflectance",
             title = list("NIR", "reflectance")),
    F = list(data = bands_dat, col = "T_NIR_leaf", file = "FigS3F_nir_transmittance",
             title = list("NIR", "transmittance")))

  # Finished figure. The facet headers of panel A serve all rows, and the x labels are on the
  # bottom row.
  box_plots <- lapply(names(BOXES), function(k) {
    box_panel(BOXES[[k]]$data, BOXES[[k]]$col, xlabels = k == "F")
  })
  names(box_plots) <- names(BOXES)
  panels <- c(list(panel_cells("A", SPECTRA_TITLE, spectra_panel(), lift = 0.33)),
              lapply(names(BOXES), function(k) panel_cells(k, BOXES[[k]]$title, box_plots[[k]])))
  save_png(assemble(panels), file.path(OUT, "FigS3_combined.png"), height = 8.0)

  # Single panels.
  save_panel(function(notes) single_panel(SPECTRA_TITLE, spectra_panel(legend = TRUE)),
             file.path(OUT, "FigS3A_reflectance_spectra"), height = 2.2, has_notes = FALSE)
  for (k in names(BOXES)) local({
    pn <- BOXES[[k]]
    save_panel(function(notes) single_panel(pn$title, box_panel(pn$data, pn$col, strips = TRUE,
                                                                xlabels = TRUE, notes = notes)),
               file.path(OUT, pn$file), height = 1.9)
  })

  # Number of plots written on each panel.
  plot_numbers <- rbind(
    cbind(panel = "A", as.data.frame(n_spec)),
    do.call(rbind, lapply(names(BOXES), function(k) {
      cbind(panel = k, attr(box_plots[[k]], "plot_numbers"))
    })))
  write.csv(plot_numbers, file.path(OUT, "FigS3_plot_numbers.csv"), row.names = FALSE)

  cat(sprintf("\nWrote the finished figure, the single panels and FigS3_plot_numbers.csv to %s\n",
              OUT))
}

# ==================================================================================================
# Section figS4
# Fig S4: Daily weather at SoyFACE and the Energy Farm, 1 May to 31 October 2024
# ==================================================================================================
#
# Purpose
#   Draws Fig. S4 at its final size from the station records of both sites, with the two
#   sites overlaid in each panel. Records are read at their native interval (hourly at
#   SoyFACE, 10-min means at the Energy Farm) and aggregated by day. (A) Mean air
#   temperature. (B) Mean vapor pressure deficit, computed at the recording interval from
#   station vapor pressure and air temperature (Tetens equation) and then averaged by day.
#   (C) Mean incoming solar flux density. (D) Mean relative humidity. (E) Mean wind speed.
#   (F) Total rainfall. Triangles below the data mark the dates with leaf area index
#   measurements (SoyFACE upper row, Energy Farm lower row). The finished figure arranges
#   the panels in three rows of two, and each panel is also written on its own canvas.
#   Days are calendar days of the station clock, midnight to midnight, and every record of
#   a day is used, the one stamped 00:00 included. Records that appear twice in a station
#   file are used once. The Energy Farm file holds each record of 1 May to 18 July twice,
#   which matters only for the rainfall totals. Energy Farm rainfall is taken from the
#   tipping-bucket count in hundredths of an inch (Rain_hundreth_Tot x 0.254 mm). The
#   station's millimeter channel (Rain_mm_Tot) stops following the bucket count in July and
#   is not used. Monthly totals of both channels and of SoyFACE are written to a table.
#
# Inputs
#   data/field/SF/weather_hourly_2024.csv     SoyFACE station, hourly (Campbell Scientific
#                                             TOA5, four header rows)
#   data/field/EF/weather_10min_2024.txt      Energy Farm station, 10-min means (TOA5,
#                                             tab-separated)
#   data/field/SF/LAI_per_plot_per_DAP.csv    SoyFACE per-plot LAI, read for the dates
#   data/field/EF/LAI_per_plot_per_DAP.csv    Energy Farm per-plot LAI, read for the dates
#   code/7_figures/supp_figure_style.R        shared style of Figs. S1-S6 and S8
#
# Outputs
#   outputs/figures/FigureS4/FigS4_combined.png                 the finished figure, panels A-F
#   outputs/figures/FigureS4/FigS4A_air_temperature.png
#   outputs/figures/FigureS4/FigS4B_vapor_pressure_deficit.png
#   outputs/figures/FigureS4/FigS4C_solar_flux_density.png
#   outputs/figures/FigureS4/FigS4D_relative_humidity.png
#   outputs/figures/FigureS4/FigS4E_wind_speed.png
#   outputs/figures/FigureS4/FigS4F_rainfall.png
#   outputs/figures/FigureS4/FigS4_daily_weather.csv            the daily values drawn, one row
#                                                               per site and day
#   outputs/figures/FigureS4/FigS4_rainfall_monthly.csv         monthly rainfall of the two
#                                                               Energy Farm channels and of
#                                                               SoyFACE
#   The PNG files are written with the ragg device (ragg::agg_png).

figS4 <- function() {
  SF_FP  <- file.path(ROOT, "data", "field", "SF", "weather_hourly_2024.csv")
  EF_FP  <- file.path(ROOT, "data", "field", "EF", "weather_10min_2024.txt")
  SF_LAI <- file.path(ROOT, "data", "field", "SF", "LAI_per_plot_per_DAP.csv")
  EF_LAI <- file.path(ROOT, "data", "field", "EF", "LAI_per_plot_per_DAP.csv")
  OUT    <- file.path(ROOT, "outputs", "figures", "FigureS4")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  WIN_START <- as.Date("2024-05-01")
  WIN_END   <- as.Date("2024-10-31")
  MM_PER_HUNDREDTH_INCH <- 0.254
  STATION_TZ <- "America/Chicago"

  # Readers for the Campbell Scientific TOA5 files. Row 1 holds logger metadata, row 2 the
  # variable names, row 3 the units and row 4 the aggregation type. Data start on row 5.
  read_toa5_csv <- function(fp) {
    nm <- scan(fp, what = "character", sep = ",", skip = 1, nlines = 1, quote = '"', quiet = TRUE)
    # All columns are read as text, so that a midnight time stamp keeps its "00:00:00".
    d  <- read_csv(fp, skip = 4, col_names = FALSE, col_types = cols(.default = col_character()),
                   progress = FALSE, name_repair = "minimal")
    names(d) <- nm
    d
  }
  read_toa5_tsv <- function(fp) {
    nm <- scan(fp, what = "character", sep = "\t", skip = 1, nlines = 1, quiet = TRUE)
    nm <- gsub("[[:space:]]+", "_", trimws(nm))
    nm <- gsub("[()]", "", nm)
    d  <- read_tsv(fp, skip = 4, col_names = FALSE, show_col_types = FALSE, progress = FALSE,
                   name_repair = "minimal")
    # Keep only the first length(nm) columns. Trailing tabs in the source produce empty
    # unnamed columns.
    d <- d[, seq_len(min(ncol(d), length(nm))), drop = FALSE]
    names(d) <- nm[seq_len(ncol(d))]
    d
  }

  # Saturation vapor pressure (Tetens equation), kPa, for air temperature in degrees C.
  es_kPa <- function(T_C) 0.6108 * exp(17.27 * T_C / (T_C + 237.3))

  # Read each station at its native interval, keep the 1 May to 31 October window and compute
  # VPD = es(T) - e, floored at zero (station vapor pressure in hPa, divided by 10 for kPa).
  # A record belongs to the calendar day of its time stamp (midnight to midnight on the
  # station clock). Four hourly SoyFACE records appear twice and are used once.
  cat("Reading the SoyFACE hourly records ...\n")
  sf <- read_toa5_csv(SF_FP) %>%
    mutate(time   = ymd_hms(TIMESTAMP, tz = STATION_TZ, quiet = TRUE),
           air_T  = as.numeric(AirT_C_Avg),
           VP_hPa = as.numeric(VP_hPa_Avg),
           RH_pct = as.numeric(RH),
           wind   = as.numeric(WS_ms_S_WVT),
           solar  = as.numeric(SlrFD_kW_Avg),
           rain   = as.numeric(Rain_mm_Tot)) %>%
    mutate(date = as.Date(time, tz = STATION_TZ)) %>%
    filter(!is.na(time), date >= WIN_START, date <= WIN_END) %>%
    distinct(TIMESTAMP, RECORD, .keep_all = TRUE) %>%
    mutate(VPD_kPa = pmax(0, es_kPa(air_T) - VP_hPa / 10), Site = "SoyFACE")

  # Energy Farm columns used are AirTemp_C_Avg, VP_mbar_Avg (mbar = hPa), RH_Avg, WS_ms_WVc1,
  # SlrFD_kW_Avg and Rain_hundreth_Tot. Rain_mm_Tot is read only for the monthly table.
  cat("Reading the Energy Farm 10-min records ...\n")
  ef_all <- read_toa5_tsv(EF_FP) %>%
    mutate(time   = mdy_hm(TIMESTAMP, tz = STATION_TZ, quiet = TRUE),
           air_T  = as.numeric(AirTemp_C_Avg),
           VP_hPa = as.numeric(VP_mbar_Avg),
           RH_pct = as.numeric(RH_Avg),
           wind   = as.numeric(WS_ms_WVc1),
           solar  = as.numeric(SlrFD_kW_Avg),
           rain_mm_channel = as.numeric(Rain_mm_Tot),
           rain   = as.numeric(Rain_hundreth_Tot) * MM_PER_HUNDREDTH_INCH) %>%
    mutate(date = as.Date(time, tz = STATION_TZ)) %>%
    filter(!is.na(time), date >= WIN_START, date <= WIN_END) %>%
    mutate(VPD_kPa = pmax(0, es_kPa(air_T) - VP_hPa / 10), Site = "Energy Farm")

  # Drop the repeated Energy Farm records. Every repeat must carry the same values as the
  # record it repeats.
  rep_check <- ef_all %>% group_by(TIMESTAMP) %>%
    summarize(n = n(),
              same = n_distinct(RECORD) == 1 && n_distinct(air_T) <= 1 && n_distinct(rain) <= 1,
              .groups = "drop")
  stopifnot(all(rep_check$same), max(rep_check$n) <= 2)
  ef <- ef_all %>% distinct(TIMESTAMP, .keep_all = TRUE)
  cat(sprintf("  SoyFACE records in the window: %d\n", nrow(sf)))
  cat(sprintf("  Energy Farm records in the window: %d, of which %d repeats dropped (%s to %s)\n",
              nrow(ef_all), nrow(ef_all) - nrow(ef),
              min(ef_all$date[duplicated(ef_all$TIMESTAMP)]),
              max(ef_all$date[duplicated(ef_all$TIMESTAMP)])))

  # Monthly rainfall of the two Energy Farm channels and of SoyFACE.
  rain_monthly <- ef %>% mutate(month = month(date)) %>% group_by(month) %>%
    summarize(EF_bucket_count_mm = sum(rain, na.rm = TRUE),
              EF_mm_channel_not_used = sum(rain_mm_channel, na.rm = TRUE), .groups = "drop") %>%
    left_join(sf %>% mutate(month = month(date)) %>% group_by(month) %>%
                summarize(SF_mm = sum(rain, na.rm = TRUE), .groups = "drop"),
              by = "month")
  cat("\nMonthly rainfall (mm)\n")
  print(as.data.frame(rain_monthly), digits = 4)
  cat(sprintf("Rainfall, 1 May to 31 October: Energy Farm %.1f mm, SoyFACE %.1f mm\n",
              sum(rain_monthly$EF_bucket_count_mm), sum(rain_monthly$SF_mm)))
  write.csv(rain_monthly, file.path(OUT, "FigS4_rainfall_monthly.csv"), row.names = FALSE)

  # Daily means (daily total for rainfall).
  agg_daily <- function(d) {
    d %>% group_by(Site, date) %>%
      summarize(air_T_mean   = mean(air_T,   na.rm = TRUE),
                VPD_kPa_mean = mean(VPD_kPa, na.rm = TRUE),
                RH_pct_mean  = mean(RH_pct,  na.rm = TRUE),
                wind_mean    = mean(wind,    na.rm = TRUE),
                solar_mean   = mean(solar,   na.rm = TRUE),
                rain_total   = sum(rain,     na.rm = TRUE),
                .groups = "drop")
  }
  daily <- bind_rows(agg_daily(sf), agg_daily(ef)) %>%
    mutate(Site = factor(Site, levels = c("SoyFACE", "Energy Farm")))
  # A day with only missing records gives a non-finite mean. Set it to NA so that the line
  # shows a gap.
  for (cc in c("air_T_mean", "VPD_kPa_mean", "RH_pct_mean", "wind_mean", "solar_mean",
               "rain_total")) {
    daily[[cc]][!is.finite(daily[[cc]])] <- NA_real_
  }
  write.csv(daily, file.path(OUT, "FigS4_daily_weather.csv"), row.names = FALSE)

  cat("\n=== Daily coverage (1 May to 31 October 2024) ===\n")
  print(as.data.frame(daily %>% group_by(Site) %>%
                        summarize(n_days = n(), date_min = min(date), date_max = max(date),
                                  .groups = "drop")))

  # LAI measurement dates. The LAI files have one row per plot and date, so keep the unique
  # dates of each site.
  lai_dates <- bind_rows(
    read_csv(SF_LAI, show_col_types = FALSE) %>% mutate(date = as.Date(date)) %>%
      distinct(date) %>% mutate(Site = "SoyFACE"),
    read_csv(EF_LAI, show_col_types = FALSE) %>% mutate(date = as.Date(date)) %>%
      distinct(date) %>% mutate(Site = "Energy Farm")) %>%
    filter(date >= WIN_START, date <= WIN_END) %>%
    mutate(Site = factor(Site, levels = c("SoyFACE", "Energy Farm")))
  cat("\nLAI measurement dates marked by triangles\n")
  print(as.data.frame(lai_dates %>% group_by(Site) %>%
                        summarize(n = n(), first = min(date), last = max(date), .groups = "drop")))

  month_breaks <- seq(as.Date("2024-05-01"), as.Date("2024-11-01"), by = "1 month")

  # One weather variable against date, as a line (or bars for rainfall). The LAI triangles sit
  # in a two-row band below the data, at 5% (SoyFACE) and 10% (Energy Farm) of the data range
  # under its minimum, and the y axis starts 13% of the range below the minimum.
  weather_panel <- function(y_col, geom = c("line", "bar"), xtitle = FALSE, legend = TRUE) {
    geom  <- match.arg(geom)
    y_lo  <- min(daily[[y_col]], na.rm = TRUE)
    y_hi  <- max(daily[[y_col]], na.rm = TRUE)
    y_rng <- y_hi - y_lo
    tri_data <- lai_dates %>%
      mutate(tri_y = ifelse(Site == "SoyFACE", y_lo - 0.05 * y_rng, y_lo - 0.10 * y_rng))
    p <- ggplot(daily, aes(x = date, y = .data[[y_col]], color = Site, fill = Site, group = Site))
    p <- if (geom == "line") {
      p + geom_line(linewidth = 0.4, alpha = 0.95, show.legend = legend)
    } else {
      p + geom_col(position = position_identity(), alpha = 0.65, width = 0.9, color = NA,
                   show.legend = FALSE)
    }
    p <- p +
      geom_point(data = tri_data, aes(x = date, y = tri_y, color = Site, fill = Site),
                 shape = 24, size = 1.3, stroke = 0.3, inherit.aes = FALSE, show.legend = legend) +
      scale_color_manual(values = SITE_COL, name = "Location") +
      scale_fill_manual(values = SITE_COL, name = "Location") +
      scale_x_date(breaks = month_breaks, date_labels = "%b",
                   limits = c(WIN_START - 1, WIN_END + 1), expand = c(0.005, 0)) +
      coord_cartesian(ylim = c(y_lo - 0.13 * y_rng, y_hi), expand = TRUE) +
      labs(x = ttl("Month", "(2024)"), y = NULL) +
      supp_theme + theme(legend.key.width = unit(0.3, "in"), plot.margin = margin(3, 8, 3, 0))
    if (!xtitle) p <- p + no_xtitle
    p
  }

  # Column of the daily table, geometry, file name and two-line y title of each panel.
  PANELS <- list(
    A = list(col = "air_T_mean",   geom = "line", file = "FigS4A_air_temperature",
             title = list("Daily mean air", ttl("temperature", "(°C)"))),
    B = list(col = "VPD_kPa_mean", geom = "line", file = "FigS4B_vapor_pressure_deficit",
             title = list("Daily mean vapor", ttl("pressure deficit", "(kPa)"))),
    C = list(col = "solar_mean",   geom = "line", file = "FigS4C_solar_flux_density",
             title = list("Daily mean solar", ttl("flux density", U$kw_m2))),
    D = list(col = "RH_pct_mean",  geom = "line", file = "FigS4D_relative_humidity",
             title = list("Daily mean relative", ttl("humidity", "(%)"))),
    E = list(col = "wind_mean",    geom = "line", file = "FigS4E_wind_speed",
             title = list("Daily mean wind", ttl("speed", U$m_s))),
    F = list(col = "rain_total",   geom = "bar",  file = "FigS4F_rainfall",
             title = list("Daily total", ttl("rainfall", "(mm)"))))

  # Finished figure with three rows of two panels, one legend and the x title on the bottom
  # row. The rainfall panel takes no legend of its own.
  panels <- lapply(names(PANELS), function(k) {
    pn <- PANELS[[k]]
    panel_cells(k, pn$title, weather_panel(pn$col, pn$geom, xtitle = k %in% c("E", "F"),
                                           legend = pn$geom == "line"))
  })
  save_png(assemble(panels, ncol = 2), file.path(OUT, "FigS4_combined.png"), height = 6.2)

  # Single panels.
  for (k in names(PANELS)) local({
    pn <- PANELS[[k]]
    save_panel(function(notes) single_panel(pn$title, weather_panel(pn$col, pn$geom, xtitle = TRUE,
                                                                    legend = TRUE)),
               file.path(OUT, pn$file), height = 2.4, width = 3.6, has_notes = FALSE)
  })

  cat(sprintf("\nWrote the finished figure, the single panels and the two tables to %s\n", OUT))
}

# ==================================================================================================
# Section figS5
# Fig S5: Alternative fits of the narrow-minus-broad canopy A difference against mean LAI
# ==================================================================================================
#
# Purpose
#   Draws Fig. S5 at its final size and writes the fit statistics behind it. Helios canopy A
#   and LAI are averaged by site, row spacing, date and leaflet type, and the
#   narrow-minus-broad difference (Delta A) is paired with the mean LAI of the narrow and
#   broad plots, giving 40 site x row spacing x date points. Four forms are fitted to the
#   same points, with L = mean LAI.
#     Quadratic                       Delta A = b0 + b1 L + b2 L^2
#     Exponential rise to a plateau   Delta A = c + a (1 - exp(-k L))
#     Linear                          Delta A = a + b L
#     Logistic                        Delta A = a / (1 + exp(-k (L - L_half)))
#   The quadratic and linear forms are fitted by ordinary least squares and the other two by
#   nonlinear least squares (nls) from a grid of starting values.
#   Each panel gives R2, RMSE, AIC and the difference from the lowest AIC, and the panels are
#   ordered by AIC. The ranking table also gives the LAI at which each fitted curve crosses
#   Delta A = 0 (the Delta AIC values and crossing LAI quoted in the Results). The finished
#   figure is 5.22 in wide, narrower than the other supplementary figures, so that each
#   square panel is 1.33 in on a side with the text at the shared sizes.
#
# Inputs
#   outputs/helios/helios_canopy_summary_SF.csv   Helios canopy summary, one row per plot-date,
#                                                 SoyFACE (simulation step)
#   outputs/helios/helios_canopy_summary_EF.csv   as above, Energy Farm
#   code/7_figures/supp_figure_style.R            shared style of Figs. S1-S6 and S8
#
# Outputs
#   outputs/figures/FigureS5/FigS5_combined.png             the finished figure, 2 x 2 panels,
#                                                           lowest AIC first
#   outputs/figures/FigureS5/FigS5A_quadratic_*.png
#   outputs/figures/FigureS5/FigS5B_exponential_rise_*.png
#   outputs/figures/FigureS5/FigS5C_linear_*.png
#   outputs/figures/FigureS5/FigS5D_logistic_*.png
#   Each single panel is written twice, as *_annotated.png with the form name and fit
#   statistics and as *_not_annotated.png without them.
#   outputs/figures/FigureS5/FigS5_model_ranking.csv        R2, RMSE, AIC, Delta AIC and
#                                                           crossing LAI of each form
#   outputs/figures/FigureS5/FigS5_model_coefficients.csv   parameter estimates and SEs
#   The PNG files are written with the ragg device (ragg::agg_png).

figS5 <- function() {
  FP_SF <- file.path(ROOT, "outputs", "helios", "helios_canopy_summary_SF.csv")
  FP_EF <- file.path(ROOT, "outputs", "helios", "helios_canopy_summary_EF.csv")
  OUT   <- file.path(ROOT, "outputs", "figures", "FigureS5")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  FIT_COL <- "#D55E00"
  PT_COL  <- "gray35"

  # Read the Helios summaries of both sites and average canopy A and LAI by site, row
  # spacing, date and leaflet type.
  raw <- bind_rows(
    read_csv(FP_SF, show_col_types = FALSE),
    read_csv(FP_EF, show_col_types = FALSE)
  )
  cat(sprintf("Helios summary loaded: %d rows (plot-dates)\n", nrow(raw)))

  cell_dap <- raw %>%
    filter(Leaf_type %in% c("Broad", "Narrow")) %>%
    group_by(Site, Spacing, DAP, Leaf_type) %>%
    summarize(A_mean   = mean(A_umol_m2_s, na.rm = TRUE),
              LAI_mean = mean(LAI_used,    na.rm = TRUE),
              .groups  = "drop")

  # One row per site x row spacing x date with Delta A (narrow minus broad) and the mean of
  # the narrow and broad LAI.
  dw <- cell_dap %>%
    pivot_wider(names_from = Leaf_type,
                values_from = c(A_mean, LAI_mean)) %>%
    mutate(deltaA   = A_mean_Narrow - A_mean_Broad,
           LAI_mean = (LAI_mean_Narrow + LAI_mean_Broad) / 2) %>%
    filter(!is.na(deltaA), !is.na(LAI_mean))

  cat(sprintf("n = %d (Site x Spacing) x DAP rows\n", nrow(dw)))
  cat(sprintf("ΔA range: [%.3f, %.3f] μmol m⁻² s⁻¹\n",
              min(dw$deltaA), max(dw$deltaA)))
  cat(sprintf("LAI_mean range: [%.3f, %.3f] m² m⁻²\n",
              min(dw$LAI_mean), max(dw$LAI_mean)))

  # R2 = 1 - RSS/TSS, RMSE = sqrt(mean of squared residuals), and AIC of the fit.
  fit_metrics <- function(fit, y_obs) {
    r <- residuals(fit); rss <- sum(r^2); tss <- sum((y_obs - mean(y_obs))^2)
    list(R2 = 1 - rss/tss, RMSE = sqrt(mean(r^2)), AIC = AIC(fit))
  }

  # Nonlinear fit from a grid of starting values. The converged fit with the lowest AIC is
  # kept, and the section stops if no start converges.
  fit_nls_best <- function(formula, starts) {
    best <- NULL
    for (s in starts) {
      f <- tryCatch(nls(formula, data = dw, start = s,
                        control = nls.control(maxiter = 1000)),
                    error = function(e) NULL)
      if (!is.null(f) && isTRUE(f$convInfo$isConv) &&
          (is.null(best) || AIC(f) < AIC(best))) best <- f
    }
    if (is.null(best)) stop("nls did not converge from any start: ",
                            paste(deparse(formula), collapse = ""))
    best
  }
  grid_starts <- function(...) {
    g <- expand.grid(..., KEEP.OUT.ATTRS = FALSE)
    lapply(seq_len(nrow(g)), function(i) as.list(g[i, , drop = FALSE]))
  }

  # Fit the four forms.
  fits <- list()
  fits$linear    <- lm(deltaA ~ LAI_mean, data = dw)
  fits$quadratic <- lm(deltaA ~ LAI_mean + I(LAI_mean^2), data = dw)
  fits$logistic  <- fit_nls_best(
    deltaA ~ a / (1 + exp(-k * (LAI_mean - L_half))),
    grid_starts(a = c(3, 5), L_half = c(3, 4, 6), k = c(0.5, 1, 2)))
  fits$exp_rise  <- fit_nls_best(
    deltaA ~ c0 + a * (1 - exp(-k * LAI_mean)),
    grid_starts(c0 = c(-2, -1, 0), a = c(3, 5, 8), k = c(0.05, 0.1, 0.2, 0.3, 0.5)))

  mtbl <- bind_rows(lapply(names(fits), function(nm) {
    m <- fit_metrics(fits[[nm]], dw$deltaA)
    data.frame(model = nm, R2 = m$R2, RMSE = m$RMSE, AIC = m$AIC)
  })) %>% mutate(dAIC = AIC - min(AIC))

  # LAI at which each fitted curve crosses Delta A = 0. For the quadratic this is the smallest
  # positive root within the observed LAI range. The logistic form approaches zero
  # asymptotically and never crosses it.
  crossover_lai <- function(nm) {
    cf <- coef(fits[[nm]])
    if (nm == "linear") return(unname(-cf[1] / cf[2]))
    if (nm == "quadratic") {
      rt <- Re(polyroot(unname(cf)))
      rt <- rt[rt > 0 & rt <= max(dw$LAI_mean)]
      return(if (length(rt)) min(rt) else NA_real_)
    }
    if (nm == "exp_rise") {
      v <- 1 + cf["c0"] / cf["a"]
      return(if (v > 0 && v < 1) unname(-log(v) / cf["k"]) else NA_real_)
    }
    NA_real_
  }
  mtbl$crossover_LAI <- sapply(mtbl$model, crossover_lai)

  cat("\nModel ranking by AIC\n")
  print(mtbl %>% arrange(AIC) %>%
          mutate(across(c(R2, RMSE, AIC, dAIC, crossover_LAI), ~ round(.x, 3))))

  write_csv(mtbl %>% arrange(AIC),
            file.path(OUT, "FigS5_model_ranking.csv"))

  coef_tbl <- bind_rows(lapply(names(fits), function(nm) {
    s <- summary(fits[[nm]])$coefficients
    data.frame(model = nm, term = rownames(s),
               estimate = s[, 1], std_error = s[, 2], row.names = NULL)
  }))
  write_csv(coef_tbl, file.path(OUT, "FigS5_model_coefficients.csv"))

  # The panels follow the AIC ranking. The panel letters and file names below assume the
  # ranking quadratic, exponential rise, linear, logistic, and the section stops if the fits
  # rank differently.
  ranked <- mtbl %>% arrange(AIC)
  model_order <- ranked$model
  stopifnot(identical(model_order, c("quadratic", "exp_rise", "linear", "logistic")))
  FORM_NAME <- c(quadratic = "Quadratic", exp_rise = "Exponential rise\nto plateau",
                 linear = "Linear", logistic = "Logistic")
  FORM_FILE <- c(quadratic = "FigS5A_quadratic", exp_rise = "FigS5B_exponential_rise",
                 linear = "FigS5C_linear", logistic = "FigS5D_logistic")
  ranked$label <- sprintf("R² = %.3f\nRMSE = %.2f\nAIC = %.2f\nΔAIC = %.2f",
                          ranked$R2, ranked$RMSE, ranked$AIC, ranked$dAIC)

  # Fitted curves on a common LAI grid from 0 to 12.
  LAI_grid <- seq(0, 12, length.out = 400)
  predict_curve <- function(nm) {
    if (nm == "linear")         predict(fits$linear,    newdata = data.frame(LAI_mean = LAI_grid))
    else if (nm == "quadratic") predict(fits$quadratic, newdata = data.frame(LAI_mean = LAI_grid))
    else if (nm == "logistic")  {
      cf <- coef(fits$logistic); cf["a"] / (1 + exp(-cf["k"] * (LAI_grid - cf["L_half"]))) }
    else if (nm == "exp_rise") {
      cf <- coef(fits$exp_rise); cf["c0"] + cf["a"] * (1 - exp(-cf["k"] * LAI_grid)) }
  }

  # One panel per form with the shared points, the fitted curve, the form name and its fit
  # statistics.
  ax_x_max <- ceiling(max(dw$LAI_mean) + 1)
  ax_y_max <- ceiling(max(dw$deltaA) + 1)
  ax_y_min <- floor(min(dw$deltaA) - 0.5)
  fit_panel <- function(nm, notes = TRUE, xtitle = TRUE) {
    m  <- ranked[ranked$model == nm, ]
    cv <- data.frame(LAI = LAI_grid, deltaA = predict_curve(nm)) %>%
      filter(LAI >= 0, LAI <= ax_x_max)
    p <- ggplot(dw, aes(x = LAI_mean, y = deltaA)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.3) +
      geom_line(data = cv, aes(x = LAI, y = deltaA), color = FIT_COL, linewidth = 0.7) +
      geom_point(color = "black", fill = PT_COL, shape = 21, size = 1.3, stroke = 0.25,
                 alpha = 0.85) +
      scale_x_continuous(limits = c(0, ax_x_max), breaks = seq(0, 12, 2), expand = c(0.01, 0)) +
      scale_y_continuous(limits = c(ax_y_min, ax_y_max), breaks = seq(-4, 10, 2),
                         expand = c(0.01, 0)) +
      labs(x = ttl("Mean LAI", U$lai), y = NULL) +
      supp_theme + theme(aspect.ratio = 1, legend.position = "none")
    if (notes) p <- p +
      annotate("text", x = 0.35, y = ax_y_max - 0.3, hjust = 0, vjust = 1, size = SITE_MM,
               family = FONT, fontface = "bold", color = SITE_GRAY, lineheight = 0.95,
               label = FORM_NAME[[nm]]) +
      annotate("text", x = ax_x_max - 0.3, y = ax_y_min + 0.2, hjust = 1, vjust = 0,
               size = NOTE_MM, family = FONT, color = "black", lineheight = 1.0, label = m$label)
    if (!xtitle) p <- p + no_xtitle
    p
  }
  Y_TITLE <- list("Δ canopy A", U$flux_co2)

  # Finished figure with two rows of two panels. The canvas is narrower than the other
  # supplementary figures so that each square panel is 1.33 in on a side, with the text at
  # the shared sizes.
  panels <- lapply(seq_along(model_order), function(i) {
    panel_cells(LETTERS[i], Y_TITLE, fit_panel(model_order[i], xtitle = i > 2))
  })
  save_png(assemble(panels, ncol = 2, collect = FALSE), file.path(OUT, "FigS5_combined.png"),
           height = 3.82, width = 5.22)

  # Single panels, with the same 1.33 in panel.
  for (nm in model_order) local({
    nm <- nm
    save_panel(function(notes) single_panel(Y_TITLE, fit_panel(nm, notes = notes)),
               file.path(OUT, FORM_FILE[[nm]]), height = 2.07, width = 2.37)
  })

  cat(sprintf("\nWrote the finished figure, the single panels, %s and %s to %s\n",
              "FigS5_model_ranking.csv", "FigS5_model_coefficients.csv", OUT))
}

# ==================================================================================================
# Section figS6
# Fig S6: Post-closure fAPAR of broad- and narrow-leaflet NILs and its equivalence test
# ==================================================================================================
#
# Purpose
#   Draws Fig. S6 at its final size and writes the equivalence table behind it. Each plot's
#   Helios fAPAR is averaged over the dates after canopy closure (DAP >= 70). (A) Per-plot
#   means by leaflet type in each site x row spacing combination, as box plots with jittered
#   plots and the number of plots above each box. (B) Narrow-minus-broad difference in mean
#   fAPAR with its 95% Welch confidence interval and the +/-0.02 equivalence margin. The P
#   value of each combination is from two one-sided Welch t-tests (TOST), the larger of the
#   two one-sided P values against the -0.02 and +0.02 margins. The table holds the
#   differences and TOST P values quoted in the Results.
#
# Inputs
#   outputs/helios/helios_canopy_summary_SF.csv   Helios canopy summary, one row per plot-date,
#                                                 SoyFACE (simulation step)
#   outputs/helios/helios_canopy_summary_EF.csv   as above, Energy Farm
#   code/7_figures/supp_figure_style.R            shared style of Figs. S1-S6 and S8
#
# Outputs
#   outputs/figures/FigureS6/FigS6_combined.png                the finished figure, panel A
#                                                              above panel B
#   outputs/figures/FigureS6/FigS6A_fapar_distributions_*.png  single panel A
#   outputs/figures/FigureS6/FigS6B_tost_forest_*.png          single panel B
#   Each single panel is written twice, as *_annotated.png with the plot numbers (A) or the
#   P values (B) and as *_not_annotated.png without them.
#   outputs/figures/FigureS6/FigS6B_tost_table.csv   group sizes, means, Welch statistics and
#                                                    TOST P value per combination
#   The PNG files are written with the ragg device (ragg::agg_png).

figS6 <- function() {
  FP_SF <- file.path(ROOT, "outputs", "helios", "helios_canopy_summary_SF.csv")
  FP_EF <- file.path(ROOT, "outputs", "helios", "helios_canopy_summary_EF.csv")
  OUT   <- file.path(ROOT, "outputs", "figures", "FigureS6")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  EQ_MARGIN <- 0.02   # fAPAR equivalence margin (Methods)

  # Read the Helios summaries of both sites.
  raw <- bind_rows(
    read_csv(FP_SF, show_col_types = FALSE),
    read_csv(FP_EF, show_col_types = FALSE)
  )
  cat(sprintf("Helios summary loaded: %d rows (plot-dates)\n", nrow(raw)))

  # Per-plot mean fAPAR over the post-closure dates (DAP >= 70) of every broad- and
  # narrow-leaflet NIL plot.
  plot_lvl <- raw %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           DAP >= 70,
           is.finite(frac_PAR_absorbed)) %>%
    group_by(Site, Spacing, Leaf_type, Loc_ID) %>%
    summarize(fAPAR = mean(frac_PAR_absorbed, na.rm = TRUE),
              n_dap = n(),
              .groups = "drop") %>%
    mutate(Cell = cell_factor(Site, Spacing),
           Leaf_type = factor(Leaf_type, levels = c("Broad", "Narrow"))) %>%
    as.data.frame()

  cat("\nPlots per combination and leaflet type (DAP >= 70):\n")
  print(plot_lvl %>% count(Cell, Leaf_type))

  # Equivalence test per combination. The narrow-minus-broad difference has the Welch standard
  # error and Welch-Satterthwaite degrees of freedom. Each one-sided test asks whether the
  # difference lies inside one margin, and the TOST P value is the larger of the two. The
  # column p_lab is the label of the table and p_fig the label drawn in panel B.
  tost <- plot_lvl %>%
    group_by(Cell) %>%
    summarize(
      n_B    = sum(Leaf_type == "Broad"),
      n_N    = sum(Leaf_type == "Narrow"),
      mean_B = mean(fAPAR[Leaf_type == "Broad"]),
      mean_N = mean(fAPAR[Leaf_type == "Narrow"]),
      var_B  = var(fAPAR[Leaf_type == "Broad"]),
      var_N  = var(fAPAR[Leaf_type == "Narrow"]),
      .groups = "drop"
    ) %>%
    mutate(
      mean_diff = mean_N - mean_B,
      se        = sqrt(var_B / n_B + var_N / n_N),
      df        = (var_B / n_B + var_N / n_N)^2 /
                    ((var_B / n_B)^2 / (n_B - 1) +
                     (var_N / n_N)^2 / (n_N - 1)),
      ci_lo     = mean_diff - qt(0.975, df) * se,
      ci_hi     = mean_diff + qt(0.975, df) * se,
      t_lower   = (mean_diff - (-EQ_MARGIN)) / se,
      t_upper   = (mean_diff - ( EQ_MARGIN)) / se,
      p_lower   = pt(t_lower, df, lower.tail = FALSE),  # alternative: difference > -margin
      p_upper   = pt(t_upper, df, lower.tail = TRUE),   # alternative: difference < +margin
      p_tost    = pmax(p_lower, p_upper),
      equivalent_05 = p_tost < 0.05,
      p_lab     = ifelse(p_tost < 0.001, "p < 0.001",
                         sprintf("p = %.3f", p_tost)),
      p_fig     = ifelse(p_tost < 0.001, "P < 0.001",
                         sprintf("P = %.3f", p_tost))
    )

  cat("\nTOST results\n")
  print(as.data.frame(tost %>%
                        select(Cell, n_B, n_N, mean_diff, ci_lo, ci_hi, p_tost, equivalent_05)),
        digits = 4)

  # Equivalence table. The table names the combinations with a hyphen ("SoyFACE - 38 cm").
  write_csv(tost %>%
              mutate(Cell = sub(", ", " - ", as.character(Cell), fixed = TRUE)) %>%
              select(-p_fig),
            file.path(OUT, "FigS6B_tost_table.csv"))

  # Panel A. Per-plot post-closure fAPAR with the number of plots above each box.
  A_TITLE <- list("Per-plot fAPAR", pl("(post-closure mean)"))
  box_A <- function(notes = TRUE) {
    box_panel(plot_lvl, "fAPAR", strips = TRUE, xlabels = TRUE, notes = notes) +
      theme(aspect.ratio = 1)
  }

  # Panel B. Forest plot of the differences with the equivalence band. The caption is the
  # second line of the x title, in regular weight and centered under the panel.
  forest_B <- function(notes = TRUE) {
    p <- ggplot(tost, aes(x = mean_diff, y = Cell)) +
      annotate("rect", xmin = -EQ_MARGIN, xmax = EQ_MARGIN, ymin = -Inf, ymax = Inf,
               fill = "gray85", alpha = 0.55) +
      geom_vline(xintercept = c(-EQ_MARGIN, EQ_MARGIN), linetype = "dashed", color = "gray40",
                 linewidth = 0.35) +
      geom_vline(xintercept = 0, linetype = "solid", color = "gray60", linewidth = 0.3) +
      geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.18, linewidth = 0.45,
                    color = "black", orientation = "y") +
      geom_point(shape = 21, size = 1.8, fill = "black", color = "black") +
      scale_x_continuous(limits = c(-0.04, 0.045), breaks = c(-0.04, -0.02, 0, 0.02, 0.04)) +
      labs(x = ttl("Narrow − Broad fAPAR"), caption = "(mean difference, 95% CI)", y = NULL) +
      supp_theme +
      theme(panel.grid.major.y = element_blank(),
            plot.caption = element_text(size = PT_TITLE, face = "plain", color = "black",
                                        hjust = 0.5, margin = margin(t = 1.5)))
    if (notes) p <- p + geom_text(aes(x = EQ_MARGIN + 0.004, y = Cell, label = p_fig), hjust = 0,
                                  size = NOTE_MM, family = FONT, color = "black")
    p
  }

  # Finished figure, with panel A across the width and the narrower panel B below it. The left
  # spacer of the lower row places panel B, with its row labels, midway under panel A.
  B_PANEL_W <- 2.0    # width of the panel B plotting area, in
  B_LEFT    <- 1.52   # space to the left of the panel B letter, in
  row_A <- assemble(list(panel_cells("A", A_TITLE, box_A(), lift = STRIP_H)), collect = FALSE)
  row_B <- wrap_plots(plot_spacer(), tag_cell("B"), forest_B(), plot_spacer(), nrow = 1,
                      widths = unit(c(B_LEFT, TAG_W, B_PANEL_W, 1), c("in", "in", "in", "null")))
  save_rows(list(row_A, row_B), heights = c(2.3, 2.1), file.path(OUT, "FigS6_combined.png"))

  # Single panels.
  save_panel(function(notes) single_panel(A_TITLE, box_A(notes)),
             file.path(OUT, "FigS6A_fapar_distributions"), height = 2.5)
  save_panel(function(notes) forest_B(notes) + theme(plot.margin = margin(3, 4, 3, 4)),
             file.path(OUT, "FigS6B_tost_forest"), height = 2.2, width = 3.2)

  cat(sprintf("\nWrote the finished figure, the single panels and FigS6B_tost_table.csv to %s\n",
              OUT))
}

# ==================================================================================================
# Section figS8
# Fig S8: Checks on the Helios canopy simulations
# ==================================================================================================
#
# Purpose
#   Draws Fig. S8 at its final size and writes the statistics behind it. (A) Helios builds
#   each leaflet as a rectangle of the plot's leaflet length and average width, so the panel
#   checks how well length x width reproduces the measured leaflet area. For the 530
#   simulated plots, length x average width (left) and length x maximum width (right) are
#   plotted against the measured leaflet area with the 1:1 line, and each facet gives n and
#   the R2 and slope of the ordinary least-squares regression of the product on the measured
#   area. (B-C) Sub-leaf mesh test (Methods S1.10) at SoyFACE (B) and the Energy Farm (C).
#   For each leaflet type and row spacing, the class-mean canopy on its peak-LAI date was
#   simulated with each leaflet divided into 1, 4, 9, 25, 64, 144 or 225 elements (the
#   production runs used 9). Each panel shows Helios canopy A against the number of elements
#   per leaflet on a log scale, with the date and LAI of each canopy. The plotted values are
#   those of Table S12. (D) Test of whether the number of leaflets placed in a simulated
#   canopy biases canopy A. Each plot's Helios canopy A and leaflet count are averaged over
#   the dates after canopy closure (DAP >= 70), and canopy A is regressed on leaflet count by
#   ordinary least squares for each leaflet type in each site x row spacing combination.
#   Each facet gives n, the slope P and R2 per leaflet type, with 95% confidence bands. The
#   regression table holds the slopes, P values and R2 quoted in the Results.
#
# Inputs
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_SF.csv   per-plot leaflet length,
#                                                                  average and maximum width and
#                                                                  measured area, SoyFACE
#   data/simulation_inputs/canopy_inputs_per_plot_per_DAP_EF.csv   as above, Energy Farm
#   outputs/mesh_test/mesh_test_summary.csv       one row per mesh-test run
#                                                 (code/3_mesh_test/scripts/05_combine_outputs.sh)
#   outputs/helios/helios_canopy_summary_SF.csv   Helios canopy summary, one row per plot-date,
#                                                 SoyFACE (simulation step)
#   outputs/helios/helios_canopy_summary_EF.csv   as above, Energy Farm
#   code/7_figures/supp_figure_style.R            shared style of Figs. S1-S6 and S8
#
# Outputs
#   outputs/figures/FigureS8/FigS8_combined.png                    the finished figure, panels A-D
#   outputs/figures/FigureS8/FigS8A_leaflet_area_check_*.png
#   outputs/figures/FigureS8/FigS8B_mesh_test_SF_*.png
#   outputs/figures/FigureS8/FigS8C_mesh_test_EF_*.png
#   outputs/figures/FigureS8/FigS8D_canopy_a_vs_leaflet_count_*.png
#   Each single panel is written twice, as *_annotated.png with the values written inside the
#   plot and as *_not_annotated.png without them.
#   outputs/figures/FigureS8/FigS8A_statistics.txt        n, R2, slope and intercept of each
#                                                         regression of panel A
#   outputs/figures/FigureS8/FigS8BC_mesh_test_dates_and_lai.csv   date and LAI of each canopy
#                                                         of panels B-C
#   outputs/figures/FigureS8/FigS8D_regression_table.csv  n, slope, P and R2 per leaflet type
#                                                         and combination
#   The PNG files are written with the ragg device (ragg::agg_png).

figS8 <- function() {
  INP     <- file.path(ROOT, "data", "simulation_inputs")
  MESH_FP <- file.path(ROOT, "outputs", "mesh_test", "mesh_test_summary.csv")
  FP_SF   <- file.path(ROOT, "outputs", "helios", "helios_canopy_summary_SF.csv")
  FP_EF   <- file.path(ROOT, "outputs", "helios", "helios_canopy_summary_EF.csv")
  OUT     <- file.path(ROOT, "outputs", "figures", "FigureS8")
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

  # Row spacing is coded in inches in the data (15 = 38-cm rows, 30 = 76-cm rows) and shown by
  # line type in panels B-C.
  SPACING_LTY <- c("38 cm" = "solid", "76 cm" = "22")

  ## Panel A. Leaflet length x width against measured leaflet area ------------------------
  # One row per simulated plot (530 near-isogenic line plots). Dimensions in cm and cm2.
  rd <- function(site) {
    x <- read.csv(file.path(INP, sprintf("canopy_inputs_per_plot_per_DAP_%s.csv", site)))
    x <- x[x$Leaf_type %in% c("Broad", "Narrow"),
           c("Loc_ID", "Leaf_type", "length_m", "avwidth_m", "mxwidth_m", "area_m2")]
    x[!duplicated(x$Loc_ID), ]
  }
  dA <- rbind(rd("SF"), rd("EF"))
  stopifnot(nrow(dA) == 530, !anyNA(dA[c("length_m", "avwidth_m", "mxwidth_m", "area_m2")]))
  dA$measured_cm2 <- dA$area_m2 * 1e4

  # Long table with one row per plot and width definition. WIDTH_LEVELS are the facet headers
  # and STAT_NAME the names of the two products in the statistics file.
  WIDTH_LEVELS <- c("Length × average width", "Length × maximum width")
  STAT_NAME    <- c("L × avwidth", "L × maxwidth")
  long <- rbind(
    data.frame(width = WIDTH_LEVELS[1], Leaf_type = dA$Leaf_type, measured_cm2 = dA$measured_cm2,
               computed_cm2 = dA$length_m * dA$avwidth_m * 1e4),
    data.frame(width = WIDTH_LEVELS[2], Leaf_type = dA$Leaf_type, measured_cm2 = dA$measured_cm2,
               computed_cm2 = dA$length_m * dA$mxwidth_m * 1e4))
  long$width     <- factor(long$width, levels = WIDTH_LEVELS)
  long$Leaf_type <- factor(long$Leaf_type, levels = c("Broad", "Narrow"))

  # Ordinary least-squares regression of the computed product on the measured area.
  fitsA <- do.call(rbind, lapply(split(long, long$width), function(s) {
    f <- lm(computed_cm2 ~ measured_cm2, data = s)
    data.frame(width = s$width[1], n = nrow(s), r2 = summary(f)$r.squared,
               slope = unname(coef(f)[2]), intercept = unname(coef(f)[1]))
  }))
  fitsA$label <- sprintf("n = %d\nR² = %.3f\nslope = %.3f", fitsA$n, fitsA$r2, fitsA$slope)

  # Statistics of the two regressions.
  out <- c("Fig S8A statistics: computed leaflet length x width against measured leaflet area",
           "Ordinary least-squares regression of the computed product on the measured area, 530 plots",
           "",
           sprintf("%-15s n = %d  R2 = %.4f  slope = %.4f  intercept = %.3f cm2",
                   STAT_NAME[as.integer(fitsA$width)], fitsA$n, fitsA$r2, fitsA$slope,
                   fitsA$intercept))
  writeLines(out, file.path(OUT, "FigS8A_statistics.txt"))
  cat(out, sep = "\n")

  panel_A <- function(notes = TRUE, legend = FALSE) {
    p <- ggplot(long, aes(measured_cm2, computed_cm2)) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray40",
                  linewidth = 0.35) +
      geom_point(aes(fill = Leaf_type, shape = Leaf_type), size = 1.2, stroke = 0.25,
                 color = "black", show.legend = legend) +
      facet_wrap(~ width, nrow = 1) +
      scale_fill_manual(values = LEAF_FILL, name = LEAF_NAME) +
      scale_shape_manual(values = LEAF_SHAPE, name = LEAF_NAME) +
      scale_x_continuous(limits = c(0, 150), breaks = seq(0, 150, 50)) +
      scale_y_continuous(limits = c(0, 150), breaks = seq(0, 150, 50)) +
      labs(x = ttl("Measured leaflet area", U$cm2), y = NULL) +
      supp_theme + theme(aspect.ratio = 1)
    if (notes) p <- p + geom_text(data = fitsA, aes(x = 5, y = 146, label = label), hjust = 0,
                                  vjust = 1, size = NOTE_MM, family = FONT, lineheight = 0.95,
                                  color = "black", inherit.aes = FALSE)
    p
  }
  A_TITLE <- list("Leaflet length ×", ttl("width", U$cm2))

  ## Panels B-C. Canopy A against the number of sub-leaf elements per leaflet ---------------
  m <- read.csv(MESH_FP)
  stopifnot(nrow(m) == 56)
  m$Leaf_type   <- factor(m$Leaf_type, levels = c("Broad", "Narrow"))
  m$Row_spacing <- factor(ifelse(m$Spacing == 15, "38 cm", "76 cm"), levels = c("38 cm", "76 cm"))
  # Both panels share one vertical scale so that the two sites can be compared. The extra
  # room at the top holds the site name and the dates and LAI of the canopies. The tick at 144
  # is left unlabeled because its label would touch that of 225.
  Y_LIM    <- range(m$A_umol_m2_s) + c(-1, 3)
  X_BREAKS <- c(1, 4, 9, 25, 64, 144, 225)
  X_LABELS <- c("1", "4", "9", "25", "64", "", "225")
  # Date and LAI of each class-mean canopy, one row per site, row spacing and leaflet type.
  mesh_key <- unique(m[order(m$Site, m$Spacing, m$Leaf_type),
                       c("Site", "Spacing", "Leaf_type", "DAP", "LAI_used")])
  write.csv(mesh_key, file.path(OUT, "FigS8BC_mesh_test_dates_and_lai.csv"), row.names = FALSE)

  panel_mesh <- function(site, notes = TRUE, legend = FALSE) {
    s   <- m[m$Site == site, ]
    key <- mesh_key[mesh_key$Site == site, ]
    note <- paste(sprintf("%s cm, %s: DAP %d, LAI %.2f", ifelse(key$Spacing == 15, "38", "76"),
                          key$Leaf_type, key$DAP, key$LAI_used), collapse = "\n")
    p <- ggplot(s, aes(N_sub_total, A_umol_m2_s, group = interaction(Leaf_type, Row_spacing))) +
      geom_line(aes(color = Leaf_type, linetype = Row_spacing), linewidth = 0.55,
                show.legend = if (legend) {
                  c(linetype = TRUE, fill = FALSE, shape = FALSE, color = FALSE)
                } else FALSE) +
      geom_point(aes(fill = Leaf_type, shape = Leaf_type), size = 1.6, stroke = 0.3,
                 color = "black",
                 show.legend = if (legend) {
                   c(fill = TRUE, shape = TRUE, linetype = FALSE)
                 } else FALSE) +
      scale_x_log10(breaks = X_BREAKS, labels = X_LABELS) +
      scale_y_continuous(limits = Y_LIM, breaks = seq(37, 62, 5)) +
      scale_color_manual(values = LEAF_LINE, guide = "none") +
      scale_fill_manual(values = LEAF_FILL, name = LEAF_NAME) +
      scale_shape_manual(values = LEAF_SHAPE, name = LEAF_NAME) +
      scale_linetype_manual(values = SPACING_LTY, name = "Row spacing") +
      guides(fill = guide_legend(order = 1), shape = guide_legend(order = 1),
             linetype = guide_legend(order = 2, override.aes = list(color = "black"))) +
      labs(x = ttl("Sub-leaf elements per leaflet"), y = NULL) +
      supp_theme + theme(legend.key.width = unit(0.3, "in"), legend.box = "horizontal",
                         legend.spacing.x = unit(0.25, "in"))
    if (notes) p <- p +
      inside_label(if (site == "SF") "SoyFACE" else "Energy Farm", x = Inf, y = Inf, hjust = 1.08,
                   vjust = 1.7) +
      annotate("text", x = 225, y = Y_LIM[2] - 2.2, label = note, hjust = 1, vjust = 1,
               size = NOTE_MM, family = FONT, color = NOTE_COL, lineheight = 0.9)
    p
  }
  MESH_TITLE <- list("Helios canopy A", U$flux_co2)

  ## Panel D. Per-plot canopy A against leaflet count after canopy closure -------------------
  # Read the Helios summaries of both sites (5,299 plot-dates).
  raw <- bind_rows(
    read_csv(FP_SF, show_col_types = FALSE),
    read_csv(FP_EF, show_col_types = FALSE)
  )
  cat(sprintf("\nHelios summary loaded: %d rows (plot-dates)\n", nrow(raw)))

  # Broad- and narrow-leaflet NIL plots after canopy closure (DAP >= 70), per-plot means over
  # the post-closure dates.
  plot_lvl <- raw %>%
    filter(Leaf_type %in% c("Broad", "Narrow"),
           DAP >= 70,
           is.finite(A_umol_m2_s), is.finite(n_leaflets)) %>%
    mutate(Leaf_type = factor(Leaf_type, levels = c("Broad", "Narrow")),
           Cell = cell_factor(Site, Spacing)) %>%
    group_by(Cell, Leaf_type, Loc_ID) %>%
    summarize(A_mean          = mean(A_umol_m2_s, na.rm = TRUE),
              n_leaflets_mean = mean(n_leaflets,   na.rm = TRUE),
              .groups = "drop")

  cat("\nPlots per combination and leaflet type (DAP >= 70, per-plot means):\n")
  print(as.data.frame(plot_lvl %>% count(Cell, Leaf_type)))

  # Ordinary least-squares regression of canopy A on leaflet count for each leaflet type in
  # each combination, with the facet label text and its vertical position.
  fit_tab <- plot_lvl %>%
    group_by(Cell, Leaf_type) %>%
    summarize(
      n      = n(),
      slope  = coef(lm(A_mean ~ n_leaflets_mean))[2],
      pval   = summary(lm(A_mean ~ n_leaflets_mean))$coefficients[2, 4],
      r2     = summary(lm(A_mean ~ n_leaflets_mean))$r.squared,
      .groups = "drop"
    ) %>%
    mutate(label = sprintf("n = %d, %s, R² = %.2f", n,
                           ifelse(pval < 0.001, "P < 0.001", sprintf("P = %.3f", pval)), r2),
           v_anchor = ifelse(Leaf_type == "Broad", 1.5, 2.8))

  cat("\nRegression of canopy A on leaflet count per combination and leaflet type\n")
  print(as.data.frame(fit_tab %>% select(Cell, Leaf_type, n, slope, pval, r2)))

  cat(sprintf("\nSlope direction: %d positive, %d zero or negative (of 8 %s)\n",
              sum(fit_tab$slope > 0, na.rm = TRUE),
              sum(fit_tab$slope <= 0, na.rm = TRUE),
              "combination x leaflet type groups"))

  # Regression table. The table names the combinations with a hyphen ("SoyFACE - 38 cm").
  write_csv(fit_tab %>%
              mutate(Cell = sub(", ", " - ", as.character(Cell), fixed = TRUE)) %>%
              select(Cell, Leaf_type, n, slope, pval, r2),
            file.path(OUT, "FigS8D_regression_table.csv"))

  panel_D <- function(notes = TRUE, legend = FALSE) {
    p <- ggplot(plot_lvl, aes(x = n_leaflets_mean, y = A_mean, color = Leaf_type, fill = Leaf_type)) +
      geom_point(aes(shape = Leaf_type), size = 1.0, stroke = 0.22, alpha = 0.85, color = "black",
                 show.legend = legend) +
      geom_smooth(method = "lm", formula = y ~ x, se = TRUE, alpha = 0.18, linewidth = 0.5,
                  show.legend = FALSE) +
      scale_color_manual(values = LEAF_LINE, name = LEAF_NAME) +
      scale_fill_manual(values = LEAF_FILL, name = LEAF_NAME) +
      scale_shape_manual(values = LEAF_SHAPE, name = LEAF_NAME) +
      scale_x_continuous(labels = function(v) v / 1000, n.breaks = 4) +
      scale_y_continuous(expand = expansion(mult = c(0.04, if (notes) 0.17 else 0.04))) +
      facet_wrap(~ Cell, nrow = 1, scales = "free_x") +
      labs(x = bquote(bold("Per-plot leaflet count") *
                        plain(" (thousands; post-closure mean, DAP ≥ 70)")),
           y = NULL) +
      supp_theme
    if (notes) p <- p + geom_text(data = fit_tab,
                                  aes(x = -Inf, y = Inf, label = label, color = Leaf_type,
                                      vjust = v_anchor),
                                  hjust = -0.05, size = NOTE_MM, family = FONT, inherit.aes = FALSE,
                                  show.legend = FALSE)
    p
  }
  D_TITLE <- list("Per-plot canopy A", U$flux_co2)

  ## Finished figure ------------------------------------------------------------------------
  # One legend row, panel A centered, panels B and C side by side, panel D across the width.
  legend_row <- legend_of(panel_mesh("SF", legend = TRUE))
  row_A <- wrap_plots(plot_spacer(), tag_cell("A", lift = STRIP_H),
                      title_cell(A_TITLE[[1]], A_TITLE[[2]]), panel_A() + no_legend, plot_spacer(),
                      nrow = 1,
                      widths = unit(c(1, TAG_W, TITLE_W, 3.25, 1),
                                    c("null", "in", "in", "in", "null")))
  row_BC <- wrap_plots(tag_cell("B"), title_cell(MESH_TITLE[[1]], MESH_TITLE[[2]]),
                       panel_mesh("SF") + no_legend,
                       tag_cell("C"), plot_spacer(), panel_mesh("EF") + no_legend,
                       nrow = 1,
                       widths = unit(c(TAG_W, TITLE_W, 1, TAG_W, 0.08, 1),
                                     c("in", "in", "null", "in", "in", "null")))
  row_D <- assemble(list(panel_cells("D", D_TITLE, panel_D() + no_legend, lift = STRIP_H)),
                    collect = FALSE)
  save_rows(list(legend_row, row_A, row_BC, row_D), heights = c(0.32, 2.47, 2.27, 2.3),
            file.path(OUT, "FigS8_combined.png"))

  ## Single panels ---------------------------------------------------------------------------
  save_panel(function(notes) single_panel(A_TITLE, panel_A(notes, legend = TRUE)),
             file.path(OUT, "FigS8A_leaflet_area_check"), height = 2.64, width = 4.07)
  # In the single mesh panels the two legends are stacked, because side by side they are wider
  # than the panel.
  stacked_legend <- theme(legend.box = "vertical", legend.spacing.y = unit(0.02, "in"))
  save_panel(function(notes) {
    single_panel(MESH_TITLE, panel_mesh("SF", notes, legend = TRUE) + stacked_legend)
  }, file.path(OUT, "FigS8B_mesh_test_SF"), height = 2.78, width = 3.8)
  save_panel(function(notes) {
    single_panel(MESH_TITLE, panel_mesh("EF", notes, legend = TRUE) + stacked_legend)
  }, file.path(OUT, "FigS8C_mesh_test_EF"), height = 2.78, width = 3.8)
  save_panel(function(notes) single_panel(D_TITLE, panel_D(notes, legend = TRUE)),
             file.path(OUT, "FigS8D_canopy_a_vs_leaflet_count"), height = 2.4)

  cat(sprintf("\nWrote the finished figure, the single panels and the three tables to %s\n", OUT))
}

# ==================================================================================================
# Run
# ==================================================================================================

SECTIONS <- c(
  "fig1c", "fig1d", "fig1cd_stats", "fig2a", "fig2c", "fig2d", "fig3ab", "fig3cd", "fig4a",
  "fig4b", "fig5a", "fig5b", "fig5c", "fig5d", "fig6a", "fig6b", "fig6b_kgha", "fig6_stats",
  "fig7a", "fig7b", "fig7b_qq", "fig7c", "figS1", "figS2", "figS3", "figS4", "figS5", "figS6",
  "figS8"
)

requested <- commandArgs(trailingOnly = TRUE)
if ("--list" %in% requested) {
  cat(SECTIONS, sep = "\n")
  quit(save = "no")
}
if (length(requested) == 0) requested <- SECTIONS
if (!all(requested %in% SECTIONS))
  stop("unknown section: ", paste(setdiff(requested, SECTIONS), collapse = ", "),
       ". Run with --list to see the section names.")

for (section in SECTIONS[SECTIONS %in% requested]) {
  cat(sprintf("\n===== %s =====\n", section))
  do.call(section, list())
  invisible(gc())
}
