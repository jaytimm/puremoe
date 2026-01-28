#' Fetch Batch of 'PubMed' Records as XML
#'
#' This function attempts to fetch batches of 'PubMed' records in XML format. It retries multiple times in case of failures.
#' @param x A vector of 'PubMed' record identifiers to be fetched.
#' @return A character string with XML content of 'PubMed' records, or an error object in case of failure.
#' @importFrom rentrez entrez_fetch
#' @noRd
#' 
#' 
.fetch_records <- function(x, sleep) {
  # Loop to retry fetching records, with a maximum of 15 attempts
  x1 <- NULL
  for (i in 1:15) {
    # Display the current attempt number
    #message(i)
    
    # Try fetching records using rentrez::entrez_fetch
    x1 <- try({
      rentrez::entrez_fetch(
        db = "pubmed",
        id = x,
        rettype = "xml",
        parsed = FALSE
      )
    }, silent = TRUE)
    
    # Wait before the next attempt
    Sys.sleep(sleep)
    
    # Check if the fetch was successful using inherits(), and if so, break the loop
    if (!inherits(x1, "try-error")) {
      break
    }
  }
  
  # If all attempts failed, fail gracefully with informative message
  if (inherits(x1, "try-error") || is.null(x1)) {
    message("Unable to fetch records from PubMed. The resource may be temporarily unavailable.")
    return(list())
  }
  
  # Return the fetched XML content
  tryCatch({
    doc <- xml2::read_xml(x1)
    xml2::xml_find_all(doc, "//PubmedArticle")
  }, error = function(e) {
    message("Unable to parse records from PubMed. The resource may have returned invalid data.")
    return(list())
  })
}



#' Clean Missing or Invalid Values in Data
#'
#' This function standardizes the representation of missing or invalid values in data by replacing specific character representations of missing data (' ', 'NA', 'n/a', 'n/a.') with R's standard `NA`.
#' @param x A vector that may contain missing or invalid values represented in various formats.
#' @return A vector with standardized missing values represented as `NA`.
#' @noRd
#' 
#' 
.clean_nas <- function(x) {
  
  # Replace specific character representations of missing data with NA
  ifelse(x %in% c(' ', 'NA', 'n/a', 'n/a.') | is.na(x), NA, x) 
}


#' Safe Download Helper Function
#'
#' Downloads a file from a URL with comprehensive error handling.
#' Returns 0 on success, NULL on failure. Never throws errors or warnings.
#'
#' @param url Character string with the URL to download from.
#' @param destfile Character string with the destination file path.
#' @param mode Character string specifying the download mode (default "wb").
#' @return Integer 0 on success, NULL on failure.
#' @noRd
.safe_download <- function(url, destfile, mode = "wb") {
  
  # Suppress all warnings and catch all errors
  result <- tryCatch({
    suppressWarnings({
      utils::download.file(url, destfile, mode = mode, quiet = TRUE)
    })
  }, error = function(e) {
    return(NULL)
  })
  
  # Check if download was successful (returns 0 on success)
  if (is.null(result) || result != 0) {
    return(NULL)
  }
  
  # Verify file was actually created and has content
  if (!file.exists(destfile) || file.size(destfile) == 0) {
    return(NULL)
  }
  
  return(0L)
}
