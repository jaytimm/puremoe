#' Expand a PMID Corpus via One-Hop iCite Citation Snowballing
#'
#' Starting from an \code{icites} data.table returned by
#' \code{\link{get_records}(endpoint = "icites")}, follows the citation links
#' already present in the \code{citation_net} column and returns a candidate
#' table. The function does not call iCite again; use
#' \code{\link{get_records}(endpoint = "icites")} explicitly on the returned
#' PMIDs if metadata is needed for the expanded corpus.
#'
#' @param icites A \code{data.table} returned by
#'   \code{get_records(endpoint = "icites")}. Must contain \code{pmid} and
#'   \code{citation_net} columns.
#' @param max_nodes Hard ceiling on the total number of PMIDs in the returned
#'   corpus (seed + discovered). Candidates are filtered by \code{min_links},
#'   ranked by citation-link evidence, and then truncated to the remaining
#'   slots after all seed PMIDs are retained. Publication year is not used for
#'   this cap because \code{citation_snowball()} does not fetch metadata for
#'   newly discovered PMIDs. Default \code{2000}.
#' @param direction One of \code{"both"} (default), \code{"citing"}, or
#'   \code{"cited"}. \code{"cited"} expands to papers referenced by the seeds;
#'   \code{"citing"} expands to papers that cite the seeds;
#'   \code{"both"} combines both directions.
#' @param min_links Minimum number of seed papers a candidate must be linked
#'   to in order to be included. Default \code{2}. Higher values yield a
#'   smaller, more focused expansion.
#'
#' @return A \code{data.table} with one row per seed or candidate PMID.
#'   Columns are \code{pmid}, \code{seed}, \code{cited_links},
#'   \code{citing_links}, and \code{link_count}. \code{cited_links} counts seed
#'   papers that cite the candidate; \code{citing_links} counts seed papers
#'   cited by the candidate.
#'
#' @importFrom data.table setDT rbindlist as.data.table
#' @export
#' @examples
#' \dontrun{
#' pmids <- search_pubmed("metformin AND PCOS [TiAb]")
#'
#' snowball <- pmids |>
#'   get_records(endpoint = "icites") |>
#'   citation_snowball(direction = "cited", min_links = 2)
#'
#' snowball$pmid |> get_records(endpoint = "pubmed_abstracts")
#' }

citation_snowball <- function(icites,
                              max_nodes = 2000,
                              direction = c("both", "citing", "cited"),
                              min_links = 2) {
  N <- NULL
  cited_links <- NULL
  citing_links <- NULL
  link_count <- NULL
  pmid <- NULL
  seed <- NULL
  finalize <- function(x) {
    x[, seed := .as_snowball_logical(seed)]
    x[]
  }

  direction <- match.arg(direction)

  if (!is.data.frame(icites))
    stop("icites must be a data.frame / data.table")
  if (!"pmid" %in% names(icites))
    stop("icites must contain a 'pmid' column")
  if (!"citation_net" %in% names(icites))
    stop("icites must contain a 'citation_net' column; use get_records(endpoint = 'icites')")

  data.table::setDT(icites)
  icites[, pmid := as.character(pmid)]

  seed_pmids <- unique(icites$pmid)
  seed_table <- data.table::data.table(
    pmid = seed_pmids,
    seed = TRUE,
    cited_links = NA_integer_,
    citing_links = NA_integer_,
    link_count = NA_integer_
  )

  citation_net_dt <- data.table::rbindlist(icites$citation_net, fill = TRUE)

  if (nrow(citation_net_dt) == 0L ||
      !all(c("from", "to") %in% names(citation_net_dt))) {
    return(finalize(seed_table))
  }

  citation_net_dt <- citation_net_dt[, .(
    from = as.character(from),
    to   = as.character(to)
  )]
  citation_net_dt <- citation_net_dt[
    !is.na(from) & !is.na(to) &
      grepl("^[0-9]+$", from) &
      grepl("^[0-9]+$", to)
  ]
  if (nrow(citation_net_dt) == 0L) return(finalize(seed_table))

  cited_counts <- citation_net_dt[
    from %in% seed_pmids,
    .(cited_links = .N),
    by = .(pmid = to)
  ]
  citing_counts <- citation_net_dt[
    to %in% seed_pmids,
    .(citing_links = .N),
    by = .(pmid = from)
  ]

  candidates <- merge(cited_counts, citing_counts, by = "pmid", all = TRUE)
  if (nrow(candidates) == 0L) return(finalize(seed_table))

  candidates[is.na(cited_links), cited_links := 0L]
  candidates[is.na(citing_links), citing_links := 0L]
  candidates <- candidates[!pmid %in% seed_pmids]

  if (direction == "cited") {
    candidates[, link_count := cited_links]
  } else if (direction == "citing") {
    candidates[, link_count := citing_links]
  } else {
    candidates[, link_count := cited_links + citing_links]
  }

  candidates <- candidates[link_count >= min_links]
  if (nrow(candidates) == 0L) return(finalize(seed_table))

  remaining <- max_nodes - length(seed_pmids)

  if (remaining <= 0L) return(finalize(seed_table))

  candidates <- candidates[order(-link_count, -cited_links, -citing_links, pmid)]
  if (nrow(candidates) > remaining) {
    candidates <- candidates[seq_len(remaining)]
  }
  candidates[, seed := FALSE]
  candidates <- candidates[, .(pmid, seed, cited_links, citing_links, link_count)]

  finalize(data.table::rbindlist(list(seed_table, candidates), use.names = TRUE))
}

.as_snowball_logical <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  x <- trimws(tolower(as.character(x)))
  out <- rep(NA, length(x))
  out[x %in% c("true", "t", "1", "yes", "y")] <- TRUE
  out[x %in% c("false", "f", "0", "no", "n")] <- FALSE
  out
}
