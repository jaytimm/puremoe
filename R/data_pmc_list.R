#' Download and Process PMC Open Access File List
#'
#' This function downloads the PubMed Central (PMC) open access file list from the
#' National Center for Biotechnology Information (NCBI) and processes it for use.
#' The list is saved locally. If the file does not exist or if `force_install` is TRUE, 
#' it will be downloaded and processed.
#'
#' @param force_install Logical, if TRUE, forces the re-download and processing of 
#' the file even if it already exists locally. Default is FALSE.
#' @return A data frame containing the processed PMC open access file list.
#' @importFrom rappdirs user_data_dir
#' @importFrom data.table fread
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Code that downloads data or performs other interactive-only operations
#'   data <- data_pmc_list()
#' }
#' }

#' @export
data_pmc_list <- function(force_install = FALSE) {
  
  # URL for the PMC open access file list
  sf <- 'https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_file_list.txt'
  
  # Local file path for storing the processed data
  df <- file.path(rappdirs::user_data_dir('pubmedr'), 'oa_file_list.rds')
  
  # Define PMID and PMCID variables
  PMID <- NULL
  PMCID <- NULL
  
  # Check if the file exists, and download and process it if it doesn't or if forced
  if (!file.exists(df) | force_install) {
    # Create the directory if it doesn't exist
    if (!dir.exists(rappdirs::user_data_dir('puremoe'))) {
      dir.create(rappdirs::user_data_dir('puremoe'), recursive = TRUE)
    }
    
    message('Downloading "pub/pmc/oa_file_list.txt" ...')
    suppressWarnings({
      # Read the file using data.table's fread
      pmc <- data.table::fread(sf, sep = '\t')
      
      # Set column names
      colnames(pmc) <- c('fpath', 'journal', 'PMCID', 'PMID', 'license_type')
      
      # Process PMCID and PMID columns
      pmc[, PMID := gsub('^PMID:', '', PMID)]
      pmc[, PMCID := gsub('^PMC', '', PMCID)]
      
      # Replace empty strings with NA
      pmc[pmc==''] <- NA
      
      # Save the processed data as an RDS file
      setwd(rappdirs::user_data_dir('puremoe'))
      saveRDS(pmc, 'oa_file_list.rds')
    })
  }
  
  # Read and return the processed RDS file
  pmc <- readRDS(df)
  return(pmc)
}
