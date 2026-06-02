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
      source = "PubMed E-utilities",
      input = "PMIDs",
      returns = "data.table; one row per PMID",
      columns = list(
        pmid = "PubMed ID (character)",
        doi = "Digital Object Identifier; NA when unavailable",
        year = "Publication year parsed from PubDate Year or MedlineDate (integer)",
        pubtype = "Publication type values collapsed with ' | ' when multiple are present",
        journal = "Journal title",
        articletitle = "Article title",
        abstract = "Abstract text, with simple section-title line breaks when detected; NA when unavailable",
        annotations = "List-column of PubMed annotations with MeSH descriptors, chemical names, and keywords"
      ),
      parameters = list(
        cores = "parallel workers",
        sleep = "delay between requests, in seconds",
        ncbi_key = "optional NCBI API key passed through get_records()"
      ),
      rate_limit = "NCBI E-utilities: 3/sec without key, 10/sec with key",
      notes = "Primary article-level metadata endpoint. Uses the same PubMed E-utilities source as pubmed_affiliations but returns article-level fields rather than author-affiliation rows."
    ),
    
    pubmed_affiliations = list(
      description = "Author affiliations from PubMed",
      source = "PubMed E-utilities",
      input = "PMIDs",
      returns = "data.table; one row per author-affiliation record",
      columns = list(
        pmid = "PubMed ID (character)",
        Author = "Author name formatted as 'LastName, ForeName'; NA when unavailable",
        Affiliation = "Affiliation text from the PubMed author record; NA when unavailable"
      ),
      parameters = list(
        cores = "parallel workers",
        sleep = "delay between requests, in seconds",
        ncbi_key = "optional NCBI API key passed through get_records()"
      ),
      rate_limit = "NCBI E-utilities: 3/sec without key, 10/sec with key",
      notes = "Uses the same PubMed E-utilities source as pubmed_abstracts but returns author-affiliation rows instead of article-level metadata."
    ),
    
    icites = list(
      description = "NIH iCite citation metrics, influence scores, and citation links",
      source = "NIH iCite",
      input = "PMIDs",
      returns = "data.table; one row per PMID returned by iCite",
      columns = list(
        pmid = "PubMed ID; join key for other puremoe endpoints (character)",
        citation_count = "Total citations received",
        relative_citation_ratio = "Relative Citation Ratio (RCR), rounded to three decimals",
        nih_percentile = "Percentile rank relative to NIH-funded publications",
        field_citation_rate = "Expected citation rate for the article's co-citation field",
        is_research_article = "Flag indicating whether iCite classifies the article as research",
        is_clinical = "Flag indicating whether iCite classifies the article as clinical",
        provisional = "Flag indicating provisional RCR status for recent publications",
        citation_net = "List-column of directed citation edges with 'from' and 'to' PMIDs, built from iCite cited-by and reference fields. Covers PubMed-indexed articles only; citations from preprints or sources outside PubMed are not included.",
        cited_by_clin = "Clinical citing PMIDs as returned by iCite"
      ),
      parameters = list(
        cores = "parallel workers",
        sleep = "delay between requests, in seconds"
      ),
      rate_limit = "Relatively permissive",
      notes = "Title, journal, publication year, authors, and abstracts are intentionally omitted to avoid duplicating pubmed_abstracts metadata. Use citation_net with citation_snowball() or citation_network(). iCite citation links cover PubMed-indexed articles only; citations from preprints or sources outside PubMed are not included."
    ),
    
    pubtations = list(
      description = "PubTator3 named-entity annotations",
      source = "PubTator3 BioC JSON export",
      input = "PMIDs",
      returns = "data.table; one row per title or abstract annotation, including NA placeholder rows when a passage has no annotations",
      columns = list(
        pmid = "PubMed ID (character)",
        tiab = "Passage containing the annotation: 'title' or 'abstract'",
        id = "PubTator annotation ID",
        text = "Annotated text span",
        identifier = "Database identifier supplied by PubTator3; NA when unavailable",
        type = "Entity type supplied by PubTator3, such as Gene, Disease, Chemical, Species, or Mutation",
        start = "Start character offset within the passage",
        end = "End character offset within the passage",
        passage_text = "Full PubTator passage text used for annotation, typically title or abstract text",
        passage_offset = "Start character offset of the PubTator passage within the document"
      ),
      parameters = list(
        cores = "parallel workers",
        sleep = "delay between requests, in seconds"
      ),
      rate_limit = "Moderate",
      notes = "Provides machine annotations over title and abstract text. Annotation coverage and identifiers depend on PubTator3 output for each PMID."
    ),
    
    pmc_fulltext = list(
      description = "Section-level full text from open-access PubMed Central articles",
      source = "PMC Cloud Service XML files",
      input = "HTTPS XML URLs, usually from pmid_to_ftp()$url",
      returns = "data.table; one row per parsed top-level body section",
      columns = list(
        pmid = "PubMed ID extracted from article metadata (character)",
        section = "Top-level body section heading; NA when a section has no title",
        text = "Section text content"
      ),
      parameters = list(
        cores = "parallel workers",
        sleep = "delay between XML downloads, in seconds"
      ),
      rate_limit = "PMC Cloud Service: be respectful; not all PMIDs have open-access XML",
      notes = "Call pmid_to_ftp() first to resolve PMIDs to open-access PMC Cloud Service URLs, then pass the url column to get_records(endpoint = 'pmc_fulltext')."
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
