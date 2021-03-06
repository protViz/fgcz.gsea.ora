#!/usr/bin/Rscript

options(nwarnings = 10000)
library(docopt)


"WebGestaltR ORA for multigroup reports

Usage:
  test.R <grp2file> [--organism=<organism>] [--outdir=<outdir>] [--log2fc=<log2fc>] [--idtype=<idtype>] [--ID_col=<ID_col>] [--nperm=<nperm>] [--score_col=<score_col>] [--contrast=<contrast>]

Options:
  -o --organism=<organism> organism [default: hsapiens]
  -r --outdir=<outdir> output directory [default: results_ora]
  -l --log2fc=<log2fc> fc threshold [default: 1]
  -t --idtype=<idtype> type of id used for mapping [default: uniprotswissprot]
  -i --ID_col=<ID_col> Column containing the UniprotIDs [default: UniprotID]
  -n --nperm=<nperm> number of permutations to calculate enrichment scores [default: 500]
  -e --score_col=<score_col> column containing fold changes [default: estimate]
  -c --contrast=<contrast> column containing fold changes [default: contrast]

Arguments:
  grp2file  input file
" -> doc

if(FALSE){


  args <- c("D:\\Dropbox\\DataAnalysis\\p2558_With_TOBI_K\\p2558_o5748\\results_modelling_testing\\modelling_results_peptide\\foldchange_estimates.xlsx",
  "-o",
  "rnorvegicus",
  "-i",
  "P_ENTREZGENEID",
  "-t",
  "entrezgene")


  #"D:\\Dropbox\\DataAnalysis\\p2109_PEPTIDE_Analysis\\p2109_Diabetes_plaque\\results_modelling_NICE\\modelling_results_peptide\\foldchange_estimates.xlsx")

  #print(args2grp)
  #args2grp
  opt <- docopt(doc, args = args)
}else{
  opt <- docopt(doc)
}

suppressMessages(library(WebGestaltR))
suppressMessages(library(tidyverse))
suppressMessages(library(org.Hs.eg.db))
suppressMessages(library(sigora))
suppressMessages(library(GO.db))
suppressMessages(library(slam))
suppressMessages(library(prora))
suppressMessages(library(readr))

# Check command args ------------------------------------------------------

cat("\nParameters used:\n\t",
    "grp2report:", grp2report <- opt$grp2file, "\n\t",
    "result_dir:", result_dir <- opt[["--outdir"]], "\n\t",
    "    log2fc:", log2fc <- as.numeric(opt[["--log2fc"]]), "\n\t",
    "  organism:", organism <- opt[["--organism"]], "\n\t",
    "    idtype:", idtype <- opt[["--idtype"]], "\n\t",
    "    ID_col:", idcolumn <- opt[["--ID_col"]], "\n\t",
    "     nperm:", nperm <- as.numeric(opt[["--nperm"]]), "\n\t",
    "  contrast:", contrast <- opt[["--contrast"]], "\n\t",
    "  score_col:", score_col <- opt[["--score_col"]], "\n\n\n")


target_GSEA <- c(
  "geneontology_Biological_Process",
  "geneontology_Cellular_Component",
  "geneontology_Molecular_Function"
)

ID_col <- idcolumn
fc_col <- score_col

organisms <- listOrganism(hostName = "http://www.webgestalt.org/", cache = NULL)

if(! organism %in% organisms){
  cat("ERROR !\n")
  cat("Organism : " , organism , "is not in the list of available organisms!")
  cat("List of available orginisms\n")
  cat( paste(organisms, collapse="\n") )
  stop("ERROR !\n" )
}

idtypes <- listIdType(organism = organism, hostName = "http://www.webgestalt.org/", cache = NULL)

if(! idtype %in% idtypes){
  cat("ERROR !\n")
  cat("idtype : " , idtype , "is not in the list of available idtypes!\n" )
  cat("list of available idtypes?\n")
  cat(paste(idtypes, collapse="\n"))
  stop("ERROR !\n")
}

# Parameters --------------------------------------------------------------


result_dir <- paste0(result_dir,"_",format(Sys.time(), '%d%b%Y_%H%M%S'))
cat("creating dir ", result_dir,"\n")
if(dir.exists(result_dir)){
  unlink(result_dir, recursive = TRUE)
}
dir.create(result_dir)


fc_estimates <- readxl::read_xlsx(grp2report)
fc_estimates <- fc_estimates %>% select_at(c(ID_col, fc_col, contrast))

print("Selected columns: ")
print(sample_n(fc_estimates, 10))


filtered_dd <- na.omit(fc_estimates)
print("After ID filtering columns: ")
print(sample_n(filtered_dd, 10))


filtered_dd_list <- base::split(filtered_dd, filtered_dd[[contrast]])
contr_names <- names(filtered_dd_list)
contr_names <- gsub(" ","", contr_names)
contr_names <- gsub("-","_vs_", contr_names)
contr_names <- make.names(contr_names)
names(filtered_dd_list) <- contr_names


log2fc_s <- c(log2fc, -as.numeric(log2fc))

res <- list()
for(target in target_GSEA){
  res_sign <- list()
  for(log2fc in log2fc_s){
    is_greater <- if(log2fc > 0 ){TRUE}else{FALSE}

    subdir_name <- paste0("fc_threshold_",abs(log2fc),"_is_greater_",is_greater)

    res_contrast <- list()
    for(name in names(filtered_dd_list)){
      filtered_dd <- filtered_dd_list[[name]]

      cat("\n\n processing contrast :",name, "\n\n")


      res_contrast[[name]]  <-
        prora::runWebGestaltORA(
          data = filtered_dd,
          fpath = name,
          organism = organism,
          ID_col = idcolumn,
          target = target,
          threshold = log2fc,
          greater = is_greater,
          nperm = nperm,
          score_col = fc_col,
          outdir = result_dir,
          subdir_name = subdir_name,
          interestGeneType = idtype,
          contrast_name = filtered_dd[[contrast]][[1]]
        )
    }
    res_sign[[subdir_name]] <- res_contrast
  }
  res[[target]] <- res_sign
}

message("Storing results")
saveRDS(res, file=file.path(result_dir,"ORA_results.Rda") )

#if(FALSE){
#  res <- readRDS("d:/Dropbox/DataAnalysis/p2558_With_TOBI_K/p2558_o5358/OLD_UPLOAD/results_modelling/results_ora_25Sep2019_093859/ORA_results.Rda")
#  result_dir <- "."
#}

message("Rendering")
copy_ora_report(result_dir)
rmarkdown::render(file.path(result_dir, "ORA_Results_Overview.Rmd"),
                  params=list(ORA = res),
                  output_file = "index.html",
                  output_dir = result_dir,
                  envir = new.env())



print(summary(warnings()))
