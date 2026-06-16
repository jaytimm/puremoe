#' Retrieve Entities and Relations from PubTator3
#'
#' Fetches PubTator3 BioC JSON for PMIDs and returns a small list of tables:
#' entity mentions and relation pairs. Sentence context is intentionally left to
#' \code{\link{pubtator_context}}.
#'
#' @param x A vector of PubMed IDs.
#' @param sleep Duration in seconds to pause after the request.
#'
#' @return A list with \code{entities} and \code{relations} data.tables.
#' @noRd
.get_pubtator <- function(x, sleep) {
  url <- paste0(
    "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/",
    "publications/export/biocjson?pmids=",
    paste(utils::URLencode(as.character(x), reserved = TRUE), collapse = ",")
  )

  payload <- tryCatch(
    jsonlite::fromJSON(url, simplifyVector = FALSE),
    error = function(e) NULL
  )
  Sys.sleep(sleep)

  .parse_pubtator_payload(payload)
}

.parse_pubtator_payload <- function(payload) {
  docs <- payload$PubTator3
  if (!is.list(docs) || !length(docs)) {
    return(.empty_pubtator_result())
  }

  entities <- list()
  relations <- list()
  entity_n <- 0L
  relation_n <- 0L

  for (doc in docs) {
    pmid <- as.character(.null_or(doc$id, .null_or(doc$pmid, NA_character_)))
    mention_index <- 0L

    passages <- .null_or(doc$passages, list())
    for (i in seq_along(passages)) {
      passage <- passages[[i]]
      if (!is.list(passage)) next

      passage_text <- as.character(.null_or(passage$text, NA_character_))
      passage_offset <- suppressWarnings(as.integer(.null_or(passage$offset, NA_integer_)))
      tiab <- .pubtator_passage_type(passage, i)
      annotations <- .null_or(passage$annotations, list())
      if (!is.list(annotations) || !length(annotations)) next

      for (ann in annotations) {
        if (!is.list(ann)) next
        loc <- .pubtator_location(.null_or(ann$locations, list()))
        infons <- .null_or(ann$infons, list())
        entity_n <- entity_n + 1L
        entities[[entity_n]] <- data.table::data.table(
          pmid = pmid,
          mention_index = mention_index,
          id = as.character(.null_or(ann$id, NA_character_)),
          text = as.character(.null_or(ann$text, NA_character_)),
          type = as.character(.null_or(infons$type, NA_character_)),
          identifier = as.character(.null_or(infons$identifier, NA_character_)),
          tiab = tiab,
          start = loc$start,
          end = loc$end,
          passage_text = passage_text,
          passage_offset = passage_offset
        )
        mention_index <- mention_index + 1L
      }
    }

    doc_relations <- .null_or(doc$relations, list())
    if (!is.list(doc_relations) || !length(doc_relations)) next

    for (rel in doc_relations) {
      if (!is.list(rel)) next
      infons <- .null_or(rel$infons, list())
      nodes <- .null_or(rel$nodes, list())
      role1 <- .null_or(infons$role1, list())
      role2 <- .null_or(infons$role2, list())

      for (node in nodes) {
        role_ids <- strsplit(
          as.character(.null_or(node$role, NA_character_)),
          ",",
          fixed = TRUE
        )[[1]]
        role_ids <- trimws(role_ids)
        relation_n <- relation_n + 1L
        relations[[relation_n]] <- data.table::data.table(
          pmid = pmid,
          relation_id = as.character(.null_or(rel$id, NA_character_)),
          relation_type = tolower(as.character(.null_or(infons$type, NA_character_))),
          score = suppressWarnings(as.numeric(.null_or(infons$score, NA_real_))),
          ent1_mention_index = suppressWarnings(as.integer(.null_or(role_ids[1], NA_integer_))),
          ent1_type = as.character(.null_or(role1$type, NA_character_)),
          ent2_mention_index = suppressWarnings(as.integer(.null_or(role_ids[2], NA_integer_))),
          ent2_type = as.character(.null_or(role2$type, NA_character_))
        )
      }
    }
  }

  list(
    entities = if (length(entities)) data.table::rbindlist(entities, fill = TRUE) else .empty_pubtator_entities(),
    relations = if (length(relations)) data.table::rbindlist(relations, fill = TRUE) else .empty_pubtator_relations()
  )
}

.combine_pubtator_results <- function(results) {
  results <- results[vapply(results, function(x) {
    is.list(x) && all(c("entities", "relations") %in% names(x))
  }, logical(1))]

  if (!length(results)) {
    return(.empty_pubtator_result())
  }

  list(
    entities = data.table::rbindlist(lapply(results, `[[`, "entities"), fill = TRUE),
    relations = data.table::rbindlist(lapply(results, `[[`, "relations"), fill = TRUE)
  )
}

.empty_pubtator_result <- function() {
  list(
    entities = .empty_pubtator_entities(),
    relations = .empty_pubtator_relations()
  )
}

.empty_pubtator_entities <- function() {
  data.table::data.table(
    pmid = character(),
    mention_index = integer(),
    id = character(),
    text = character(),
    type = character(),
    identifier = character(),
    tiab = character(),
    start = integer(),
    end = integer(),
    passage_text = character(),
    passage_offset = integer()
  )
}

.empty_pubtator_relations <- function() {
  data.table::data.table(
    pmid = character(),
    relation_id = character(),
    relation_type = character(),
    score = numeric(),
    ent1_mention_index = integer(),
    ent1_type = character(),
    ent2_mention_index = integer(),
    ent2_type = character()
  )
}

.pubtator_passage_type <- function(passage, i) {
  infons <- .null_or(passage$infons, list())
  type <- tolower(as.character(.null_or(infons$type, NA_character_)))
  if (!is.na(type) && nzchar(type)) {
    return(type)
  }
  if (identical(i, 1L)) "title" else "abstract"
}

.pubtator_location <- function(locations) {
  if (!is.list(locations) || !length(locations) || !is.list(locations[[1]])) {
    return(list(start = NA_integer_, end = NA_integer_))
  }
  start <- suppressWarnings(as.integer(.null_or(locations[[1]]$offset, NA_integer_)))
  length <- suppressWarnings(as.integer(.null_or(locations[[1]]$length, NA_integer_)))
  list(start = start, end = start + length)
}

.null_or <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}
