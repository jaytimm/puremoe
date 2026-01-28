#' Download and Load 'PMC' Open Access File List
#'
#' This function downloads and loads the 'PMC' (PubMed Central) Open Access file list.
#' The file list contains mappings between PMC IDs, PMIDs, and file paths for 
#' open access articles available for download.
#' 
#' The data is sourced from NCBI's FTP server and stored locally for subsequent use.
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
#' @return A data.table containing the PMC file list with columns: file_path, 
#' citation, pmcid, pmid, and license_code.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
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
  
  # Define the URL for the PMC file list
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
  df <- file.path(path, 'oa_file_list.txt')
  
  # Check for the existence of the file or force download
  if (!file.exists(df) || force_install) {
    message('Downloading the PMC Open Access file list...')
    download_result <- .safe_download(sf, df, mode = "wb")
    
    # If download failed and no cached file exists
    if (is.null(download_result) && !file.exists(df)) {
      message("Unable to download PMC file list. The resource may be temporarily unavailable.")
      message("No cached PMC file list available. Please check your internet connection and try again.")
      return(NULL)
    }
  }
  
  # If file doesn't exist, return NULL
  if (!file.exists(df)) {
    message("PMC file list is not available.")
    return(NULL)
  }
  
  # Read the file as a tab-separated file
  # The file format is: file_path \t citation \t pmcid \t pmid \t license_code
  dt <- tryCatch({
    data.table::fread(df, sep = "\t", header = FALSE, 
                      col.names = c("file_path", "citation", "pmcid", "pmid", "license_code"),
                      na.strings = c("", "NA"))
  }, error = function(e) {
    message("Unable to parse PMC file list. The file may be corrupted.")
    return(NULL)
  })
  
  # Clean up PMID column (remove "PMID:" prefix if present)
  if (!is.null(dt) && "pmid" %in% names(dt)) {
    dt[, pmid := gsub("^PMID:", "", pmid)]
  }
  
  # Construct full URLs from file paths
  if (!is.null(dt) && "file_path" %in% names(dt)) {
    dt[, url := paste0("https://ftp.ncbi.nlm.nih.gov/pub/pmc/", file_path)]
  }
  
  return(dt)
}
