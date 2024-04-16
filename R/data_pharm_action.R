#' Download and Load Pharmacological Actions Data
#'
#' This function downloads and loads pharmacological actions data from a specified URL.
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
#' @return A data frame containing pharmacological actions data.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @export
#' @examples
#' data <- data_pharm_action()

data_pharm_action <- function(path = NULL, 
                              use_persistent_storage = FALSE, 
                              force_install = FALSE) {
  
  # URL for the pharmacological actions data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_pharm_action.rds?raw=true'
  
  # Determine the directory path based on user preference for persistent storage
  if (use_persistent_storage && is.null(path)) {
    path <- file.path(user_data_dir("MyRPackage"), "Data")
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
  df <- file.path(path, 'data_pharm_action.rds')
  
  # Check if the data file exists, and download it if it doesn't or if forced
  if (!file.exists(df) || force_install) {
    message('Downloading pharmacological actions...')
    download.file(sf, df, mode = "wb")
  }
  
  # Read and return the downloaded RDS file
  a1 <- readRDS(df)
  return(a1)
}