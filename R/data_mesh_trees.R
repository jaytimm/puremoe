#' Download and Load 'MeSH' Trees Data
#'
#' This function downloads and loads the 'MeSH' (Medical Subject Headings) Trees data.
#' 
#' The data is sourced from specified URLs and stored locally for subsequent use.
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
#' @return A data frame containing the MeSH Trees data.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   data <- data_mesh_trees()
#' }
#' }
#' 
data_mesh_trees <- function(path = NULL, 
                            use_persistent_storage = FALSE, 
                            force_install = FALSE) {
  
  # Define the URL for the MeSH trees data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_mesh_trees.rds?raw=true'
  
  # Check if user opts for persistent storage and no path is provided
  if (use_persistent_storage && is.null(path)) {
    path <- file.path(rappdirs::user_data_dir("puremoe"), "Data")
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created persistent directory at: %s", path))
    }
  } else if (is.null(path)) {
    # Default to tempdir() for temporary storage
    path <- tempdir()
    message("No path provided and persistent storage not requested. Using temporary directory for this session.")
  } else {
    # Check if the specified path exists; if not, create it
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created directory at specified path: %s", path))
    }
  }
  
  # Determine the local file path for storing the data
  df <- file.path(path, 'data_mesh_trees.rds')
  
  # Check if the file exists or if forced download is requested
  if (!file.exists(df) || force_install) {
    # Download the MeSH trees data
    message('Downloading MeSH trees...')
    download_result <- .safe_download(sf, df, mode = "wb")
    
    # If download failed and no cached file exists, return NULL
    if (is.null(download_result) && !file.exists(df)) {
      message("Unable to download MeSH trees data. The resource may be temporarily unavailable.")
      message("No cached file available. Please check your internet connection and try again.")
      return(NULL)
    }
  }
  
  # If file doesn't exist at this point, return NULL
  if (!file.exists(df)) {
    message("MeSH trees data is not available.")
    return(NULL)
  }
  
  # Read and return the downloaded RDS file
  a1 <- readRDS(df)
  return(a1)
}