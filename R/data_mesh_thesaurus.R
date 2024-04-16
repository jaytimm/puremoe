#' Download and Combine 'MeSH' and Supplemental Thesauruses
#'
#' This function downloads and combines the 'MeSH' (Medical Subject Headings) Thesaurus 
#' and a supplemental concept thesaurus.
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
#' @return A data.table containing the combined MeSH and supplemental thesaurus data.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @importFrom data.table rbindlist
#' @export
#' @examples
#' data <- data_mesh_thesaurus()
#' 
data_mesh_thesaurus <- function(path = NULL, 
                                use_persistent_storage = FALSE, 
                                force_install = FALSE) {
  
  # Define the URLs for the MeSH thesaurus and supplemental thesaurus data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_mesh_thesaurus.rds?raw=true'
  sf2 <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_scr_thesaurus.rds?raw=true'
  
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
  
  # Define local file paths for storing the downloaded data
  df <- file.path(path, 'data_mesh_thesaurus.rds')
  df2 <- file.path(path, 'data_scr_thesaurus.rds')
  
  # Check for the existence of the files or force download
  if (!file.exists(df) || force_install) {
    message('Downloading the MeSH thesaurus...')
    download.file(sf, df, mode = "wb")
  }
  
  if (!file.exists(df2) || force_install) {
    message('Downloading the supplemental concept thesaurus...')
    download.file(sf2, df2, mode = "wb")
  }
  
  # Read the downloaded RDS files
  a1 <- readRDS(df)
  a2 <- readRDS(df2)
  
  # Ensure the column names are consistent between the two data sets
  colnames(a2) <- colnames(a1)
  
  # Combine the data using data.table's rbindlist
  combined_data <- rbindlist(list(a1, a2))
  
  return(combined_data)
}