#' Convert PubMed IDs (PMIDs) to PMC IDs and Full-Text URLs
#'
#' This function converts PMIDs to PMC IDs, then fetches the full-text file URLs
#' from the PMC Open Access service. It combines both steps into a single workflow.
#'
#' @param pmids A character or numeric vector of PubMed IDs (PMIDs) to convert.
#' @param batch_size An integer specifying the number of PMIDs to process per
#'   batch for ID conversion. Defaults to 200L. The NCBI API has limitations on batch sizes.
#' @param sleep A numeric value specifying the number of seconds to pause
#'   between API requests for ID conversion (Step 1). Defaults to 0.5 seconds.
#'   For OA API calls (Step 2), sleep time is automatically adjusted based on
#'   rate limits: 0.11s with API key (10 req/sec), 0.34s without (3 req/sec).
#' @param verbose Logical, whether to print progress messages. Defaults to FALSE.
#' @param ncbi_key (Optional) NCBI API key for authenticated access.
#'
#' @return A data.table with columns:
#'   \itemize{
#'     \item \code{pmid}: The input PubMed ID
#'     \item \code{pmcid}: The corresponding PMC ID
#'     \item \code{doi}: The corresponding DOI (NA if not available)
#'     \item \code{url}: The full HTTPS URL for downloading PMC full text
#'   }
#'   Results are filtered to only include rows with valid URLs (open access articles),
#'   ordered by PMID. Returns NULL with a message if the API is unavailable or returns invalid data.
#'
#' @importFrom httr GET status_code
#' @importFrom xml2 read_xml xml_find_all xml_attr xml_find_first
#' @importFrom data.table rbindlist setorder
#' @importFrom rentrez set_entrez_key
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Convert PMIDs to PMC IDs and get full-text URLs
#'   result <- pmid_to_ftp(c("11250746", "11573492"))
#' }
#' }
#'
pmid_to_ftp <- function(pmids, batch_size = 200L, sleep = 0.5, verbose = FALSE, ncbi_key = NULL) {
  
  # Input validation
  if (missing(pmids) || length(pmids) == 0) {
    message("No PMIDs provided.")
    return(NULL)
  }
  
  if (!(is.character(pmids) || is.numeric(pmids))) {
    message("PMIDs must be character or numeric.")
    return(NULL)
  }
  
  # Set the NCBI API key for authenticated access if provided
  if (!is.null(ncbi_key)) rentrez::set_entrez_key(ncbi_key)
  
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
  
  # Step 1: Convert PMIDs to PMC IDs (batched)
  if (verbose) message("Step 1: Converting PMIDs to PMC IDs...")
  
  pmid_batches <- split(pmids, ceiling(seq_along(pmids) / batch_size))
  
  id_results <- lapply(pmid_batches, function(batch) {
    # Construct the query URL
    query <- paste0("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?",
                    "ids=", paste(batch, collapse = ","),
                    "&idtype=pmid&format=xml")
    
    Sys.sleep(sleep)
    
    # Make the API request with error handling
    resp <- tryCatch({
      httr::GET(query)
    }, error = function(e) {
      if (verbose) message("Unable to connect to NCBI ID Converter API.")
      return(NULL)
    })
    
    if (is.null(resp) || httr::status_code(resp) != 200) {
      return(NULL)
    }
    
    # Parse XML response
    doc <- tryCatch({
      xml2::read_xml(resp)
    }, error = function(e) {
      return(NULL)
    })
    
    if (is.null(doc)) {
      return(NULL)
    }
    
    # Extract records
    recs <- tryCatch({
      xml2::xml_find_all(doc, ".//record")
    }, error = function(e) {
      return(list())
    })
    
    if (length(recs) == 0) {
      return(NULL)
    }
    
    # Process each record
    dt <- data.table::rbindlist(lapply(recs, function(r) {
      pmid_val <- xml2::xml_attr(r, "pmid")
      pmcid_val <- xml2::xml_attr(r, "pmcid")
      doi_val <- xml2::xml_attr(r, "doi")
      
      list(pmid = pmid_val, pmcid = pmcid_val, doi = doi_val)
    }))
    
    return(dt)
  })
  
  # Filter out NULL results
  id_results <- id_results[!sapply(id_results, is.null)]
  
  if (length(id_results) == 0) {
    message("All ID conversion requests failed. Unable to retrieve PMC IDs.")
    return(NULL)
  }
  
  # Combine ID conversion results
  id_dt <- data.table::rbindlist(id_results, fill = TRUE)
  
  # Step 2: Get URLs for PMC IDs that exist (filter out NAs)
  if (verbose) message("Step 2: Fetching full-text URLs for PMC IDs...")
  
  pmc_ids_with_urls <- id_dt[!is.na(pmcid) & pmcid != "", ]
  
  if (nrow(pmc_ids_with_urls) > 0) {
    # Determine sleep time for OA API calls based on rate limits:
    # Without API key: 3 requests/second (0.33s between requests)
    # With API key: 10 requests/second (0.10s between requests)
    # Use slightly longer to be safe
    oa_sleep <- if (!is.null(ncbi_key)) 0.11 else 0.34
    
    # Query OA API for each PMC ID
    url_results <- lapply(seq_len(nrow(pmc_ids_with_urls)), function(i) {
      pmcid_val <- pmc_ids_with_urls$pmcid[i]
      
      oa_url <- paste0("https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi?id=", pmcid_val)
      
      Sys.sleep(oa_sleep)
      
      oa_resp <- tryCatch({
        httr::GET(oa_url)
      }, error = function(e) {
        return(NULL)
      })
      
      full_url <- NA_character_
      
      if (!is.null(oa_resp) && httr::status_code(oa_resp) == 200) {
        oa_doc <- tryCatch({
          xml2::read_xml(oa_resp)
        }, error = function(e) {
          return(NULL)
        })
        
        if (!is.null(oa_doc)) {
          # Extract the href from the link element
          link_node <- xml2::xml_find_first(oa_doc, ".//link[@format='tgz']")
          if (length(link_node) > 0) {
            ftp_url <- xml2::xml_attr(link_node, "href")
            if (!is.na(ftp_url) && ftp_url != "") {
              # Convert FTP URL to HTTPS URL
              full_url <- gsub("^ftp://", "https://", ftp_url)
            }
          }
        }
      }
      
      list(pmcid = pmcid_val, url = full_url)
    })
    
    url_dt <- data.table::rbindlist(url_results)
    
    # Add url column to id_dt if it doesn't exist
    if (!"url" %in% names(id_dt)) {
      id_dt[, url := NA_character_]
    }
    
    # Merge URLs back into main data.table using data.table syntax
    id_dt[url_dt, url := i.url, on = "pmcid"]
  } else {
    # No PMC IDs found, add empty url column
    id_dt[, url := NA_character_]
  }
  
  # Order by PMID
  data.table::setorder(id_dt, pmid)
  
  # Filter out rows where url is NA (no open access available)
  id_dt <- id_dt[!is.na(url)]
  
  return(id_dt[])
}
