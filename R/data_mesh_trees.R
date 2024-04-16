#' Download and Load MeSH Trees Data
#'
#' This function downloads and loads the MeSH (Medical Subject Headings) Trees data
#' from a specified URL. The data is stored locally for future use. If the data already 
#' exists locally, the download can be skipped unless `force_download` is set to `TRUE`.
#'
#' @param force_download A logical value indicating whether to force re-downloading 
#' of the data even if it already exists locally.
#' @return A data frame containing the MeSH Trees data.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Code that downloads data or performs other interactive-only operations
#'   data <- data_mesh_trees()
#' }
#' }

data_mesh_trees <- function(force_download = FALSE) {
  
  # Define the URL for the MeSH trees data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_mesh_trees.rds?raw=true'
  
  # Determine the local file path for storing the data
  df <- file.path(rappdirs::user_data_dir('puremoe'), 'data_mesh_trees.rds')
  
  # Check if the file exists or if forced download is requested
  if (!file.exists(df) | force_download) {
    # Create the directory if it doesn't exist
    if (!dir.exists(rappdirs::user_data_dir('puremoe'))) {
      dir.create(rappdirs::user_data_dir('puremoe'), recursive = TRUE)
    }
    
    # Download the MeSH trees data
    message('Downloading mesh trees ...')
    utils::download.file(sf, df, mode = "wb")
  }
  
  # Read and return the downloaded RDS file
  a1 <- readRDS(df)
  return(a1)
}
