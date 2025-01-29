#' Search 'PubMed' Records
#'
#' Performs a 'PubMed' search based on a query, optionally filtered by publication years. 
#' Returns a unique set of 'PubMed' IDs matching the query.
#'
#' @param x Character string, the search query.
#' @param start_year Integer, the start year of publication date range (used if `use_pub_years` is TRUE).
#' @param end_year Integer, the end year of publication date range (used if `use_pub_years` is TRUE).
#' @param retmax Integer, maximum number of records to retrieve, defaults to 9999.
#' @param use_pub_years Logical, whether to filter search by publication years, defaults to TRUE.
#' @return Numeric vector of unique PubMed IDs.
#' @importFrom rentrez entrez_search
#' @export
#' @examples
#' ethnob1 <- search_pubmed("ethnobotany", 2010, 2012)
#' 
#' 
search_pubmed <- function(x, 
                          start_year = NULL, 
                          end_year = NULL, 
                          retmax = 9999, 
                          use_pub_years = FALSE) {
  
  if(!is.character(x) || length(x) != 1) {
    stop("x must be a single character string.")
  }
  
  if(use_pub_years) {
    if(is.null(start_year) || is.null(end_year)) {
      stop("start_year and end_year must be provided when use_pub_years is TRUE.")
    }
    if(!is.numeric(start_year) || !is.numeric(end_year) || length(start_year) != 1 || length(end_year) != 1) {
      stop("start_year and end_year must be single integers.")
    }
    if(start_year > end_year) {
      stop("start_year must be less than or equal to end_year.")
    }
    
    all_ids <- vector("list", length = end_year - start_year + 1)
    names(all_ids) <- as.character(start_year:end_year)
    
    for (year in start_year:end_year) {
      query <- paste0(x, " AND ", year, "[Pub Date]")
      all_ids[[as.character(year)]] <- .perform_search(query, retmax)
    }
  } else {
    all_ids <- list(all_years = .perform_search(x, retmax))
  }
  
  return(unique(unlist(all_ids, use.names = FALSE)))
}

#' Internal Function for PubMed Search
#'
#' Handles querying of the PubMed database and returns search results.
#' This function is used internally by 'search_pubmed'.
#'
#' @param query Character string containing the PubMed search query.
#' @param retmax Integer specifying the maximum number of records to retrieve.
#' @noRd
.perform_search <- function(query, retmax) {
  tryCatch({
    result <- rentrez::entrez_search(db = "pubmed", term = query, retmax = retmax, use_history = TRUE)
    if (result$count > 0) {
      return(result$ids)
    } else {
      return(NULL)
    }
  }, error = function(e) {
    warning(sprintf("Failed to retrieve data for query '%s': %s", query, e$message))
    return(NULL)
  })
  Sys.sleep(0.5)
}
