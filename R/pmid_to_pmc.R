#' Convert PubMed IDs (PMIDs) to PMC IDs
#'
#' This function converts a vector of PubMed IDs (PMIDs) to their corresponding
#' PubMed Central (PMC) IDs and DOIs using the NCBI ID Converter API.
#'
#' @param pmids A character or numeric vector of PubMed IDs (PMIDs) to convert.
#' @param batch_size An integer specifying the number of PMIDs to process per
#'   batch. Defaults to 200L. The NCBI API has limitations on batch sizes.
#' @param sleep A numeric value specifying the number of seconds to pause
#'   between API requests. Defaults to 0.5 seconds to respect API rate limits.
#'
#' @return A data.table with columns:
#'   \itemize{
#'     \item \code{pmid}: The input PubMed ID
#'     \item \code{pmcid}: The corresponding PMC ID (NA if not available in PMC)
#'     \item \code{doi}: The corresponding DOI (NA if not available)
#'   }
#'   Results are ordered by PMID. Returns NULL with a message if the API is
#'   unavailable or returns invalid data.
#'
#' @importFrom httr GET status_code
#' @importFrom xml2 read_xml xml_find_all xml_attr
#' @importFrom data.table rbindlist setorder
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Convert a single PMID to PMC ID
#'   result <- pmid_to_pmc("12345678")
#'   
#'   # Convert multiple PMIDs
#'   pmids <- c("12345678", "23456789", "34567890")
#'   result <- pmid_to_pmc(pmids, batch_size = 10, sleep = 1)
#' }
#' }
#'
pmid_to_pmc <- function(pmids, batch_size = 200L, sleep = 0.5) {
  
  # Input validation
  if (missing(pmids) || length(pmids) == 0) {
    message("No PMIDs provided.")
    return(NULL)
  }
  
  if (!(is.character(pmids) || is.numeric(pmids))) {
    message("PMIDs must be character or numeric.")
    return(NULL)
  }
  
  # Convert to character if numeric
  pmids <- as.character(pmids)
  
  # Remove any NA or empty values
  pmids <- pmids[!is.na(pmids) & pmids != ""]
  
  if (length(pmids) == 0) {
    message("No valid PMIDs provided after removing NAs and empty values.")
    return(NULL)
  }
  
  # Ensure batch_size is a positive integer
  batch_size <- as.integer(batch_size[1])
  if (is.na(batch_size) || batch_size < 1) {
    batch_size <- 200L
    message("Invalid batch_size, using default value of 200.")
  }
  
  # Ensure sleep is non-negative
  sleep <- as.numeric(sleep[1])
  if (is.na(sleep) || sleep < 0) {
    sleep <- 0.5
    message("Invalid sleep value, using default value of 0.5.")
  }
  
  # Split PMIDs into batches
  pmid_batches <- split(pmids, ceiling(seq_along(pmids) / batch_size))
  
  # Process each batch
  results <- lapply(pmid_batches, function(batch) {
    # Construct the query URL
    query <- paste0("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?",
                    "ids=", paste(batch, collapse = ","),
                    "&idtype=pmid&format=xml")
    
    # Sleep before making request
    Sys.sleep(sleep)
    
    # Make the API request with error handling
    resp <- tryCatch({
      httr::GET(query)
    }, error = function(e) {
      message("Unable to connect to NCBI ID Converter API. The resource may be temporarily unavailable.")
      return(NULL)
    })
    
    # Check if request failed
    if (is.null(resp)) {
      return(NULL)
    }
    
    # Check HTTP status code (fail gracefully instead of using stop_for_status)
    if (httr::status_code(resp) != 200) {
      message("NCBI ID Converter API returned an error. The resource may be temporarily unavailable.")
      return(NULL)
    }
    
    # Parse XML response with error handling
    doc <- tryCatch({
      xml2::read_xml(resp)
    }, error = function(e) {
      message("Unable to parse response from NCBI ID Converter API. The resource may have returned invalid data.")
      return(NULL)
    })
    
    # Check if parsing failed
    if (is.null(doc)) {
      return(NULL)
    }
    
    # Extract records
    recs <- tryCatch({
      xml2::xml_find_all(doc, ".//record")
    }, error = function(e) {
      message("Unable to extract records from API response.")
      return(list())
    })
    
    # If no records found, return NULL for this batch
    if (length(recs) == 0) {
      return(NULL)
    }
    
    # Process each record - just get PMC IDs and DOIs (no URL fetching here)
    dt <- data.table::rbindlist(lapply(recs, function(r) {
      pmid_val <- xml2::xml_attr(r, "pmid")
      pmcid_val <- xml2::xml_attr(r, "pmcid")
      doi_val <- xml2::xml_attr(r, "doi")
      
      list(pmid = pmid_val, pmcid = pmcid_val, doi = doi_val)
    }))
    
    return(dt)
  })
  
  # Filter out NULL results
  results <- results[!sapply(results, is.null)]
  
  # If all batches failed, return NULL
  if (length(results) == 0) {
    message("All API requests failed. Unable to retrieve PMC IDs.")
    return(NULL)
  }
  
  # Combine all results
  result_dt <- data.table::rbindlist(results, fill = TRUE)
  
  # Order by PMID
  data.table::setorder(result_dt, pmid)
  
  return(result_dt[])
}
