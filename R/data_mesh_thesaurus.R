#' Download and Combine MeSH and Supplemental Thesauruses
#'
#' This function downloads and combines the MeSH (Medical Subject Headings) Thesaurus 
#' and a supplemental concept thesaurus for use in biomedical research and analysis.
#' The data is sourced from specified URLs and stored locally for subsequent use.
#' @param force_download A logical value indicating whether to force re-downloading 
#' of the data even if it already exists locally.
#' @return A data.table containing the combined MeSH and supplemental thesaurus data.
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file
#' @importFrom data.table rbindlist
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Code that downloads data or performs other interactive-only operations
#'   data <- data_mesh_thesaurus()
#' }
#' }


data_mesh_thesuarus <- function(force_download = FALSE) {
  
  # URLs for the MeSH thesaurus and supplemental thesaurus data
  sf <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_mesh_thesaurus.rds?raw=true'
  sf2 <- 'https://github.com/jaytimm/mesh-builds/blob/main/data/data_scr_thesaurus.rds?raw=true'
  
  # Local file paths for storing the downloaded data
  df <- file.path(rappdirs::user_data_dir('puremoe'), 'data_mesh_thesuarus.rds')
  df2 <- file.path(rappdirs::user_data_dir('puremoe'), 'data_scr_thesuarus.rds')
  
  # Check for the existence of the files or force download
  if (!file.exists(df) | force_download) {
    # Create the directory if it doesn't exist
    if (!dir.exists(rappdirs::user_data_dir('puremoe'))) {
      dir.create(rappdirs::user_data_dir('puremoe'), recursive = TRUE)
    }
    
    # Download the MeSH thesaurus data
    message('Downloading the mesh thesaurus ...')
    utils::download.file(sf, df, mode = "wb")
  }
  
  # Repeat the process for the supplemental concept thesaurus
  if (!file.exists(df2) | force_download) {
    message('Downloading the supplemental concept thesaurus ...')
    utils::download.file(sf2, df2, mode = "wb")
  }
  
  # Read the downloaded RDS files
  a1 <- readRDS(df)
  a2 <- readRDS(df2)
  
  # Ensure the column names are consistent between the two data sets
  colnames(a2) <- colnames(a1)
  
  # Combine the data using data.table's rbindlist
  data.table::rbindlist(list(a1, a2))
}
