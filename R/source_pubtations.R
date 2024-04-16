#' Extract Named Entities from 'PubMed''s 'PubTator3' Tool
#'
#' This function retrieves named entity annotations from 'PubMed''s 'PubTator3' tool. It fetches data using 'PubMed' IDs and processes the JSON response into a structured format.
#' @param x A vector of 'PubMed' IDs for which annotations are to be retrieved from 'PubTator'.
#' @return A data.table, or NA if no data is available, with columns for 'PubMed' ID, title or abstract location, annotation text, start and end positions of annotations, and annotation types.
#' @importFrom jsonlite stream_in
#' @importFrom data.table rbindlist
#' @noRd
#' 
.get_pubtations <- function(x, sleep){
  
  # x <- batches[[3]]
  # https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocxml?pmids=29355051&full=true
  
  # Connect to PubTator API and retrieve data
  # con <- url(paste0("https://www.ncbi.nlm.nih.gov/research/pubtator-api/publications/export/biocjson?pmids=", paste(x, collapse = ',')))
  
  con <- url(paste0("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson?pmids=", paste(x, collapse = ',')))
  
  # Read JSON data stream, handling errors with NA
  # mydata <- tryCatch(jsonlite::stream_in(gzcon(con)), error = function(e) NA)  
  mydata <- tryCatch(
    jsonlite::stream_in(con), 
    error = function(e) NA)  

  
  # Process the data if valid, else return NA
  # i = 1
  if(length(mydata) == 1){jj0 <- NA} else{
    jj <- list()
    
    # Iterate over each record to extract and format annotations
    for(i in 1:nrow(mydata)){
      
      # Extract annotations for titles and abstracts
      pb1 <- mydata$passages[[i]]$annotations
      names(pb1) <- c('title', 'abstract')
      
      # Process title annotations
      if(any(nrow(pb1$title) == 0, is.null(nrow(pb1$title)))) {
        pb1$title <- data.frame(tiab = 'title', 
                                id = NA,
                                text = NA, 
                                locations = NA, 
                                identifier = NA, 
                                type = NA)
      } else{
        
        if (!("identifier" %in% names(pb1[["title"]]$infons))) {
          pb1[["title"]]$infons$identifier <- NA
        }
        
        pb1$title <- cbind(tiab = 'title', 
                           pb1$title[, c('id', 'text', 'locations')], 
                           identifier = pb1$title$infons$identifier, 
                           type = pb1$title$infons$type)
      }
      
      # Process abstract annotations
      if(any(nrow(pb1$abstract) == 0, is.null(nrow(pb1$abstract)))) {
        pb1$abstract <- data.frame(tiab = 'abstract', 
                                   id = NA, 
                                   text = NA, 
                                   locations = NA, 
                                   identifier = NA, 
                                   type = NA)
      } else{
        
        if (!("identifier" %in% names(pb1[["abstract"]]$infons))) {
          pb1[["abstract"]]$infons$identifier <- NA
        }
        
        pb1$abstract <- cbind(tiab = 'abstract', 
                              pb1$abstract[, c('id', 'text', 'locations')], 
                              identifier = pb1$abstract$infons$identifier, 
                              type = pb1$abstract$infons$type)
      }
      
      # Combine title and abstract annotations
      jj[[i]] <- rbind(pb1$title, pb1$abstract)
    }
    
    
    if (!all(sapply(jj, is.data.frame))) {
      return(NA)  
    } else {

      names(jj) <- mydata$id
      jj0 <- jj |> data.table::rbindlist(idcol = 'pmid')
      # ... rest of the processing ...
    }
    
    
    # Clean and format location data
    jj0$locations <- jj0$locations |> as.character()
    jj0$locations <- gsub("[^[:digit:],]", "", jj0$locations)
    
    # Extract start and end positions of annotations
    start <- NULL
    end <- NULL
    locations <- NULL
    jj0[, c('start', 'length') := data.table::tstrsplit(locations, ",", fixed=TRUE)]
    jj0[, start := as.integer(start)]
    jj0[, end := start + as.integer(length)]
    
    # Clean up temporary columns
    jj0[, length := NULL]
    jj0[, locations := NULL]
  }
  
  Sys.sleep(sleep)
  
  # Return the processed annotations data
  return(jj0)
}
