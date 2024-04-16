#' Internal: Extract Author Affiliations from PubMed Records
#'
#' Function queries PubMed to extract author affiliations from the fetched records. It processes XML records to obtain detailed information about authors, including their names and affiliations.
#' @param x A character vector with search terms or IDs for fetching records from PubMed.
#' @return A data.table consisting of PubMed IDs, author names, and their affiliations.
#' @importFrom xml2 xml_find_all xml_text
#' @importFrom data.table rbindlist
#' @noRd
#' 
#' 
.get_affiliations <- function (x, sleep) {
  
  # Fetch records from PubMed based on the input x
  records <- .fetch_records(x, sleep)
  
  # Process each PubMed record to extract author affiliations
  z <- lapply(records, function(g){
    
    # Extract the PubMed ID from the record
    pm <- xml2::xml_text(xml2::xml_find_all(g, ".//MedlineCitation/PMID"))
    
    # Find all author elements in the record
    auts <- xml2::xml_find_all(g, ".//Author")
    
    # Process each author element
    cache <- lapply(auts, function(k){
      # Extract and concatenate the last name and first name of the author
      Author <- paste(
        xml2::xml_text(xml2::xml_find_all(k, ".//LastName")),
        xml2::xml_text(xml2::xml_find_all(k, ".//ForeName")),
        sep = ', ')
      
      # Handle cases where the author name is missing
      if(length(Author) == 0){Author <- NA}
      
      # Extract the affiliation information of the author
      Affiliation <- xml2::xml_text(xml2::xml_find_all(k,  ".//Affiliation"))
      
      # Handle cases where the affiliation is missing
      if(length(Affiliation) == 0){Affiliation <- NA}
      
      # Create a data frame with PubMed ID, Author name, and Affiliation
      data.frame(pmid = pm, Author, Affiliation)
    })
    
    # Combine all author information into a single data.table
    data.table::rbindlist(cache)
  })
  
  # Combine all records into one data.table
  x0 <- data.table::rbindlist(z)
  
  # Return the final data.table with author affiliations
  return(x0)
}



# #### clean -- 
# .clean_affiliations <- function(x){
#   
#   x[, Affiliation := sub('^.*?([A-Z])','\\1', Affiliation)]
#   x[, Affiliation := trimws(Affiliation)]
#   x[, Affiliation := gsub('(^.*[[:punct:] ])(.*@.*$)', '\\1', Affiliation)]
#   x[, Affiliation := gsub('(^.*[[:punct:] ])(.*@.*$)', '\\1', Affiliation)]
#   x[, Affiliation := gsub('electronic address.*$|email.*$', '', Affiliation, ignore.case = T)]
#   x[, Affiliation := ifelse(nchar(Affiliation) < 10, NA, Affiliation)]
#   return(x)
# }
