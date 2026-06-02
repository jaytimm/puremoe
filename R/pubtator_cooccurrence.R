#' Count Entity Co-occurrence from Sentence-Mapped PubTator3 Annotations
#'
#' Counts pairs of biomedical entities that co-occur within the same sentence
#' (\code{window = 0}) or within \code{window} sentences of each other, using the
#' sentence-mapped annotation table returned by \code{\link{pubtator_sentences}}.
#' Co-occurrence is computed within each \code{pmid}/\code{tiab} passage: title
#' and abstract are treated separately because their sentence offsets are
#' numbered independently.
#'
#' Entities are de-duplicated to one mention per sentence before pairing, and
#' pairs of the \emph{same} entity (identical \code{type}, \code{identifier},
#' and \code{text}) are dropped, so same-type pairs between two \emph{distinct}
#' entities (e.g. two different genes) are retained.
#'
#' Counting follows windowed-collocation semantics: a pair contributes one
#' instance for each pair of mentions within \code{window} sentences of each
#' other. At \code{window = 0} this is simply one instance per shared sentence,
#' but for \code{window > 0} a pair recurring across several sentences yields
#' multiple instances, so counts scale with mention frequency. \code{n_pmids}
#' (distinct documents) is unaffected and is the more conservative signal.
#'
#' @param mapped A \code{data.table} returned by
#'   \code{\link{pubtator_sentences}}. Must contain \code{pmid}, \code{tiab},
#'   \code{type}, \code{identifier}, \code{text}, \code{sentence_id}, and
#'   \code{sentence} columns.
#' @param window Non-negative integer sentence distance. \code{0} (default)
#'   counts entities in the same sentence; \code{n} counts entities whose
#'   sentences are at most \code{n} apart within the same passage.
#' @param by One of \code{"type"} (default) or \code{"entity"}. \code{"type"}
#'   aggregates counts by entity-type pair; \code{"entity"} aggregates by the
#'   specific \code{(type, identifier, text)} pair. Ignored when
#'   \code{evidence = TRUE}.
#' @param evidence Logical. When \code{FALSE} (default), returns aggregated
#'   counts. When \code{TRUE}, returns the supporting sentence \code{context} for
#'   each co-occurring pair, so counts can be traced back to concrete text.
#'
#' @return A \code{data.table}. With \code{evidence = FALSE} and
#'   \code{by = "type"}: \code{type_x}, \code{type_y}, \code{n} (co-occurrence
#'   instances), and \code{n_pmids} (distinct documents), ordered by \code{n}.
#'   With \code{by = "entity"}: the same plus
#'   \code{identifier_x}/\code{text_x}/\code{identifier_y}/\code{text_y}. With
#'   \code{evidence = TRUE}: one row per distinct \code{context} string for an
#'   entity pair (identical contexts de-duplicated), with \code{pmid},
#'   \code{tiab}, the two entities' \code{type}/\code{identifier}/\code{text},
#'   and \code{context}.
#'
#' @importFrom data.table as.data.table uniqueN fifelse setorder
#' @export
#' @examples
#' \dontrun{
#' pmids <- search_pubmed('"biomarker"[TiAb] AND "cancer"[TiAb]')
#'
#' mapped <- pmids |>
#'   get_records(endpoint = "pubtations") |>
#'   pubtator_sentences()
#'
#' # same-sentence entity-type co-occurrence
#' mapped |> pubtator_cooccurrence(window = 0, by = "type")
#'
#' # specific entity pairs within one sentence on either side
#' mapped |> pubtator_cooccurrence(window = 1, by = "entity")
#'
#' # traceable evidence: every instance with its sentence context
#' mapped |> pubtator_cooccurrence(window = 0, evidence = TRUE)
#' }
pubtator_cooccurrence <- function(mapped,
                                  window = 0L,
                                  by = c("type", "entity"),
                                  evidence = FALSE) {

  pmid <- tiab <- type <- identifier <- text <- sentence_id <- sentence <- NULL
  mid <- mid_a <- mid_b <- ek <- ek_a <- ek_b <- NULL
  type_a <- type_b <- identifier_a <- identifier_b <- text_a <- text_b <- NULL
  sentence_id_a <- sentence_id_b <- NULL
  type_x <- type_y <- identifier_x <- identifier_y <- text_x <- text_y <- NULL
  sid_x <- sid_y <- lo <- hi <- inst_id <- n <- n_pmids <- context <- NULL

  by <- match.arg(by)
  window <- as.integer(window[1L])
  if (is.na(window) || window < 0L)
    stop("window must be a non-negative integer")
  if (!is.logical(evidence) || length(evidence) != 1L || is.na(evidence))
    stop("evidence must be a single logical value")
  if (!is.data.frame(mapped))
    stop("mapped must be a data.frame / data.table")

  required <- c("pmid", "tiab", "type", "identifier", "text",
                "sentence_id", "sentence")
  if (!all(required %in% names(mapped)))
    stop("mapped must contain columns: ", paste(required, collapse = ", "),
         "; use pubtator_sentences()")

  empty_out <- function() {
    if (evidence) {
      return(data.table::data.table(
        pmid = character(), tiab = character(),
        type_x = character(), identifier_x = character(), text_x = character(),
        type_y = character(), identifier_y = character(), text_y = character(),
        context = character()
      ))
    }
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

  DT <- data.table::as.data.table(mapped)
  DT <- DT[!is.na(text) & nchar(text) > 0L & !is.na(sentence_id),
           .(pmid = as.character(pmid),
             tiab = as.character(tiab),
             sentence_id = as.integer(sentence_id),
             type = as.character(type),
             identifier = as.character(identifier),
             text = as.character(text),
             sentence = as.character(sentence))]
  if (nrow(DT) == 0L) return(empty_out())

  # one mention per (passage, sentence, entity); ek = canonical entity key
  ent <- unique(DT[, .(pmid, tiab, sentence_id, type, identifier, text)])
  ent[, ek := paste(type,
                    data.table::fifelse(is.na(identifier), "", identifier),
                    text, sep = "")]
  ent[, mid := .I]

  pairs <- merge(ent, ent, by = c("pmid", "tiab"),
                 suffixes = c("_a", "_b"), allow.cartesian = TRUE)
  pairs <- pairs[mid_a < mid_b]
  pairs <- pairs[abs(sentence_id_a - sentence_id_b) <= window]
  pairs <- pairs[ek_a != ek_b]
  if (nrow(pairs) == 0L) return(empty_out())

  # canonicalize orientation so each unordered pair aggregates consistently
  swap <- pairs$ek_a > pairs$ek_b
  pairs[, `:=`(
    type_x       = data.table::fifelse(swap, type_b, type_a),
    identifier_x = data.table::fifelse(swap, identifier_b, identifier_a),
    text_x       = data.table::fifelse(swap, text_b, text_a),
    sid_x        = data.table::fifelse(swap, sentence_id_b, sentence_id_a),
    type_y       = data.table::fifelse(swap, type_a, type_b),
    identifier_y = data.table::fifelse(swap, identifier_a, identifier_b),
    text_y       = data.table::fifelse(swap, text_a, text_b),
    sid_y        = data.table::fifelse(swap, sentence_id_a, sentence_id_b)
  )]

  if (!evidence) {
    keys <- if (by == "type") {
      c("type_x", "type_y")
    } else {
      c("type_x", "identifier_x", "text_x", "type_y", "identifier_y", "text_y")
    }
    out <- pairs[, .(n = .N, n_pmids = data.table::uniqueN(pmid)), by = keys]
    data.table::setorder(out, -n, -n_pmids)
    return(out[])
  }

  # evidence: join the spanned sentences into a single context string
  pairs[, `:=`(inst_id = .I,
               lo = pmin(sid_x, sid_y),
               hi = pmax(sid_x, sid_y))]
  sl <- unique(DT[, .(pmid, tiab, sentence_id, sentence)])
  ictx <- merge(pairs[, .(inst_id, pmid, tiab, lo, hi)], sl,
                by = c("pmid", "tiab"), allow.cartesian = TRUE)
  ictx <- ictx[sentence_id >= lo & sentence_id <= hi]
  data.table::setorder(ictx, inst_id, sentence_id)
  ctx <- ictx[, .(context = paste(sentence, collapse = " ")), by = inst_id]

  ev <- merge(pairs, ctx, by = "inst_id", all.x = TRUE)
  # one row per distinct context for an entity pair: at window > 0 a pair can be
  # admitted via several mention-pairs spanning the same sentences, yielding
  # identical context strings, so de-duplicate them.
  ev <- unique(ev[, .(pmid, tiab,
                      type_x, identifier_x, text_x,
                      type_y, identifier_y, text_y,
                      context)])
  data.table::setorder(ev, pmid, tiab, type_x, type_y, context)
  ev[]
}
