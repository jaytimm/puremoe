#' Get Information About Available Endpoints
#'
#' This function provides detailed information about the available endpoints
#' in the package, including column descriptions, parameters, rate limits, and usage notes.
#'
#' @param endpoint Character string specifying which endpoint to get information about.
#'   If NULL (default), returns a list of all available endpoints.
#' @param format Character string specifying the output format. Either "list" (default)
#'   or "json" for JSON-formatted output.
#'
#' @return If \code{endpoint} is NULL, returns a character vector of available endpoint names.
#'   If \code{endpoint} is specified, returns a list (or JSON string) with detailed information
#'   about that endpoint including description, columns, parameters, rate limits, and notes.
#'
#' @importFrom jsonlite toJSON
#'
#' @export
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # List all available endpoints
#'   endpoint_info()
#'   
#'   # Get information about a specific endpoint
#'   endpoint_info("pubmed_abstracts")
#'   
#'   # Get information in JSON format
#'   endpoint_info("icites", format = "json")
#' }
#' }
#'
endpoint_info <- function(endpoint = NULL, format = c("list", "json")) {
  format <- match.arg(format)
  
  schemas <- list(
    pubmed_abstracts = list(
      description = "PubMed article metadata and abstracts",
      returns = "data.frame",
      columns = list(
        pmid = "PubMed ID (character)",
        doi = "Digital Object Identifier (character)",
        year = "Publication year (integer)",
        pubtype = "Publication type(s) (character)",
        journal = "Journal name (character)",
        articletitle = "Article title (character)",
        abstract = "Abstract text (character)",
        annotations = "MeSH terms and keywords (list-column)"
      ),
      parameters = list(cores = "parallel workers", sleep = "delay between requests (seconds)"),
      rate_limit = "NCBI E-utilities: 3/sec without key, 10/sec with key",
      notes = "Use ncbi_key for higher rate limits. Primary source of article metadata."
    ),
    
    pubmed_affiliations = list(
      description = "Author affiliations from PubMed",
      returns = "data.frame",
      columns = list(
        pmid = "PubMed ID (character)",
        Author = "Author name (character)",
        Affiliation = "Institutional affiliation (character)"
      ),
      parameters = list(cores = "parallel workers", sleep = "delay between requests"),
      rate_limit = "NCBI E-utilities: 3/sec without key, 10/sec with key",
      notes = "One row per author; multiple affiliations possible"
    ),
    
    icites = list(
      description = "NIH iCite citation metrics and influence scores",
      returns = "data.frame",
      columns = list(
        pmid = "PubMed ID - join key to link with pubmed_abstracts (character)",
        citation_count = "Total citations received (integer)",
        relative_citation_ratio = "RCR: field-adjusted citation rate comparing to NIH baseline (numeric)",
        nih_percentile = "Percentile rank vs NIH-funded publications (numeric)",
        field_citation_rate = "Expected citation rate for article's co-citation field (numeric)",
        is_research_article = "Flag for primary research articles (logical)",
        is_clinical = "Flag for clinical articles (logical)",
        provisional = "Flag indicating RCR is provisional due to recent publication (logical)",
        citation_net = "Citation network edge list: 'from' and 'to' PMIDs within result set (list-column)",
        cited_by_clin = "PMIDs of clinical articles citing this paper (character/list)"
      ),
      parameters = list(cores = "parallel workers", sleep = "delay between requests"),
      rate_limit = "Relatively permissive",
      notes = "Join to pubmed_abstracts on pmid for complete metadata (title, journal, authors, etc. not included to avoid redundancy). citation_net enables intra-corpus network analysis."
    ),
    
    pubtations = list(
      description = "PubTator entity annotations (genes, diseases, chemicals, etc.)",
      returns = "data.frame",
      columns = list(
        pmid = "PubMed ID (character)",
        tiab = "Title/abstract text (character)",
        id = "Annotation ID (character)",
        text = "Annotated text span (character)",
        identifier = "Database identifier (character)",
        type = "Entity type: Gene, Disease, Chemical, Species, Mutation (character)",
        start = "Start position in text (integer)",
        end = "End position in text (integer)"
      ),
      parameters = list(cores = "parallel workers"),
      rate_limit = "Moderate",
      notes = "One row per annotation; multiple annotations per article. Provides named entity recognition output."
    ),
    
    pmc_fulltext = list(
      description = "Full-text articles from PubMed Central",
      returns = "data.frame",
      columns = list(
        pmid = "PubMed ID (character)",
        section = "Section heading (character)",
        text = "Section text content (character)"
      ),
      parameters = list(cores = "parallel workers"),
      input = "Requires FTP URLs from pmid_to_ftp()",
      rate_limit = "NCBI FTP: be respectful",
      notes = "One row per section; use after pmid_to_ftp() to get URLs. Not all PMIDs have PMC full text available."
    )
  )
  
  # Return available endpoints
  if (is.null(endpoint)) {
    result <- names(schemas)
    if (format == "json") {
      return(jsonlite::toJSON(list(available_endpoints = result), 
                              pretty = TRUE, auto_unbox = TRUE))
    }
    return(result)
  }
  
  # Validate endpoint
  if (!endpoint %in% names(schemas)) {
    stop("Unknown endpoint. Available: ", paste(names(schemas), collapse = ", "))
  }
  
  result <- schemas[[endpoint]]
  
  # Return in requested format
  if (format == "json") {
    return(jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE))
  }
  
  result
}
