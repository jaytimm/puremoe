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
    })
    
    # Wait for 5 seconds before the next attempt
    Sys.sleep(sleep)
    
    # Check if the fetch was successful using inherits(), and if so, break the loop
    if (!inherits(x1, "try-error")) {
      break
    }
  }
  
  # Return the fetched XML content or an error object
  doc <- xml2::read_xml(x1)
  xml2::xml_find_all(doc, "//PubmedArticle")
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
