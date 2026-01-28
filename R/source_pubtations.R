#' Extract Named Entities from 'PubMed''s 'PubTator3' Tool
#'
#' This function retrieves named entity annotations from 'PubMed''s 'PubTator3' tool. It fetches data using 'PubMed' IDs and processes the JSON response into a structured format.
#' @param x A vector of 'PubMed' IDs for which annotations are to be retrieved from 'PubTator'.
#' @return A data.table, or NA if no data is available, with columns for 'PubMed' ID, title or abstract location, annotation text, start and end positions of annotations, and annotation types.
#' @importFrom jsonlite stream_in
#' @importFrom data.table rbindlist
#' @noRd
#' 
.get_pubtations <- function(x, sleep) {
  
  con <- tryCatch({
    url(paste0("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson?pmids=", paste(x, collapse = ',')))
  }, error = function(e) {
    message("Unable to connect to PubTator3 API. The resource may be temporarily unavailable.")
    return(NULL)
  })
  
  # If connection failed, return NA
  if (is.null(con)) {
    return(NA)
  }
  
  # Read JSON response safely
  mydata <- tryCatch(jsonlite::stream_in(con, verbose = FALSE), error = function(e) {
    message("Unable to read data from PubTator3 API. The resource may be temporarily unavailable.")
    return(NA)
  })
  
  # Ensure data is valid
  if (!is.data.frame(mydata) || nrow(mydata) == 0) {
    return(NA)  # No data retrieved
  }
  
  # Extract the nested JSON correctly
  if ("PubTator3" %in% names(mydata) && is.list(mydata$PubTator3[[1]])) {
    mydata <- mydata$PubTator3[[1]]
  } else {
    return(NA)  # Unexpected format
  }
  
  # Validate that mydata is a list before proceeding
  if (!is.list(mydata) || !("passages" %in% names(mydata))) {
    return(NA)  # If missing, return NA
  }
  
  # Extract annotations safely
  jj <- list()
  
  for (i in seq_along(mydata$passages)) {
    
    if (!is.list(mydata$passages[[i]])) next  # Skip if not a valid list
    
    pb1 <- mydata$passages[[i]]$annotations
    
    if (!is.list(pb1)) next  # Skip if annotations aren't in a list
    
    names(pb1) <- c("title", "abstract")
    
    # Process title
    if (!is.data.frame(pb1$title) || nrow(pb1$title) == 0) {
      pb1$title <- data.frame(tiab = "title", id = NA, text = NA, locations = NA, identifier = NA, type = NA)
    } else {
      if (!("identifier" %in% names(pb1[["title"]]$infons))) {
        pb1[["title"]]$infons$identifier <- NA
      }
      pb1$title <- cbind(tiab = "title", pb1$title[, c("id", "text", "locations")], identifier = pb1$title$infons$identifier, type = pb1$title$infons$type)
    }
    
    # Process abstract
    if (!is.data.frame(pb1$abstract) || nrow(pb1$abstract) == 0) {
      pb1$abstract <- data.frame(tiab = "abstract", id = NA, text = NA, locations = NA, identifier = NA, type = NA)
    } else {
      if (!("identifier" %in% names(pb1[["abstract"]]$infons))) {
        pb1[["abstract"]]$infons$identifier <- NA
      }
      pb1$abstract <- cbind(tiab = "abstract", pb1$abstract[, c("id", "text", "locations")], identifier = pb1$abstract$infons$identifier, type = pb1$abstract$infons$type)
    }
    
    # Merge title and abstract
    jj[[i]] <- rbind(pb1$title, pb1$abstract)
  }
  
  # If nothing was collected, return NA
  if (length(jj) == 0 || !all(sapply(jj, is.data.frame))) {
    return(NA)
  }
  
  # Convert to data.table
  names(jj) <- mydata$id
  jj0 <- data.table::rbindlist(jj, idcol = "pmid")
  
  # Clean up locations field
  jj0$locations <- as.character(jj0$locations)
  jj0$locations <- gsub("[^[:digit:],]", "", jj0$locations)
  
  # Extract start and end positions
  jj0[, c("start", "length") := data.table::tstrsplit(locations, ",", fixed = TRUE)]
  jj0[, start := as.integer(start)]
  jj0[, end := start + as.integer(length)]
  
  # Remove unnecessary columns
  jj0[, c("length", "locations") := NULL]
  
  Sys.sleep(sleep)
  
  return(jj0)
}

