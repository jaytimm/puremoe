#' Count PubTator Entity Co-occurrence from Sentence Context
#'
#' Counts pairs of biomedical entities that co-occur in the same sentence
#' (\code{window = 0}) or within \code{window} sentences of each other, using
#' the contextualized entity table returned by \code{\link{pubtator_context}}.
#' Co-occurrence is computed within each \code{pmid}/\code{tiab} passage; title
#' and abstract sentence IDs are not compared to one another.
#'
#' Entities are de-duplicated to one mention per sentence before pairing, and
#' pairs of the same entity (identical \code{type}, \code{identifier}, and
#' \code{text}) are dropped.
#'
#' @param x A PubTator context list returned by \code{\link{pubtator_context}},
#'   or a contextualized entity data.frame with \code{pmid}, \code{tiab},
#'   \code{type}, \code{identifier}, \code{text}, and \code{sentence_id}.
#' @param window Non-negative integer sentence distance. \code{0} counts
#'   entities in the same sentence; \code{n} counts entities whose sentences are
#'   at most \code{n} apart within the same \code{pmid}/\code{tiab} passage.
#' @param by One of \code{"type"} (default) or \code{"entity"}. \code{"type"}
#'   aggregates counts by entity-type pair; \code{"entity"} aggregates by the
#'   specific \code{(type, identifier, text)} pair.
#'
#' @return A data.table. With \code{by = "type"}: \code{type_x},
#'   \code{type_y}, \code{n} (co-occurrence instances), and \code{n_pmids}
#'   (distinct documents), ordered by \code{n}. With \code{by = "entity"}: the
#'   same plus \code{identifier_x}/\code{text_x}/\code{identifier_y}/
#'   \code{text_y}.
#'
#' @importFrom data.table as.data.table uniqueN fifelse setorder
#' @export
#' @examples
#' \dontrun{
#' pmids <- search_pubmed('"biomarker"[TiAb] AND "cancer"[TiAb]')
#'
#' ctx <- pmids |>
#'   get_records(endpoint = "pubtator") |>
#'   pubtator_context()
#'
#' ctx |> pubtator_cooccurrence(window = 0, by = "type")
#' ctx |> pubtator_cooccurrence(window = 1, by = "entity")
#' }
pubtator_cooccurrence <- function(x,
                                  window = 0L,
                                  by = c("type", "entity")) {

  pmid <- tiab <- type <- identifier <- text <- sentence_id <- NULL
  mid <- mid_a <- mid_b <- ek <- ek_a <- ek_b <- NULL
  type_a <- type_b <- identifier_a <- identifier_b <- text_a <- text_b <- NULL
  sentence_id_a <- sentence_id_b <- n <- n_pmids <- NULL

  by <- match.arg(by)
  window <- as.integer(window[1L])
  if (is.na(window) || window < 0L) {
    stop("window must be a non-negative integer")
  }

  entities <- .pubtator_cooccurrence_entities(x)

  required <- c("pmid", "tiab", "type", "identifier", "text", "sentence_id")
  if (!all(required %in% names(entities))) {
    stop("x must be a pubtator_context() result or contain columns: ",
         paste(required, collapse = ", "))
  }

  empty_out <- function() {
    if (by == "type") {
      return(data.table::data.table(
        type_x = character(), type_y = character(),
        n = integer(), n_pmids = integer()
      ))
    }
    data.table::data.table(
      type_x = character(), identifier_x = character(), text_x = character(),
      type_y = character(), identifier_y = character(), text_y = character(),
      n = integer(), n_pmids = integer()
    )
  }

  DT <- data.table::as.data.table(entities)
  DT <- DT[!is.na(text) & nchar(text) > 0L & !is.na(sentence_id),
           .(pmid = as.character(pmid),
             tiab = as.character(tiab),
             sentence_id = as.integer(sentence_id),
             type = as.character(type),
             identifier = as.character(identifier),
             text = as.character(text))]
  if (nrow(DT) == 0L) return(empty_out())

  ent <- unique(DT[, .(pmid, tiab, sentence_id, type, identifier, text)])
  ent[, ek := paste(type,
                    data.table::fifelse(is.na(identifier), "", identifier),
                    text, sep = "\037")]
  ent[, mid := .I]

  pairs <- merge(ent, ent, by = c("pmid", "tiab"),
                 suffixes = c("_a", "_b"), allow.cartesian = TRUE)
  pairs <- pairs[mid_a < mid_b]
  pairs <- pairs[abs(sentence_id_a - sentence_id_b) <= window]
  pairs <- pairs[ek_a != ek_b]
  if (nrow(pairs) == 0L) return(empty_out())

  swap <- pairs$ek_a > pairs$ek_b
  pairs[, `:=`(
    type_x       = data.table::fifelse(swap, type_b, type_a),
    identifier_x = data.table::fifelse(swap, identifier_b, identifier_a),
    text_x       = data.table::fifelse(swap, text_b, text_a),
    type_y       = data.table::fifelse(swap, type_a, type_b),
    identifier_y = data.table::fifelse(swap, identifier_a, identifier_b),
    text_y       = data.table::fifelse(swap, text_a, text_b)
  )]

  keys <- if (by == "type") {
    c("type_x", "type_y")
  } else {
    c("type_x", "identifier_x", "text_x", "type_y", "identifier_y", "text_y")
  }
  out <- pairs[, .(n = .N, n_pmids = data.table::uniqueN(pmid)), by = keys]
  data.table::setorder(out, -n, -n_pmids)
  out[]
}

.pubtator_cooccurrence_entities <- function(x) {
  if (is.list(x) && "entities" %in% names(x) && is.data.frame(x$entities)) {
    return(x$entities)
  }
  if (is.data.frame(x)) {
    return(x)
  }
  stop("x must be a pubtator_context() result or a contextualized entity data.frame")
}
