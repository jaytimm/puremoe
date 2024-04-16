#' Download and Process 'MeSH' and 'SCR' Embeddings
#'
#' This function downloads 'MeSH' and 'SCR' embeddings data from the specified URLs and processes it for use.
#' The data is saved locally in RDS format. If the files do not exist, they will be downloaded and processed.
#'
#' This dataset is not viewable until it has been downloaded.
#' 
#' Citation
#' 
#' Noh, J., & Kavuluru, R. (2021). Improved biomedical word embeddings in the transformer era. 
#' Journal of biomedical informatics, 120, 103867.
#'
#' @param path A character string specifying the directory path where data should 
#' be stored. If not provided and persistent storage is requested, it defaults to 
#' a system-appropriate persistent location managed by `rappdirs`.
#' @param use_persistent_storage A logical value indicating whether to use persistent
#' storage. If TRUE and no path is provided, data will be stored in a system-appropriate 
#' location. Defaults to FALSE, using a temporary directory.
#' @param force_install A logical value indicating whether to force re-downloading 
#' of the data even if it already exists locally.
#' @return A data frame containing the processed Mesh and SCR embeddings data.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   data <- data_mesh_embeddings()
#' }
#' }
#' 
data_mesh_embeddings <- function(path = NULL, 
                                 use_persistent_storage = FALSE,
                                 force_install = FALSE) {
  
  # Define the URLs for Mesh and SCR embeddings data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_mesh_embeddings.rds?raw=true'
  sf2 <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_scr_embeddings.rds?raw=true'
  
  # Determine the directory path based on user preference for persistent storage
  if (use_persistent_storage && is.null(path)) {
    path <- file.path(rappdirs::user_data_dir("puremoe"), "Data")
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created persistent directory at: %s", path))
    }
  } else if (is.null(path)) {
    path <- tempdir()
    message("No path provided and persistent storage not requested. Using temporary directory for this session.")
  } else {
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      message(sprintf("Created directory at specified path: %s", path))
    }
  }
  
  # Define local file paths for storing the downloaded data
  df <- file.path(path, 'data_mesh_embeddings.rds')
  df2 <- file.path(path, 'data_scr_embeddings.rds')
  
  # Download the Mesh embeddings data if it doesn't exist or force download is requested
  if (!file.exists(df) || force_install) {
    message('Downloading the Mesh embeddings...')
    download.file(sf, df, mode = "wb")
  }
  
  # Download the SCR embeddings data if it doesn't exist or force download is requested
  if (!file.exists(df2) || force_install) {
    message('Downloading the SCR embeddings...')
    download.file(sf2, df2, mode = "wb")
  }
  
  # Read the downloaded RDS files and ensure they exist
  if (!file.exists(df) || !file.exists(df2)) {
    message("One or both files could not be found after download. Please check the download paths and file accessibility.")
    return(NULL)
  }
  
  a1 <- readRDS(df)
  a2 <- readRDS(df2)
  
  # Combine the data using rbind
  result <- rbind(a1, a2)
  return(result)
}