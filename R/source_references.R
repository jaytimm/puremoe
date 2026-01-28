#' Internal: Extract References from 'PubMed' Records
#'
#' Function queries PubMed to extract reference citations from the fetched records. 
#' It processes XML records to obtain detailed information about references, including citation text and available article identifiers such as PubMed ID, PMC ID, DOI, and ISBN.
#' 
#' @param x A character vector with search terms or IDs for fetching records from 'PubMed'.
#' @param sleep Numeric value indicating time (in seconds) to wait between requests to avoid overwhelming the server.
#' @return A data.table consisting of 'PubMed' IDs, citation text, and available article identifiers (PubMed ID, PMC ID, DOI, ISBN).
#' @importFrom xml2 xml_find_all xml_text xml_attr
#' @importFrom data.table rbindlist
#' @noRd
.get_references <- function(x, sleep) {
  
  # Fetch records from PubMed based on the input x
  records <- .fetch_records(x, sleep)
  
  # Process each PubMed record to extract references
  z <- lapply(records, function(g) {
    
    # Extract the PubMed ID for the main article
    pm <- xml2::xml_text(xml2::xml_find_all(g, ".//MedlineCitation/PMID"))
    
    # Find all reference elements
    refs <- xml2::xml_find_all(g, ".//Reference")
    
    # Process each reference entry
    cache <- lapply(refs, function(k) {
      
      # Extract citation text
      citation <- xml2::xml_text(xml2::xml_find_all(k, ".//Citation"))
      if (length(citation) == 0) citation <- NA
      
      # Extract article identifiers (PMC, PubMed, DOI)
      article_ids <- xml2::xml_find_all(k, ".//ArticleId")
      cited_pmc <- NA
      cited_pmid <- NA
      cited_doi <- NA
      
      # Parse different ID types
      if (length(article_ids) > 0) {
        for (id in article_ids) {
          id_type <- xml2::xml_attr(id, "IdType")
          id_value <- xml2::xml_text(id)
          
          if (id_type == "pmc") {
            cited_pmc <- id_value
          } else if (id_type == "pubmed") {
            cited_pmid <- id_value
          } else if (id_type == "doi") {
            cited_doi <- id_value
          } 
        }
      }
      
      # Create a data frame with extracted reference information
      data.frame(
        pmid = pm,
        citation = citation,
        cited_pmid = cited_pmid,
        cited_pmc = cited_pmc,
        cited_doi = cited_doi
      )
    })
    
    # Combine all references into a single data.table
    data.table::rbindlist(cache, fill = TRUE)
  })
  
  # Combine all records into one data.table
  x0 <- data.table::rbindlist(z, fill = TRUE)
  
  # Return the final data.table with references
  return(x0)
}
