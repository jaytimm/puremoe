#' Download and Process Mesh and SCR Embeddings
#'
#' This function downloads Mesh and SCR embeddings data from the specified URLs and processes it for use.
#' The data is saved locally in RDS format. If the files do not exist, they will be downloaded and processed.
#'
#' @return A data frame containing the processed Mesh and SCR embeddings data.
#'
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Code that downloads data or performs other interactive-only operations
#'   data <- data_mesh_embeddings()
#' }
#' }

#' 
data_mesh_embeddings <- function() {
  
  # Define the URLs for Mesh and SCR embeddings data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_mesh_embeddings.rds?raw=true'
  sf2 <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_scr_embeddings.rds?raw=true'
  
  # Define local file paths for storing the processed data
  df <- file.path(rappdirs::user_data_dir('puremoe'), 'data_mesh_embeddings.rds')
  df2 <- file.path(rappdirs::user_data_dir('puremoe'), 'data_scr_embeddings.rds')
  
  # Check if the directory for data storage exists, and create it if not
  if (!dir.exists(rappdirs::user_data_dir('puremoe'))) {
    dir.create(rappdirs::user_data_dir('puremoe'), recursive = TRUE)
  }
  
  # Download and process Mesh embeddings data if it doesn't exist
  if (!file.exists(df)) {
    message('Downloading the Mesh embeddings ...')
    out <- tryCatch({
      utils::download.file(sf, df)
    }, error = function(e) paste("Error"))
    
    if (out == 'Error') {
      message('Download not completed ... Try options(timeout = 600)')
      file.remove(df)
    }
  }
  
  # Download and process SCR embeddings data if it doesn't exist
  if (!file.exists(df2)) {
    message('Downloading the SCR embeddings ...')
    out <- tryCatch({
      utils::download.file(sf2, df2)
    }, error = function(e) paste("Error"))
    
    if (out == 'Error') {
      message('Download not completed ... Try options(timeout = 600)')
      file.remove(df2)
    }
  }
  
  # If both files exist, read and combine them
  if (all(file.exists(df), file.exists(df2))) {
    a1 <- readRDS(df)
    a2 <- readRDS(df2)
    
    result <- rbind(a1, a2)
    return(result)
  }
  
  return(NULL)
}
