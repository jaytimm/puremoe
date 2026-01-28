#' Scrape Full Text Entries from 'PubMed Central' (PMC)
#'
#' This function retrieves full-text articles from 'PMC' using provided full URLs.
#' It downloads and parses XML files to extract article sections and their corresponding text.
#' @param x A vector of full URLs to PMC tar.gz files (e.g., from \code{\link{pmid_to_pmc}}).
#' @return A data.table with columns for document ID, 'PMC' identifier, section titles, 
#'   and text content of each section.
#' @importFrom xml2 read_xml xml_children xml_find_first xml_text
#' @importFrom utils untar
#' @noRd
#' 
#' 
.get_pmc <- function(x, sleep) {
  
  # Initialize an empty list to store the scraped data
  flist <- list()
  
  # Loop over each URL
  for(q in 1:length(x)){
    
    # Use the URL directly (should be full URL from pmid_to_pmc)
    fn <- x[q]
    
    # Create a temporary file to store the downloaded content
    tmp <- tempfile()
    
    # Try to download the file, handling errors gracefully
    dd <- .safe_download(fn, tmp, mode = "wb")
    
    # If download is successful (returns 0), proceed with extraction
    if(!is.null(dd) && dd == 0){
      
      # Find XML files in the downloaded content
      xmls <- grep('xml$', utils::untar(tmp, list = TRUE), value = TRUE)
      
      if (length(xmls) > 0) {
        # Extract the XML files to a temporary directory
        untar(tmp, files = xmls, exdir = tempdir())
        
        # Construct the full path to the first XML file (preserving directory structure)
        xml_path <- file.path(tempdir(), xmls[1])
        
        # Read the first XML file
        x0 <- xml2::read_xml(xml_path)
        pmid <- pmid_value <- xml2::xml_text(xml2::xml_find_first(x0, ".//article-meta//article-id[@pub-id-type='pmid']"))

        # Find the body element
        body <- xml2::xml_find_first(x0, ".//body")
        
        if (!is.null(body) && length(body) > 0) {
          # Find all top-level sec elements within body
          secs <- xml2::xml_find_all(body, "./sec")
          
          if (length(secs) > 0) {
            # Extract titles and text from each section
            header_titles <- lapply(secs, function(sec) {
              title_node <- xml2::xml_find_first(sec, "./title")
              if (length(title_node) > 0) {
                xml2::xml_text(title_node)
              } else {
                NA_character_
              }
            })
            
            # Extract the text of each section (all text content within the sec element)
            text <- lapply(secs, xml2::xml_text)
            
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
      }
    }
    Sys.sleep(sleep)
  }
  
  # Combine all data frames into one data.table and return
  return(data.table::rbindlist(flist))
}
