#' Map PubTator3 Annotations to Abstract Sentences
#'
#' Splits abstract text into sentences and assigns each PubTator3 entity
#' annotation to its containing sentence via character-offset overlap.
#' When available, the PubTator3 passage text and offsets are used directly.
#'
#' @param pubtations A data.table returned by
#'   \code{\link{get_records}(endpoint = "pubtations")}.
#'
#' @return A data.table with annotation columns plus integer
#'   \code{sentence_id}, \code{sentence}, \code{sentence_start}, and
#'   \code{sentence_end}. \code{sentence_start} and \code{sentence_end} are
#'   zero-based, end-exclusive entity offsets within \code{sentence}. PubTator passage metadata
#'   columns are used for mapping but are not returned. Only passage annotations
#'   that can be assigned to a sentence are returned.
#'
#' @importFrom data.table copy rbindlist setDT setnames setorder
#' @importFrom textpress nlp_split_sentences
#' @export
#' @examples
#' \dontrun{
#' pmids <- search_pubmed('"Biomarkers Consortium"')
#'
#' pubtations <- get_records(pmids, endpoint = "pubtations")
#'
#' mapped <- pubtator_sentences(pubtations)
#' }

pubtator_sentences <- function(pubtations) {

  if (!is.data.frame(pubtations))
    stop("pubtations must be a data.frame / data.table")
  pubtation_cols <- c("pmid", "tiab", "text", "start", "end",
                      "passage_text", "passage_offset")
  if (!all(pubtation_cols %in% names(pubtations)))
    stop("pubtations must contain columns: ", paste(pubtation_cols, collapse = ", "))

  pubtations <- data.table::copy(pubtations)
  data.table::setDT(pubtations)
  pubtations[, pmid := as.character(pmid)]

  .pubtator_sentences_from_passages(pubtations)
}

.pubtator_sentences_from_passages <- function(pubtations) {

  text <- passage_text <- passage_offset <- passage_id <- NULL
  passage_start <- passage_end <- NULL

  pubs <- pubtations[!is.na(text) & nchar(text) > 0 &
                       !is.na(passage_text) & !is.na(passage_offset)]
  if (nrow(pubs) == 0L) {
    out <- data.table::copy(pubtations)
    out[, `:=`(sentence_id = NA_integer_, sentence = NA_character_,
               sentence_start = NA_integer_, sentence_end = NA_integer_)]
    out[, c("passage_text", "passage_offset") := NULL]
    return(out[])
  }

  empty_pubs <- pubtations[is.na(text) | !nchar(text) > 0 |
                             is.na(passage_text) | is.na(passage_offset)]
  if (nrow(empty_pubs) > 0L) {
    empty_pubs[, `:=`(sentence_id = NA_integer_, sentence = NA_character_,
                      sentence_start = NA_integer_, sentence_end = NA_integer_)]
  }

  pubs[, passage_offset := as.integer(passage_offset)]
  pubs[, passage_id := paste(pmid, tiab, passage_offset, sep = "::")]
  pubs[, passage_start := start - passage_offset]
  pubs[, passage_end := end - passage_offset]
  pubs <- pubs[passage_start >= 0L & passage_end > passage_start]

  passages <- unique(pubs[, .(doc_id = passage_id, text = passage_text)])
  sentences <- textpress::nlp_split_sentences(passages, by = "doc_id")
  data.table::setDT(sentences)
  data.table::setnames(sentences, c("text", "start", "end"),
                       c("sentence", "sent_start", "sent_end"))

  mapped <- merge(pubs, sentences, by.x = "passage_id", by.y = "doc_id",
                  allow.cartesian = TRUE)
  mapped <- mapped[passage_start + 1L >= sent_start & passage_end <= sent_end]
  mapped[, `:=`(
    sentence_start = as.integer(passage_start - (sent_start - 1L)),
    sentence_end = as.integer(passage_end - (sent_start - 1L))
  )]
  mapped[, c("sent_start", "sent_end", "passage_start", "passage_end",
             "passage_id") := NULL]
  mapped[, sentence_id := as.integer(sentence_id)]
  mapped[tiab == "title", sentence_id := 0L]

  if (nrow(empty_pubs) > 0L) {
    mapped <- data.table::rbindlist(list(mapped, empty_pubs),
                                    use.names = TRUE, fill = TRUE)
  }
  mapped[, c("passage_text", "passage_offset") := NULL]

  data.table::setorder(mapped, pmid, start)
  mapped[]
}

#' Internal: Format PubTator Annotations as Training Spans
#'
#' Builds sentence- or abstract-level text units from PubTator passage text and
#' recalculates entity offsets relative to the returned unit text.
#'
#' @param pubtations A data.table returned by
#'   \code{\link{get_records}(endpoint = "pubtations")}.
#' @param unit One of \code{"sentence"} or \code{"abstract"}.
#' @param window Number of sentences on each side of the entity sentence to
#'   include when \code{unit = "sentence"}.
#'
#' @return A data.table of non-empty annotations with training text units and
#'   entity offsets relative to those units.
#' @noRd
.as_training_spans <- function(pubtations,
                               unit = c("sentence", "abstract"),
                               window = 0L) {

  text <- passage_text <- passage_offset <- passage_id <- NULL
  entity_start_passage <- entity_end_passage <- NULL
  sent_index <- unit_start_doc <- unit_end_doc <- NULL
  unit_start <- unit_end <- unit_id <- NULL

  unit <- match.arg(unit)
  window <- as.integer(window[1L])
  if (is.na(window) || window < 0L) {
    stop("window must be a non-negative integer")
  }
  if (unit == "abstract" && window > 0L) {
    stop("window is only supported when unit = 'sentence'")
  }

  pubtation_cols <- c("pmid", "tiab", "id", "text", "identifier", "type",
                      "start", "end", "passage_text", "passage_offset")
  if (!all(pubtation_cols %in% names(pubtations))) {
    stop("pubtations must contain columns: ", paste(pubtation_cols, collapse = ", "))
  }

  pubtations <- data.table::copy(pubtations)
  data.table::setDT(pubtations)
  pubtations[, pmid := as.character(pmid)]
  pubtations[, passage_offset := as.integer(passage_offset)]

  spans <- pubtations[!is.na(text) & nchar(text) > 0 &
                        !is.na(start) & !is.na(end) &
                        !is.na(passage_text) & !is.na(passage_offset)]
  if (nrow(spans) == 0L) {
    out <- spans
    out[, `:=`(unit = character(), unit_id = character(),
               unit_text = character(), unit_start = integer(),
               unit_end = integer(), entity_start_unit = integer(),
               entity_end_unit = integer())]
    return(out[])
  }

  spans[, passage_id := paste(pmid, tiab, passage_offset, sep = "::")]

  if (unit == "abstract") {
    spans[, `:=`(
      unit = "abstract",
      unit_id = passage_id,
      unit_text = passage_text,
      unit_start = passage_offset,
      unit_end = passage_offset + nchar(passage_text)
    )]
    spans[, `:=`(
      entity_start_unit = start - unit_start,
      entity_end_unit = end - unit_start
    )]
    spans[, c("passage_id", "passage_text", "passage_offset") := NULL]
    data.table::setorder(spans, pmid, start)
    return(spans[])
  }

  spans[, `:=`(
    entity_start_passage = start - passage_offset,
    entity_end_passage = end - passage_offset
  )]
  spans <- spans[entity_start_passage >= 0L & entity_end_passage > entity_start_passage]

  passages <- unique(spans[, .(doc_id = passage_id, text = passage_text)])
  sentences <- textpress::nlp_split_sentences(passages, by = "doc_id")
  data.table::setDT(sentences)
  data.table::setnames(sentences, c("text", "start", "end"),
                       c("sentence", "sent_start", "sent_end"))
  sentences[, sent_index := seq_len(.N), by = doc_id]

  sentence_offsets <- unique(spans[, .(doc_id = passage_id, passage_offset)])
  sentences <- merge(sentences, sentence_offsets, by = "doc_id")
  sentences[, `:=`(
    unit_start_doc = passage_offset + sent_start - 1L,
    unit_end_doc = passage_offset + sent_end
  )]
  sentences[, passage_offset := NULL]

  chunks <- textpress::nlp_roll_chunks(
    sentences[, .(doc_id, sent_index, text = sentence)],
    by = c("doc_id", "sent_index"),
    chunk_size = 1L,
    context_size = window,
    id_col = "unit_id"
  )
  data.table::setDT(chunks)
  chunks[, sent_index := seq_len(.N), by = doc_id]

  bounds <- sentences[
    ,
    {
      i <- seq_len(.N)
      data.table::data.table(
        sent_index = i,
        unit_start = unit_start_doc[pmax(1L, i - window)],
        unit_end = unit_end_doc[pmin(.N, i + window)]
      )
    },
    by = doc_id
  ]

  span_sentences <- merge(spans, sentences, by.x = "passage_id",
                          by.y = "doc_id", allow.cartesian = TRUE)
  span_sentences <- span_sentences[
    entity_start_passage + 1L >= sent_start &
      entity_end_passage <= sent_end
  ]

  span_sentences <- merge(
    span_sentences,
    chunks[, .(passage_id = doc_id, sent_index, unit_id)],
    by = c("passage_id", "sent_index")
  )
  span_sentences <- merge(
    span_sentences,
    bounds[, .(passage_id = doc_id, sent_index, unit_start, unit_end)],
    by = c("passage_id", "sent_index")
  )
  span_sentences[, `:=`(
    unit = "sentence",
    unit_text = substr(passage_text,
                       unit_start - passage_offset + 1L,
                       unit_end - passage_offset),
    entity_start_unit = start - unit_start,
    entity_end_unit = end - unit_start
  )]

  span_sentences[, c("passage_id", "passage_text", "passage_offset",
                     "entity_start_passage", "entity_end_passage",
                     "sent_start", "sent_end", "unit_start_doc",
                     "unit_end_doc", "sent_index") := NULL]
  data.table::setorder(span_sentences, pmid, start)
  span_sentences[]
}
