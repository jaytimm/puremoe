#' Internal: Fetch Data from iCite Database
#'
#' This internal function is designed to scrape data from the iCite database, a bibliometric tool provided by the NIH. It constructs a URL to query iCite with specified PubMed IDs and retrieves citation metrics and other related data.
#' @param x A vector of PubMed IDs for which data is to be fetched from the iCite database.
#' @return A data.frame consisting of the data retrieved from iCite, formatted as CSV.
#' @importFrom httr GET content
#' @importFrom utils read.csv
#' @noRd
#' 

.fetch_icites <- function(x, sleep){
  
  # Construct the URL for the iCite API call, including the PubMed IDs (x)
  url0 <- httr::GET(paste0("https://icite.od.nih.gov/api/pubs?pmids=",
                           paste(x, collapse = ","),
                           "&format=csv"))
  
  # Note: There is no error handling here, which could be a point of improvement.
  
  # Read the content of the response as a CSV.
  csv_ <- utils::read.csv(textConnection(
    httr::content(url0,
                  "text",
                  encoding = "UTF-8")),
    encoding = "UTF-8")
  
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
.get_icites <- function(x, sleep){
  
  # Fetch data from iCite using the PubMed IDs provided
  pmiddf <- .fetch_icites(x, sleep)
  
  # Extract the PubMed IDs for reference
  gots <- pmiddf$pmid
  
  # Convert pmiddf to a data.table for efficient data manipulation
  data.table::setDT(pmiddf)
  
  # Clean and format the 'ref_count' column
  ref_count <- NULL
  pmiddf[, ref_count := ifelse(is.null(references)|is.na(references), NULL, references)]
  
  # Process 'references' and 'cited_by' columns, handling empty or NA values
  pmiddf[, references := ifelse(nchar(references) == 0|is.na(references), '99', references)]
  pmiddf[, cited_by := ifelse(nchar(cited_by) == 0|is.na(cited_by), '99', cited_by)]
  
  # Split the 'cited_by' and 'references' columns into lists
  cited_by <- strsplit(pmiddf$cited_by, split = " ")
  references <- strsplit(pmiddf$references, split = " ")
  rs <- strsplit(pmiddf$ref_count, split = " ")
  
  # Build a data frame for references
  doc_id <- NULL
  from <- NULL
  refs <- data.table::data.table(doc_id = rep(gots, sapply(references, length)),
                                 from = rep(gots, sapply(references, length)),
                                 to = unlist(references))
  # Replace placeholder '99' with NA
  refs[refs == 99] <- NA
  
  # Aggregate reference data and convert to a data.table
  refs0 <- refs[, list(references = .N), by = list(from)]
  
  # Build a data frame for cited_by data
  cited <- data.frame(doc_id = rep(gots, sapply(cited_by, length)),
                      from = unlist(cited_by),
                      to = rep(gots, sapply(cited_by, length)))
  # Replace placeholder '99' with NA
  cited[cited == 99] <- NA
  
  # Combine references and cited_by data
  f1 <- rbind(refs, cited)
  # Aggregate the combined data and format as a list within a data.table
  f2 <- data.table::setDT(f1)[, list(references = list(.SD)), by = doc_id]
  
  # Add citation network data to pmiddf
  citation_net <- NULL
  pmiddf[, citation_net := f2$references]
  # Calculate and add reference count
  pmiddf[, ref_count := sapply(rs, length)]
  # Remove the original 'cited_by' and 'references' columns
  pmiddf[, c('cited_by', 'references') := NULL]
  
  # Return the processed data table
  pmiddf[, c(1, 6:25)]
}

