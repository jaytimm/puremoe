#' Add Sentence Context to PubTator Entities and Relations
#'
#' Adds sentence identifiers and sentence-relative spans to PubTator entity
#' mentions, then carries compact sentence anchors onto relation rows.
#'
#' @param pubtator A list returned by \code{\link{get_records}(endpoint =
#'   "pubtator")}, with \code{entities} and \code{relations} data.tables.
#'
#' @return A list with \code{entities}, \code{relations}, and \code{sentences}
#'   data.tables. Entity rows preserve their original \code{start}/\code{end}
#'   spans and gain \code{sentence_id}, \code{sentence_start}, and
#'   \code{sentence_end}. Relation rows gain role-specific entity labels and
#'   sentence anchors, plus \code{same_sentence} and
#'   \code{sentence_distance}.
#'
#' @importFrom data.table copy rbindlist setDT setnames setorder
#' @importFrom textpress nlp_split_sentences
#' @export
pubtator_context <- function(pubtator) {
  if (!is.list(pubtator) || !all(c("entities", "relations") %in% names(pubtator))) {
    stop("pubtator must be a list with entities and relations")
  }
  if (!is.data.frame(pubtator$entities) || !is.data.frame(pubtator$relations)) {
    stop("pubtator$entities and pubtator$relations must be data.frames")
  }

  entities <- data.table::copy(pubtator$entities)
  relations <- data.table::copy(pubtator$relations)
  data.table::setDT(entities)
  data.table::setDT(relations)

  required_entities <- c("pmid", "mention_index", "text", "start", "end",
                         "tiab", "passage_text", "passage_offset")
  if (!all(required_entities %in% names(entities))) {
    stop("pubtator$entities must contain columns: ",
         paste(required_entities, collapse = ", "))
  }

  required_relations <- c("pmid", "ent1_mention_index", "ent2_mention_index")
  if (!all(required_relations %in% names(relations))) {
    stop("pubtator$relations must contain columns: ",
         paste(required_relations, collapse = ", "))
  }

  mapped <- .pubtator_context_entities(entities)
  relations <- .pubtator_context_relations(relations, mapped$entities)

  list(
    entities = mapped$entities,
    relations = relations,
    sentences = mapped$sentences
  )
}

.pubtator_context_entities <- function(entities) {
  pmid <- tiab <- passage_text <- passage_offset <- passage_id <- NULL
  text <- start <- end <- passage_start <- passage_end <- NULL
  sent_start <- sent_end <- sentence_id <- sentence <- NULL

  entities[, pmid := as.character(pmid)]
  entities[, mention_index := as.integer(mention_index)]
  entities[, passage_offset := as.integer(passage_offset)]
  entities[, `:=`(
    sentence_id = NA_integer_,
    sentence_start = NA_integer_,
    sentence_end = NA_integer_
  )]

  valid <- entities[!is.na(text) & nchar(text) > 0L &
                      !is.na(start) & !is.na(end) &
                      !is.na(passage_text) & !is.na(passage_offset)]
  valid[, c("sentence_id", "sentence_start", "sentence_end") := NULL]

  if (nrow(valid) == 0L) {
    return(list(
      entities = entities[],
      sentences = .empty_pubtator_sentence_table()
    ))
  }

  valid[, passage_id := paste(pmid, tiab, passage_offset, sep = "::")]
  valid[, `:=`(
    passage_start = start - passage_offset,
    passage_end = end - passage_offset
  )]
  valid <- valid[passage_start >= 0L & passage_end > passage_start]

  passages <- unique(valid[, .(
    doc_id = passage_id,
    pmid = as.character(pmid),
    tiab = as.character(tiab),
    passage_offset = as.integer(passage_offset),
    text = as.character(passage_text)
  )])

  sentences <- textpress::nlp_split_sentences(passages[, .(doc_id, text)],
                                              by = "doc_id")
  data.table::setDT(sentences)
  data.table::setnames(sentences, c("text", "start", "end"),
                       c("sentence", "sent_start", "sent_end"))
  sentences <- merge(sentences, passages[, .(doc_id, pmid, tiab, passage_offset)],
                     by = "doc_id", all.x = TRUE)
  sentences[, sentence_id := as.integer(sentence_id)]
  sentences[tiab == "title", sentence_id := 0L]

  joined <- merge(valid, sentences[, .(doc_id, sentence_id, sentence,
                                       sent_start, sent_end)],
                  by.x = "passage_id", by.y = "doc_id",
                  allow.cartesian = TRUE)
  joined <- joined[passage_start + 1L >= sent_start & passage_end <= sent_end]
  joined[, `:=`(
    sentence_start = as.integer(passage_start - (sent_start - 1L)),
    sentence_end = as.integer(passage_end - (sent_start - 1L))
  )]

  update_cols <- c("pmid", "mention_index", "sentence_id",
                   "sentence_start", "sentence_end")
  keep_cols <- setdiff(names(entities), c("sentence_id", "sentence_start", "sentence_end"))
  entities <- merge(
    entities[, ..keep_cols],
    joined[, ..update_cols],
    by = c("pmid", "mention_index"),
    all.x = TRUE,
    sort = FALSE
  )

  sentence_out <- unique(sentences[, .(
    pmid = as.character(pmid),
    tiab = as.character(tiab),
    passage_offset = as.integer(passage_offset),
    sentence_id = as.integer(sentence_id),
    sentence = as.character(sentence)
  )])

  data.table::setorder(entities, pmid, mention_index)
  data.table::setorder(sentence_out, pmid, tiab, sentence_id)

  list(
    entities = entities[],
    sentences = sentence_out[]
  )
}

.pubtator_context_relations <- function(relations, entities) {
  pmid <- ent1_mention_index <- ent2_mention_index <- NULL
  mention_index <- text <- identifier <- tiab <- sentence_id <- NULL
  ent1_tiab <- ent2_tiab <- ent1_sentence_id <- ent2_sentence_id <- NULL

  out <- data.table::copy(relations)
  out[, pmid := as.character(pmid)]
  out[, ent1_mention_index := as.integer(ent1_mention_index)]
  out[, ent2_mention_index := as.integer(ent2_mention_index)]

  out[, `:=`(
    ent1_text = NA_character_,
    ent1_identifier = NA_character_,
    ent1_tiab = NA_character_,
    ent1_sentence_id = NA_integer_,
    ent2_text = NA_character_,
    ent2_identifier = NA_character_,
    ent2_tiab = NA_character_,
    ent2_sentence_id = NA_integer_
  )]

  role_cols <- c("pmid", "mention_index", "text", "identifier", "tiab", "sentence_id")
  role_entities <- unique(entities[, ..role_cols], by = c("pmid", "mention_index"))
  role_entities[, pmid := as.character(pmid)]
  role_entities[, mention_index := as.integer(mention_index)]

  out[role_entities, `:=`(
    ent1_text = i.text,
    ent1_identifier = i.identifier,
    ent1_tiab = i.tiab,
    ent1_sentence_id = i.sentence_id
  ), on = .(pmid, ent1_mention_index = mention_index)]

  out[role_entities, `:=`(
    ent2_text = i.text,
    ent2_identifier = i.identifier,
    ent2_tiab = i.tiab,
    ent2_sentence_id = i.sentence_id
  ), on = .(pmid, ent2_mention_index = mention_index)]

  same_tiab <- !is.na(out$ent1_tiab) & !is.na(out$ent2_tiab) &
    out$ent1_tiab == out$ent2_tiab
  out[, same_sentence := same_tiab &
        !is.na(ent1_sentence_id) & !is.na(ent2_sentence_id) &
        ent1_sentence_id == ent2_sentence_id]
  out[, sentence_distance := data.table::fifelse(
    same_tiab & !is.na(ent1_sentence_id) & !is.na(ent2_sentence_id),
    abs(ent1_sentence_id - ent2_sentence_id),
    NA_integer_
  )]

  out[]
}

.empty_pubtator_sentence_table <- function() {
  data.table::data.table(
    pmid = character(),
    tiab = character(),
    passage_offset = integer(),
    sentence_id = integer(),
    sentence = character()
  )
}
