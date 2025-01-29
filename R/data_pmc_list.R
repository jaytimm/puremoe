#' Download and Process 'PMC Open Access' File List
#'
#' This function downloads the 'PubMed Central' (PMC) open access file list from the
#' 'National Center for Biotechnology Information' (NCBI) and processes it for use.
#' 
#' The data is sourced from the specified URL and stored locally for subsequent use.
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
#' @param timeout An integer indicating the timeout in seconds for the download.
#' Defaults to 300 seconds.
#' @return A data frame containing the processed PMC open access file list.
#' @importFrom rappdirs user_data_dir
#' @importFrom data.table fread
#' @importFrom httr GET write_disk timeout
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
                          force_install = FALSE, 
                          timeout = 300) {
  
  # URL for the PMC open access file list
  url <- 'https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_file_list.txt'
  
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
    message("Using temporary directory for this session.")
  } else {
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created directory at specified path: %s", path))
    } else {
      message(sprintf("Directory already exists at: %s", path))
    }
  }
  
  # Define local file path for storing the downloaded data
  local_file_path <- file.path(path, 'oa_file_list.txt')
  
  # Check if the file exists and download it if it doesn't or if force_install is TRUE
  if (!file.exists(local_file_path) || force_install) {
    message('Downloading "pub/pmc/oa_file_list.txt"...')
    tryCatch({
      httr::GET(url, httr::write_disk(local_file_path, overwrite = TRUE), httr::timeout(timeout))
    }, error = function(e) {
      stop("Failed to download the file: ", e$message)
    })
  }
  
  # Read the file using data.table's fread
  column_names <- c('fpath', 'journal', 'PMCID', 'PMID', 'license_type')
  pmc <- data.table::fread(local_file_path, sep = "\t", header = FALSE, col.names = column_names)
  
  PMID <- NULL
  PMCID <- NULL
  pmc[, `:=` (PMID = gsub('^PMID:', '', PMID), PMCID = gsub('^PMC', '', PMCID))]
  pmc[pmc == ''] <- NA  # Replace empty strings with NA
  
  # Save the processed data as an RDS file
  saveRDS(pmc, file.path(path, 'oa_file_list.rds'))
  
  return(pmc)
}
