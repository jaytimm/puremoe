#' Retrieve Data from 'NLM'/'PubMed' databases Based on PMIDs
#'
#' This function retrieves different types of data (like 'PubMed' records, affiliations, 'iCites 'data, etc.) from 'PubMed' based on provided PMIDs. It supports parallel processing for efficiency.
#' 
#' For the 'pmc_fulltext' endpoint, provide full URLs to PMC Cloud Service XML files.
#' Use \code{\link{pmid_to_ftp}} to convert PMIDs to PMC IDs and full-text URLs first.
#' 
#' @param pmids A vector of PMIDs for which data is to be retrieved. For 'pmc_fulltext' endpoint, 
#'   provide full URLs instead (e.g., from \code{pmid_to_ftp()$url}).
#' @param endpoint A character vector specifying the type of data to retrieve ('pubtator', 'pubtations', 'icites',
#'   'pubmed_affiliations', 'pubmed_abstracts', 'pmc_fulltext').
#' @param cores Number of cores to use for parallel processing (default is 3).
#' @param ncbi_key (Optional) NCBI API key for authenticated access.
#' @param sleep Duration (in seconds) to pause after each batch 
#' @param icite_timeout Maximum elapsed seconds to allow each iCite batch before
#'   skipping it and returning PMID-only rows. Defaults to the
#'   \code{puremoe.icite_timeout} option, or 15 seconds if unset.
#' @return A data.table containing combined results from the specified endpoint, except
#'   for the PubTator endpoint, which returns a list with entities and
#'   relations data.tables.
#' @importFrom parallel makeCluster stopCluster detectCores clusterExport
#' @importFrom pbapply pblapply
#' @importFrom data.table rbindlist
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   pmids <- c("38136652")
#'   results <- get_records(pmids, endpoint = "pubmed_abstracts", cores = 1)
#' }
#' }
get_records <- function(pmids,
                        endpoint = c('pubtator',
                                     'pubtations',
                                     'icites',
                                     'pubmed_affiliations',
                                     'pubmed_abstracts',
                                     'pmc_fulltext'),
                        cores = 3, 
                        sleep = 1,
                        ncbi_key = NULL,
                        icite_timeout = getOption("puremoe.icite_timeout", 15)) {
  
  # Input validation
  if (!(is.character(pmids) || is.numeric(pmids)) || length(pmids) == 0) {
    stop("pmids must be a non-empty vector of characters or numbers")
  }
  
  endpoint <- match.arg(endpoint)

  if (endpoint == "pubtations") endpoint <- "pubtator"
  
  if (!is.numeric(cores)) {
    stop("cores must be numeric")
  }
  if (!is.numeric(icite_timeout) || length(icite_timeout) != 1 || is.na(icite_timeout)) {
    stop("icite_timeout must be a single numeric value")
  }
  
  # Set the NCBI API key for authenticated access if provided
  if (!is.null(ncbi_key)) rentrez::set_entrez_key(ncbi_key)
  
  # Define batch size and the specific task function based on the chosen endpoint
  batch_size <- if (endpoint == "pmc_fulltext") {5} else if (endpoint == "pubtator") {99} else {199}
  task_function <- switch(endpoint,
                          "icites" = .get_icites,
                          "pubtator" = .get_pubtator,
                          "pubmed_affiliations" = .get_affiliations,
                          "pubmed_abstracts" = .get_records,
                          "pmc_fulltext" = .get_pmc,
                          ##
                          stop("Invalid endpoint"))
  
  # Split the PMIDs (or PMC IDs/file paths for pmc_fulltext) into batches for parallel processing
  batches <- split(pmids, ceiling(seq_along(pmids) / batch_size))
  run_icites_batch <- .run_icites_batch
  run_records_batch <- function(batch,
                                endpoint,
                                task_function,
                                sleep,
                                batch_index,
                                n_batches,
                                icite_timeout) {
    if (identical(endpoint, "icites")) {
      return(run_icites_batch(
        batch = batch,
        task_function = task_function,
        sleep = sleep,
        batch_index = batch_index,
        n_batches = n_batches,
        icite_timeout = icite_timeout
      ))
    }

    task_function(batch, sleep)
  }
  
  if (cores > 1) {
    
    # Parallel processing: Create a cluster and export necessary variables
    clust <- parallel::makeCluster(cores)
    parallel::clusterExport(cl = clust,
                            varlist = c("batches", "task_function", "endpoint",
                                        "sleep", "icite_timeout",
                                        "run_records_batch",
                                        "run_icites_batch",
                                        ".combine_pubtator_results",
                                        ".empty_pubtator_result",
                                        ".empty_pubtator_entities",
                                        ".empty_pubtator_relations",
                                        ".null_or",
                                        ".parse_pubtator_payload",
                                        ".pubtator_location",
                                        ".pubtator_passage_type"),
                            envir = environment())
    
    # Apply the task function to each batch with the sleep parameter, using parallel processing
    results <- pbapply::pblapply(X = seq_along(batches),
                                 FUN = function(i) {
                                   run_records_batch(
                                     batch = batches[[i]],
                                     endpoint = endpoint,
                                     task_function = task_function,
                                     sleep = sleep,
                                     batch_index = i,
                                     n_batches = length(batches),
                                     icite_timeout = icite_timeout
                                   )
                                 },
                                 cl = clust)
    parallel::stopCluster(clust)  # Stop the cluster after processing
  } else {
    
    # Sequential processing: Apply the task function to each batch with the sleep parameter
    results <- lapply(seq_along(batches), function(i) {
      run_records_batch(
        batch = batches[[i]],
        endpoint = endpoint,
        task_function = task_function,
        sleep = sleep,
        batch_index = i,
        n_batches = length(batches),
        icite_timeout = icite_timeout
      )
    })
  }
  
  if (endpoint == "pubtator") {
    return(.combine_pubtator_results(results))
  }
  
  df_only_list <- results[sapply(results, is.data.frame)]
  # Combine results from all batches into a single data.table
  # Use fill=TRUE to handle cases where batches have different columns
  combined_results <- data.table::rbindlist(df_only_list, fill = TRUE)
  if ("pmid" %in% names(combined_results)) {
    combined_results[, pmid := as.character(pmid)]
  }
  if ("year" %in% names(combined_results)) {
    combined_results[, year := suppressWarnings(as.integer(year))]
  }
  return(combined_results)
}

.run_icites_batch <- function(batch,
                              task_function,
                              sleep,
                              batch_index,
                              n_batches,
                              icite_timeout) {
  citation_net <- icite_note <- NULL
  batch <- as.character(batch)
  n_pmids <- length(batch)
  placeholder <- function(pmids, note) {
    out <- data.table::data.table(pmid = as.character(pmids))
    empty_net <- data.table::data.table(from = character(), to = character())
    out[, citation_net := replicate(.N, empty_net, simplify = FALSE)]
    out[, icite_note := note]
    out
  }

  run_batch <- function() task_function(batch, sleep)

  if (.Platform$OS.type == "unix" && is.finite(icite_timeout) && icite_timeout > 0) {
    job <- parallel::mcparallel(run_batch(), silent = TRUE)
    start <- Sys.time()
    result <- NULL

    repeat {
      result <- parallel::mccollect(job, wait = FALSE)
      if (!is.null(result)) {
        break
      }
      if (as.numeric(difftime(Sys.time(), start, units = "secs")) >= icite_timeout) {
        try(tools::pskill(job$pid, tools::SIGKILL), silent = TRUE)
        try(parallel::mccollect(job, wait = FALSE), silent = TRUE)
        message(sprintf(
          "iCite batch %d/%d skipped after %s seconds; returning PMID-only rows for %d PMIDs.",
          batch_index, n_batches, icite_timeout, n_pmids
        ))
        return(placeholder(
          batch,
          sprintf("iCite batch %d/%d skipped after %s seconds; returning PMID-only rows.", batch_index, n_batches, icite_timeout)
        ))
      }
      Sys.sleep(0.1)
    }

    result <- result[[1]]
  } else {
    result <- try(run_batch(), silent = TRUE)
  }

  if (inherits(result, "try-error") || is.null(result) || !is.data.frame(result)) {
    message(sprintf(
      "iCite batch %d/%d skipped after an error; returning PMID-only rows for %d PMIDs.",
      batch_index, n_batches, n_pmids
    ))
    return(placeholder(
      batch,
      sprintf("iCite batch %d/%d skipped after an error; returning PMID-only rows.", batch_index, n_batches)
    ))
  }

  if (!"citation_net" %in% names(result)) {
    result$icite_note <- sprintf(
      "iCite batch %d/%d returned %d records, but no citation_net column was available.",
      batch_index, n_batches, nrow(result)
    )
  } else {
    edge_counts <- vapply(result$citation_net, function(x) {
      if (is.null(x)) {
        return(0L)
      }
      n <- tryCatch(nrow(x), error = function(e) 0L)
      if (length(n) == 0L || is.na(n)) {
        return(0L)
      }
      as.integer(n)
    }, integer(1))
    if (length(edge_counts) > 0L && all(edge_counts == 0L)) {
      result$icite_note <- sprintf(
        "iCite batch %d/%d returned %d records, but citation_net is empty for all records.",
        batch_index, n_batches, nrow(result)
      )
    }
  }

  result
}
