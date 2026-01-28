#' Internal: Fetch Data from 'iCite' Database
#'
#' This internal function is designed to scrape data from the 'iCite' database, a bibliometric tool provided by the 'NIH'. It constructs a URL to query 'iCite' with specified 'PubMed' IDs and retrieves citation metrics and other related data.
#' @param x A vector of 'PubMed' IDs for which data is to be fetched from the 'iCite' database.
#' @return A data.frame consisting of the data retrieved from iCite, formatted as CSV.
#' @importFrom httr GET content
#' @importFrom utils read.csv
#' @noRd
#' 

.fetch_icites <- function(x, sleep){
  
  # Construct the URL for the iCite API call, including the PubMed IDs (x)
  url0 <- tryCatch({
    httr::GET(paste0("https://icite.od.nih.gov/api/pubs?pmids=",
                     paste(x, collapse = ","),
                     "&format=csv"))
  }, error = function(e) {
    message("Unable to connect to iCite API. The resource may be temporarily unavailable.")
    return(NULL)
  })
  
  # If GET request failed, return empty data.frame
  if (is.null(url0)) {
    return(data.frame(pmid = x))
  }
  
  # Check HTTP status code
  if (httr::status_code(url0) != 200) {
    message("iCite API returned an error. The resource may be temporarily unavailable.")
    return(data.frame(pmid = x))
  }
  
  # Read the content of the response as a CSV.
  csv_ <- tryCatch({
    utils::read.csv(textConnection(
      httr::content(url0,
                    "text",
                    encoding = "UTF-8")),
      encoding = "UTF-8")
  }, error = function(e) {
    message("Unable to parse data from iCite API. The resource may have returned invalid data.")
    return(data.frame(pmid = x))
  })
  
  Sys.sleep(sleep)
  # Return the CSV content as a data.frame
  return(csv_)
}




#' Process and Structure Data from iCite
#'
#' Function processes and structures the data obtained via `.fetch_icites`.
#' @param x A vector of PubMed IDs for which data has been fetched from the iCite database.
#' @return A data.table enhanced with citation network information and cleaned reference and citation data.
#' @importFrom data.table setDT
#' @noRd
#' 
#' 
# .get_icites <- function(x, sleep){
#   
#   # Fetch data from iCite using the PubMed IDs provided
#   pmiddf <- .fetch_icites(x, sleep)
#   
#   # Extract the PubMed IDs for reference
#   gots <- pmiddf$pmid
#   
#   # Convert pmiddf to a data.table for efficient data manipulation
#   data.table::setDT(pmiddf)
#   
#   # Clean and format the 'ref_count' column
#   ref_count <- NULL
#   pmiddf[, ref_count := ifelse(is.null(references)|is.na(references), NULL, references)]
#   
#   # Process 'references' and 'cited_by' columns, handling empty or NA values
#   pmiddf[, references := ifelse(nchar(references) == 0|is.na(references), '99', references)]
#   pmiddf[, cited_by := ifelse(nchar(cited_by) == 0|is.na(cited_by), '99', cited_by)]
#   
#   # Split the 'cited_by' and 'references' columns into lists
#   cited_by <- strsplit(pmiddf$cited_by, split = " ")
#   references <- strsplit(pmiddf$references, split = " ")
#   rs <- strsplit(pmiddf$ref_count, split = " ")
#   
#   # Build a data frame for references
#   doc_id <- NULL
#   from <- NULL
#   refs <- data.table::data.table(doc_id = rep(gots, sapply(references, length)),
#                                  from = rep(gots, sapply(references, length)),
#                                  to = unlist(references))
#   # Replace placeholder '99' with NA
#   refs[refs == 99] <- NA
#   
#   # Aggregate reference data and convert to a data.table
#   refs0 <- refs[, list(references = .N), by = list(from)]
#   
#   # Build a data frame for cited_by data
#   cited <- data.frame(doc_id = rep(gots, sapply(cited_by, length)),
#                       from = unlist(cited_by),
#                       to = rep(gots, sapply(cited_by, length)))
#   # Replace placeholder '99' with NA
#   cited[cited == 99] <- NA
#   
#   # Combine references and cited_by data
#   f1 <- rbind(refs, cited)
#   # Aggregate the combined data and format as a list within a data.table
#   f2 <- data.table::setDT(f1)[, list(references = list(.SD)), by = doc_id]
#   
#   # Add citation network data to pmiddf
#   citation_net <- NULL
#   pmiddf[, citation_net := f2$references]
#   # Calculate and add reference count
#   pmiddf[, ref_count := sapply(rs, length)]
#   # Remove the original 'cited_by' and 'references' columns
#   pmiddf[, c('cited_by', 'references') := NULL]
#   
#   # Return the processed data table
#   pmiddf[, c(1, 6:25)]
# }

.get_icites <- function(x, sleep = 0.25) {
  
  pmiddf <- .fetch_icites(x, sleep)
  
  # If fetch failed, return NULL
  if (is.null(pmiddf) || nrow(pmiddf) == 0) {
    return(NULL)
  }
  
  data.table::setDT(pmiddf)
  
  # Normalize pmid column - use X_id if pmid is missing or NA
  if ("X_id" %in% names(pmiddf)) {
    if (!"pmid" %in% names(pmiddf)) {
      # If pmid doesn't exist, create it from X_id
      pmiddf[, pmid := X_id]
    } else {
      # If pmid exists but has NA values, fill from X_id
      pmiddf[is.na(pmid) | pmid == "", pmid := X_id]
    }
  }
  
  # Ensure pmid column exists
  if (!"pmid" %in% names(pmiddf)) {
    message("Warning: No pmid or X_id column found in iCite response.")
    return(NULL)
  }
  
  # normalize field names to old expectations
  if ("citedPmids" %in% names(pmiddf) && !"references" %in% names(pmiddf)) {
    data.table::setnames(pmiddf, "citedPmids", "references")
  }
  if ("citedByPmids" %in% names(pmiddf) && !"cited_by" %in% names(pmiddf)) {
    data.table::setnames(pmiddf, "citedByPmids", "cited_by")
  }
  
  # Ensure required columns exist for citation network processing
  has_references <- "references" %in% names(pmiddf)
  has_cited_by <- "cited_by" %in% names(pmiddf)
  
  if (!has_references) {
    pmiddf[, references := NA_character_]
  }
  if (!has_cited_by) {
    pmiddf[, cited_by := NA_character_]
  }
  
  # Extract PMIDs for citation network processing
  gots <- pmiddf$pmid
  gots <- as.character(gots)  # Ensure character type
  
  # Process citation networks if we have the data
  if (has_references || has_cited_by) {
    pmiddf[, ref_count := ifelse(is.null(references)|is.na(references), NULL, references)]
    pmiddf[, references := ifelse(nchar(references) == 0|is.na(references), '99', references)]
    pmiddf[, cited_by := ifelse(nchar(cited_by) == 0|is.na(cited_by), '99', cited_by)]
    
    cited_by  <- strsplit(pmiddf$cited_by,  split = " ")
    references <- strsplit(pmiddf$references, split = " ")
    rs <- strsplit(pmiddf$ref_count, split = " ")
    
    refs <- data.table::data.table(
      doc_id = rep(gots, sapply(references, length)),
      from   = rep(gots, sapply(references, length)),
      to     = unlist(references)
    )
    refs[refs == 99] <- NA
    refs0 <- refs[, .(references = .N), by = .(from)]
    
    cited <- data.table::data.table(
      doc_id = rep(gots, sapply(cited_by, length)),
      from   = unlist(cited_by),
      to     = rep(gots, sapply(cited_by, length))
    )
    cited[cited == 99] <- NA
    
    f1 <- rbind(refs, cited)
    if (nrow(f1) > 0) {
      f2 <- data.table::setDT(f1)[, .(references = list(.SD)), by = doc_id]
      pmiddf[, citation_net := f2$references[match(gots, f2$doc_id)]]
      pmiddf[, ref_count := sapply(rs, length)]
    } else {
      pmiddf[, citation_net := list(list())]
      pmiddf[, ref_count := 0L]
    }
    
    # Remove temporary columns if they existed before
    if (has_references || has_cited_by) {
      cols_to_remove <- c("references", "cited_by")
      cols_to_remove <- cols_to_remove[cols_to_remove %in% names(pmiddf)]
      if (length(cols_to_remove) > 0) {
        pmiddf[, (cols_to_remove) := NULL]
      }
    }
  } else {
    # No citation network data, just set defaults
    pmiddf[, citation_net := list(list())]
    pmiddf[, ref_count := 0L]
  }
  
  # Define columns to keep (only select those that exist)
  icites_keep <- c(
    "pmid",
    "citation_count",
    "relative_citation_ratio",
    "nih_percentile",
    "field_citation_rate",
    "is_research_article",
    "is_clinical",
    "provisional",
    "citation_net",
    "cited_by_clin"
  )
  
  # Select only columns that exist in the data.table
  cols_to_keep <- icites_keep[icites_keep %in% names(pmiddf)]
  
  # If pmid is not in the keep list but exists, ensure it's included
  if (!"pmid" %in% cols_to_keep && "pmid" %in% names(pmiddf)) {
    cols_to_keep <- c("pmid", cols_to_keep)
  }
  
  # Select only the columns that exist
  if (length(cols_to_keep) > 0) {
    pmiddf <- pmiddf[, .SD, .SDcols = cols_to_keep]
  }
  
  return(pmiddf[])
}
