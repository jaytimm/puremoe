#' Build a PubTator Relation Network with Evidence
#'
#' Converts a \code{\link{pubtator_context}} result into a relation network:
#' graph-ready \code{nodes} and \code{edges}, plus a lean \code{evidence}
#' table that maps each edge back to the PubTator relation row and, when the
#' endpoint mentions share a sentence, the supporting sentence.
#'
#' @param x A list returned by \code{\link{pubtator_context}}, with
#'   \code{entities}, \code{relations}, and \code{sentences} data.tables.
#'
#' @return A named list with three \code{data.table}s:
#'   \describe{
#'     \item{\code{nodes}}{One row per normalized relation endpoint. Columns:
#'       \code{id}, \code{type}, \code{label}, \code{n_mentions}, and
#'       \code{n_pmids}. Entity identifiers are used when present; otherwise
#'       nodes fall back to \code{type:text}.}
#'     \item{\code{edges}}{One row per directed PubTator relation edge. Columns:
#'       \code{from}, \code{to}, \code{relation_type}, \code{weight},
#'       \code{n_pmids}, and \code{n_sentences}.}
#'     \item{\code{evidence}}{One row per PubTator relation row. Columns:
#'       \code{from}, \code{to}, \code{relation_type}, \code{pmid},
#'       \code{relation_id}, \code{same_sentence}, \code{sentence_distance},
#'       and \code{sentence}. The sentence is populated only when the relation
#'       endpoints share a sentence.}
#'   }
#'
#' @seealso \code{\link{pubtator_context}}, \code{\link{pubtator_cooccurrence}}
#' @importFrom data.table as.data.table copy fifelse uniqueN setorder setcolorder
#' @export
#' @examples
#' \dontrun{
#' pmids <- search_pubmed('"doxorubicin"[TiAb] AND "cardiotoxicity"[TiAb]')
#'
#' ctx <- pmids |>
#'   get_records(endpoint = "pubtator") |>
#'   pubtator_context()
#'
#' net <- pubtator_network(ctx)
#' net$nodes
#' net$edges
#' net$evidence
#' }
pubtator_network <- function(x) {
  .pn_validate_context(x)

  evidence <- .pn_evidence(x)
  edges <- .pn_edges(evidence)
  nodes <- .pn_nodes(x$entities, edges)

  list(nodes = nodes[], edges = edges[], evidence = evidence[])
}

# Node id: identifier when present, else a type-scoped surface form so that
# distinct entity types sharing a text string do not collapse into one node.
#' @noRd
.pn_node_id <- function(type, identifier, text) {
  data.table::fifelse(
    !is.na(identifier) & nzchar(as.character(identifier)),
    as.character(identifier),
    paste(as.character(type), as.character(text), sep = ":")
  )
}

#' @noRd
.pn_validate_context <- function(x) {
  if (!is.list(x) || !all(c("entities", "relations", "sentences") %in% names(x))) {
    stop("x must be a pubtator_context() result with entities, relations, and sentences")
  }
  if (!is.data.frame(x$entities) || !is.data.frame(x$relations) ||
      !is.data.frame(x$sentences)) {
    stop("x$entities, x$relations, and x$sentences must be data.frames")
  }

  required_rel <- c("pmid", "relation_id", "relation_type",
                    "ent1_type", "ent1_identifier", "ent1_text",
                    "ent1_tiab", "ent1_sentence_id",
                    "ent2_type", "ent2_identifier", "ent2_text",
                    "ent2_tiab", "ent2_sentence_id",
                    "same_sentence", "sentence_distance")
  if (!all(required_rel %in% names(x$relations))) {
    stop("x$relations is missing context columns; run pubtator_context() first")
  }

  required_sent <- c("pmid", "tiab", "sentence_id", "sentence")
  if (!all(required_sent %in% names(x$sentences))) {
    stop("x$sentences is missing required sentence columns")
  }

  invisible(TRUE)
}

#' @noRd
.pn_evidence <- function(x) {
  pmid <- relation_id <- relation_type <- sentence <- NULL
  ent1_type <- ent1_identifier <- ent1_text <- ent1_tiab <- ent1_sentence_id <- NULL
  ent2_type <- ent2_identifier <- ent2_text <- ent2_tiab <- ent2_sentence_id <- NULL
  same_sentence <- sentence_distance <- from <- to <- NULL

  rel <- data.table::copy(data.table::as.data.table(x$relations))
  rel <- rel[!is.na(relation_type) & nzchar(as.character(relation_type))]
  if (nrow(rel) == 0L) return(.pn_evidence_empty())

  rel[, `:=`(
    from = .pn_node_id(ent1_type, ent1_identifier, ent1_text),
    to = .pn_node_id(ent2_type, ent2_identifier, ent2_text),
    pmid = as.character(pmid),
    relation_type = as.character(relation_type),
    same_sentence = as.logical(same_sentence),
    sentence_distance = as.integer(sentence_distance)
  )]

  sent <- data.table::as.data.table(x$sentences)
  sent <- unique(sent[, .(
    pmid = as.character(pmid),
    tiab = as.character(tiab),
    sentence_id = as.integer(sentence_id),
    sentence = as.character(sentence)
  )])

  rel <- merge(
    rel,
    sent,
    by.x = c("pmid", "ent1_tiab", "ent1_sentence_id"),
    by.y = c("pmid", "tiab", "sentence_id"),
    all.x = TRUE,
    sort = FALSE
  )
  rel[is.na(same_sentence) | !same_sentence, sentence := NA_character_]

  out <- rel[, .(
    from,
    to,
    relation_type,
    pmid,
    relation_id = as.character(relation_id),
    same_sentence,
    sentence_distance,
    sentence
  )]
  data.table::setcolorder(out, c("from", "to", "relation_type", "pmid",
                                 "relation_id", "same_sentence",
                                 "sentence_distance", "sentence"))
  out[]
}

#' @noRd
.pn_edges <- function(evidence) {
  from <- to <- relation_type <- pmid <- sentence <- same_sentence <- NULL

  if (nrow(evidence) == 0L) return(.pn_edges_empty())

  out <- evidence[, .(
    weight = .N,
    n_pmids = data.table::uniqueN(pmid),
    n_sentences = sum(!is.na(sentence) & nzchar(sentence) & same_sentence, na.rm = TRUE)
  ), by = .(from, to, relation_type)]
  data.table::setorder(out, -weight, -n_pmids, from, to, relation_type)
  data.table::setcolorder(out, c("from", "to", "relation_type", "weight",
                                 "n_pmids", "n_sentences"))
  out[]
}

#' @noRd
.pn_nodes <- function(entities, edges_dt) {
  pmid <- type <- identifier <- text <- id <- N <- NULL

  if (nrow(edges_dt) == 0L) return(.pn_nodes_empty())

  ent <- data.table::copy(data.table::as.data.table(entities))
  required <- c("pmid", "type", "identifier", "text")
  if (!all(required %in% names(ent))) return(.pn_nodes_from_edges(edges_dt))

  ent <- ent[!is.na(text) & nchar(as.character(text)) > 0L,
             .(pmid = as.character(pmid),
               type = as.character(type),
               identifier = as.character(identifier),
               text = as.character(text))]
  if (nrow(ent) == 0L) return(.pn_nodes_from_edges(edges_dt))

  ent[, id := .pn_node_id(type, identifier, text)]
  lab <- ent[, .N, by = .(id, type, text)]
  data.table::setorder(lab, id, -N)
  lab <- lab[, .SD[1L], by = id, .SDcols = c("type", "text")]
  data.table::setnames(lab, "text", "label")
  freq <- ent[, .(n_mentions = .N, n_pmids = data.table::uniqueN(pmid)), by = id]
  nodes <- merge(lab, freq, by = "id", sort = FALSE)

  endpoints <- unique(c(edges_dt$from, edges_dt$to))
  missing <- setdiff(endpoints, nodes$id)
  if (length(missing) > 0L) {
    nodes <- data.table::rbindlist(list(
      nodes,
      data.table::data.table(id = missing, type = NA_character_,
                             label = missing, n_mentions = 0L, n_pmids = 0L)
    ), use.names = TRUE)
  }

  data.table::setcolorder(nodes, c("id", "type", "label", "n_mentions", "n_pmids"))
  data.table::setorder(nodes, -n_mentions, id)
  nodes[]
}

#' @noRd
.pn_nodes_from_edges <- function(edges_dt) {
  ids <- unique(c(edges_dt$from, edges_dt$to))
  ids <- ids[!is.na(ids)]
  data.table::data.table(
    id = ids,
    type = NA_character_,
    label = ids,
    n_mentions = 0L,
    n_pmids = 0L
  )
}

#' @noRd
.pn_nodes_empty <- function() {
  data.table::data.table(
    id = character(),
    type = character(),
    label = character(),
    n_mentions = integer(),
    n_pmids = integer()
  )
}

#' @noRd
.pn_edges_empty <- function() {
  data.table::data.table(
    from = character(),
    to = character(),
    relation_type = character(),
    weight = integer(),
    n_pmids = integer(),
    n_sentences = integer()
  )
}

#' @noRd
.pn_evidence_empty <- function() {
  data.table::data.table(
    from = character(),
    to = character(),
    relation_type = character(),
    pmid = character(),
    relation_id = character(),
    same_sentence = logical(),
    sentence_distance = integer(),
    sentence = character()
  )
}
