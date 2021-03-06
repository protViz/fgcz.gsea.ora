rm(list = ls())
library(WebGestaltR)
library(tidyverse)
library(org.Hs.eg.db)
library(sigora)
library(GO.db)
library(slam)
library(prora)
library(readr)

# Files -------------------------------------------------------------------


grp2report <- "d:/projects/p23314/MQ_2grp_report_Diseased_vs_control_fc1_q005.txt"
#grp2report <- "../../data/2Grp_CF_a_vs_CF_b.txt"
result_dir <- "gsea_ora_results"



#target_SIGORA <- target_SIGORA[1]

target_SIGORA <- c("GO", "KEGG", "reactome")
organism <- "hsapiens"
ID_col <- "TopProteinName"
fc_col <- "log2FC"
fc_threshold <- 1
greater <- TRUE


fpath_se <- tools::file_path_sans_ext(basename(grp2report))
odir <- file.path(result_dir , make.names(fpath_se))


dd <- read_tsv(grp2report)
dd <- dd %>% select_at(c(ID_col, fc_col))
filtered_dd <- get_UniprotID_from_fasta_header(dd,idcolumn = ID_col) %>%
  filter(!is.na(UniprotID))


# Parameters --------------------------------------------------------------

filtered_dd <- na.omit(filtered_dd)
sum(filtered_dd[[fc_col]] > fc_threshold)


# Run ---------------------------------------------------------------------

if (!dir.exists(odir)) {
  if (!dir.create(odir,recursive = TRUE)) {
    stop("\n can't create odir", odir, "\n")
  }
}


if (organism == "hsapiens"){
  res <- lapply(target_SIGORA, function(target_SIGORA) {
    message(target_SIGORA)
    prora::runSIGORA(
      data = filtered_dd,
      target = target_SIGORA,
      score_col = fc_col,
      ID_col = "UniprotID",
      threshold = fc_threshold,
      greater = greater,
      outdir = file.path(odir, "sigORA")
    )
  })
}
