#' Scrape Full Text Entries from 'PubMed Central' (PMC)
#'
#' This function retrieves full-text articles from 'PMC' using provided 'PMC' identifiers. It downloads and parses XML files to extract article sections and their corresponding text.
#' @param x A vector of 'PMC' identifiers for which full-text articles are to be retrieved.
#' @return A data.table with columns for document ID, 'PMC' identifier, section titles, and text content of each section.
#' @importFrom xml2 read_xml xml_children xml_find_first xml_text
#' @importFrom utils untar
#' @noRd
#' 
#' 
.get_pmc <- function(x, sleep) {
  
  # Initialize an empty list to store the scraped data
  flist <- list()
  
  # Loop over each PMC identifier
  for(q in 1:length(x)){
    
    # Construct the file URL for the given PMC identifier
    fn <- paste0('https://ftp.ncbi.nlm.nih.gov/pub/pmc/', x[q])
    
    # Create a temporary file to store the downloaded content
    tmp <- tempfile()
    
    # Try to download the file, handling errors gracefully
    dd <- tryCatch(download.file(fn, destfile = tmp), 
                   error = function(e) 'error')  
    
    # If download is successful, proceed with extraction
    if(dd != 'error'){
      
      # Find XML files in the downloaded content
      xmls <- grep('xml$', utils::untar(tmp, list = TRUE), value = TRUE)
      
      # Extract the XML files to a temporary directory
      untar(tmp, files = xmls, exdir = tempdir())
      
      # Read the first XML file
      x0 <- xml2::read_xml(paste0(tempdir(), '/', xmls)[1])
      pmid <- pmid_value <- xml2::xml_find_first(x0, ".//article-meta//article-id[@pub-id-type='pmid']") |>
        xml2::xml_text()

      
      # Check if there are multiple children nodes in the XML
      if(length(xml2::xml_children(x0)) > 1){
        
        # Extract the second child node (assuming it contains the relevant content)
        x1 <- xml2::xml_child(x0, 2)            
        
        # Extract titles of different sections in the article
        header_titles <- lapply(xml2::xml_children(x1),
                                function(x) {
                                  xml2::xml_text(xml2::xml_find_first(x, ".//title"))}
        )
        
        # Extract the text of each section
        text <- lapply(xml2::xml_children(x1), xml2::xml_text)
        
        # Unlist the section titles
        section <- unlist(header_titles)
        
        # Combine the data into a data frame
        df <- data.frame(pmid, 
                         section,
                         text = unlist(text),
                         row.names = NULL)
        
        # Format the text for readability
        df$text <- gsub('([a-z]+)([A-Z])', '\\1\n\\2', df$text)
        
        # Add the data frame to the list
        flist[[q]] <- df
      }
    }
    Sys.sleep(sleep)
  }
  
  # Combine all data frames into one data.table and return
  return(flist |> data.table::rbindlist())
}
