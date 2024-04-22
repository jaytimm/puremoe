#' Retrieve Data from 'NLM'/'PubMed' databases Based on PMIDs
#'
#' This function retrieves different types of data (like 'PubMed' records, affiliations, 'iCites 'data, etc.) from 'PubMed' based on provided PMIDs. It supports parallel processing for efficiency.
#' @param pmids A vector of PMIDs for which data is to be retrieved.
#' @param endpoint A character vector specifying the type of data to retrieve ('pubtations', 'icites', 'affiliations', 'pubmed', 'pmc').
#' @param cores Number of cores to use for parallel processing (default is 3).
#' @param ncbi_key (Optional) NCBI API key for authenticated access.
#' @param sleep Duration (in seconds) to pause after each batch 
#' @return A data.table containing combined results from the specified endpoint.
#' @importFrom parallel makeCluster stopCluster detectCores clusterExport
#' @importFrom pbapply pblapply
#' @importFrom data.table rbindlist
#' @export
#' @examples
#' pmids <- c("38136652", "31345328", "32496629")
#' results <- get_records(pmids, endpoint = "pubmed_abstracts", cores = 1)
#' 
get_records <- function(pmids, 
                        endpoint = c('pubtations', 
                                     'icites', 
                                     'pubmed_affiliations', 
                                     'pubmed_abstracts', 
                                     'pmc'), 
                        cores = 3, 
                        sleep = 1,
                        ncbi_key = NULL) {
  
  # Input validation
  if (!(is.character(pmids) || is.numeric(pmids)) || length(pmids) == 0) {
    stop("pmids must be a non-empty vector of characters or numbers")
  }
  
  if (!is.character(endpoint) || length(endpoint) != 1 || 
      !endpoint %in% c('pubtations', 'icites', 'pubmed_affiliations', 'pubmed_abstracts', 'pmc')) {
    stop("Invalid endpoint. Must be one of 'pubtations', 'icites', 'pubmed_affiliations', 'pubmed_abstracts', 'pmc'")
  }
  
  if (!is.numeric(cores)) {
    stop("cores must be numeric")
  }
  
  # Set the NCBI API key for authenticated access if provided
  if (!is.null(ncbi_key)) rentrez::set_entrez_key(ncbi_key)
  
  
  # Define batch size and the specific task function based on the chosen endpoint
  batch_size <- if (endpoint == "pmc") {5} else if (endpoint == "pubtations") {99} else {199}
  task_function <- switch(endpoint,
                          "icites" = .get_icites,
                          "pubtations" = .get_pubtations,
                          "pubmed_affiliations" = .get_affiliations,
                          "pubmed_abstracts" = .get_records,
                          "pmc" = .get_pmc,
                          ##
                          stop("Invalid endpoint"))
  
  # Split the PMIDs into batches for parallel processing
  batches <- split(pmids, ceiling(seq_along(pmids) / batch_size))
  
  if (cores > 1) {
    
    # Parallel processing: Create a cluster and export necessary variables
    clust <- parallel::makeCluster(cores)
    parallel::clusterExport(cl = clust, 
                            varlist = c("task_function", "sleep"), 
                            envir = environment())
    
    # Apply the task function to each batch with the sleep parameter, using parallel processing
    results <- pbapply::pblapply(X = batches, 
                                 FUN = function(batch) task_function(batch, sleep), 
                                 cl = clust)
    parallel::stopCluster(clust)  # Stop the cluster after processing
  } else {
    
    # Sequential processing: Apply the task function to each batch with the sleep parameter
    results <- lapply(batches, function(batch) task_function(batch, sleep))
  }
  
  df_only_list <- results[sapply(results, is.data.frame)]
  # Combine results from all batches into a single data.table
  combined_results <- data.table::rbindlist(df_only_list)
  return(combined_results)
}
