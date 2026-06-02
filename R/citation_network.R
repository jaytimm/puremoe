#' Build a Citation Network from an iCite Corpus
#'
#' Converts an \code{icites} data.table into a tidy graph representation
#' (nodes + edges) suitable for \pkg{igraph} or \pkg{tidygraph}. Only edges
#' where \emph{both} endpoints are present in the corpus are retained, so the
#' graph is bounded to the papers you already have metadata for.
#'
#' RCR and \code{is_clinical} are carried as node attributes, making the
#' resulting graph immediately weighted by field-normalized impact and enabling
#' bench-to-bedside edge filtering without any additional API calls.
#'
#' @param icites A \code{data.table} returned by
#'   \code{\link{get_records}(endpoint = "icites")}. Must contain \code{pmid}
#'   and \code{citation_net} columns.
#'
#' @return A named list with two \code{data.table}s:
#'   \describe{
#'     \item{\code{nodes}}{One row per PMID. Contains all iCite metadata
#'       columns except \code{citation_net}. Key columns: \code{pmid},
#'       \code{relative_citation_ratio}, \code{nih_percentile},
#'       \code{is_clinical}.}
#'     \item{\code{edges}}{One row per within-corpus directed citation.
#'       Columns: \code{from_pmid} (the citing paper),
#'       \code{to_pmid} (the cited paper).}
#'   }
#'
#' @importFrom data.table setDT as.data.table rbindlist
#' @export
#' @examples
#' \dontrun{
#' # network from a seed corpus
#' pmids |>
#'   get_records(endpoint = "icites") |>
#'   citation_network()
#'
#' # expand first, then fetch iCite metadata for the full network
#' snowball <- pmids |>
#'   get_records(endpoint = "icites") |>
#'   citation_snowball()
#'
#' snowball$pmid |>
#'   get_records(endpoint = "icites") |>
#'   citation_network()
#'
#' # translational footprint: filter to bench -> clinical edges
#' snowball <- pmids |>
#'   get_records(endpoint = "icites") |>
#'   citation_snowball()
#'
#' net <- snowball$pmid |>
#'   get_records(endpoint = "icites") |>
#'   citation_network()
#'
#' clinical_edges <- net$edges |>
#'   merge(net$nodes[, .(pmid, is_clinical)],
#'         by.x = "to_pmid", by.y = "pmid") |>
#'   subset(is_clinical == TRUE)
#' }
citation_network <- function(icites) {

  if (!is.data.frame(icites))
    stop("icites must be a data.frame / data.table")
  if (!"pmid" %in% names(icites))
    stop("icites must contain a 'pmid' column")
  if (!"citation_net" %in% names(icites))
    stop("icites must contain a 'citation_net' column; use get_records(endpoint = 'icites')")

  data.table::setDT(icites)
  icites[, pmid := as.character(pmid)]

  corpus_pmids <- unique(icites$pmid)

  # --- nodes: all iCite metadata, without the list-column ------------------
  node_cols <- setdiff(names(icites), "citation_net")
  nodes     <- icites[, .SD, .SDcols = node_cols]

  # --- edges: within-corpus directed citations only ------------------------
  edge_list <- lapply(seq_len(nrow(icites)), function(i) {
    net <- icites$citation_net[[i]]
    if (is.null(net) || !is.data.frame(net) || nrow(net) == 0) return(NULL)
    net_dt <- data.table::as.data.table(net)
    net_dt[, from := as.character(from)]
    net_dt[, to   := as.character(to)]
    net_dt <- net_dt[
      !is.na(from) & !is.na(to) &
      from %in% corpus_pmids &
      to   %in% corpus_pmids
    ]
    if (nrow(net_dt) == 0) return(NULL)
    net_dt[, .(from_pmid = from, to_pmid = to)]
  })

  edges <- data.table::rbindlist(edge_list)
  if (nrow(edges) > 0) edges <- unique(edges)

  list(nodes = nodes[], edges = edges[])
}
