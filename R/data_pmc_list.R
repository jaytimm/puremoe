#' Download and Process 'PMC Open Access' File List
#'
#' This function downloads the 'PubMed Central' (PMC) open access file list from the
#' 'National Center for Biotechnology Information' (NCBI) and processes it for use.
#' 
#' The data is sourced from specified URL and stored locally for subsequent use.
#' By default, the data is stored in a temporary directory. Users can opt into 
#' persistent storage by setting `use_persistent_storage` to TRUE and optionally 
#' specifying a path.
#'
#' @param path A character string specifying the directory path where data should 
#' be stored. If not provided and persistent storage is requested, it defaults to 
#' a system-appropriate persistent location managed by `rappdirs`.
#' @param use_persistent_storage A logical value indicating whether to use persistent
#' storage. If TRUE and no path is provided, data will be stored in a system-appropriate 
#' location. Defaults to FALSE, using a temporary directory.
#' @param force_install A logical value indicating whether to force re-downloading 
#' of the data even if it already exists locally.
#' @return A data frame containing the processed PMC open access file list.
#' @importFrom rappdirs user_data_dir
#' @importFrom data.table fread
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   data <- data_pmc_list()
#' }
#' }
#' 
data_pmc_list <- function(path = NULL, 
                          use_persistent_storage = FALSE, 
                          force_install = FALSE) {
  
  # URL for the PMC open access file list
  sf <- 'https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_file_list.txt'
  
  # Determine the directory path based on user preference for persistent storage
  if (use_persistent_storage && is.null(path)) {
    path <- file.path(rappdirs::user_data_dir("puremoe"), "Data")
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created persistent directory at: %s", path))
    } else {
      message(sprintf("Directory already exists at: %s", path))
    }
  } else if (is.null(path)) {
    path <- tempdir()
    message("No path provided and persistent storage not requested. Using temporary directory for this session.")
  } else {
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created directory at specified path: %s", path))
    } else {
      message(sprintf("Directory already exists at: %s", path))
    }
  }
  
  # Define local file path for storing the downloaded data
  df <- file.path(path, 'oa_file_list.rds')
  
  # Check if the file exists, and download and process it if it doesn't or if forced
  if (!file.exists(df) || force_install) {
    message('Downloading "pub/pmc/oa_file_list.txt" ...')
    suppressWarnings({
      # Read the file using data.table's fread
      pmc <- fread(sf, sep = '\t')
      
      # Set column names
      colnames(pmc) <- c('fpath', 'journal', 'PMCID', 'PMID', 'license_type')
      
      PMID <- NULL
      PMCID <- NULL
      
      # Process PMCID and PMID columns
      pmc[, PMID := gsub('^PMID:', '', PMID)]
      pmc[, PMCID := gsub('^PMC', '', PMCID)]
      
      # Replace empty strings with NA
      pmc[pmc == ''] <- NA
      
      # Save the processed data as an RDS file
      saveRDS(pmc, df)
    })
  }
  
  # Read and return the processed RDS file
  pmc <- readRDS(df)
  return(pmc)
}
