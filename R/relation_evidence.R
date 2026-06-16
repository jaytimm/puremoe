#' Summarize Evidence Behind PubTator Relations
#'
#' Aggregates PubTator3 relations into a per-relation evidence summary: one row
#' per unique directed relation (\code{relation_type}, entity 1, entity 2),
#' reporting how many documents and sentences assert it, the sentences
#' themselves, and -- when \code{icites} is supplied -- a citation-weighted
#' support score. This turns a flat relation table into a ranked picture of which
#' asserted relationships are best attested across a corpus. It is a local
#' aggregation over a \code{\link{pubtator_context}} result and makes no API
#' calls.
#'
#' Entities are keyed on their PubTator \code{identifier} when present and
#' otherwise on \code{type:text}, so synonymous mentions of the same concept
#' collapse into one relation. The representative \code{ent1_text}/\code{ent2_text}
#' is the most frequent surface form for each entity.
#'
#' @param ctx A list returned by \code{\link{pubtator_context}}, with
#'   \code{relations} and \code{sentences} data.tables.
#' @param relation_type Optional character vector of relation types to keep
#'   (e.g. \code{"treat"}); matched case-insensitively. \code{NULL} (default)
#'   keeps all types.
#' @param entity Optional character vector matched against either entity side by
#'   \code{identifier} (exact) or \code{text} (case-insensitive). \code{NULL}
#'   (default) applies no entity filter.
#' @param icites Optional \code{icites} table from
#'   \code{\link{get_records}(endpoint = "icites")}; when supplied, a
#'   \code{citation_support} column (summed citation counts over the distinct
#'   supporting papers) is added and results are ranked by it.
#' @param same_sentence If \code{TRUE} (default), keep only relations whose two
#'   entities fall in the same sentence, so each supporting row maps to a single
#'   asserting sentence.
#'
#' @return A data.table, one row per unique relation, ordered by support
#'   (descending): \code{relation_type}, the \code{ent1_*}/\code{ent2_*} entity
#'   columns, \code{n_pmids} (distinct documents), \code{n_sentences} (distinct
#'   asserting sentences), an optional \code{citation_support} column when
#'   \code{icites} is supplied, and the list-columns \code{sentences} (distinct
#'   asserting sentences) and \code{pmids} (supporting documents) for tracing
#'   each summary back to its source.
#'
#' @importFrom data.table as.data.table copy uniqueN setorderv setcolorder
#' @export
#' @examples
#' \dontrun{
#' pmids <- search_pubmed('"doxorubicin"[TiAb] AND "cardiotoxicity"[TiAb]')
#' ctx   <- get_records(pmids, endpoint = "pubtator") |> pubtator_context()
#'
#' # Every relation, ranked by how many documents assert it
#' relation_evidence(ctx)
#'
#' # One relation type, ranked by citation support; read the sentences
#' icites <- get_records(pmids, endpoint = "icites")
#' ev <- relation_evidence(ctx, relation_type = "negative_correlation",
#'                         icites = icites)
#' ev[1, ]$sentences[[1]]
#' }
relation_evidence <- function(ctx,
                              relation_type = NULL,
                              entity = NULL,
                              icites = NULL,
                              same_sentence = TRUE) {

  pmid <- tiab <- sentence_id <- sentence <- citation_count <- NULL
  ent1_tiab <- ent1_sentence_id <- ent1_text <- ent1_identifier <- ent1_type <- NULL
  ent2_text <- ent2_identifier <- ent2_type <- NULL
  ent1_key <- ent2_key <- sent_key <- n_pmids <- n_sentences <- citation_support <- NULL

  if (!is.list(ctx) || !all(c("relations", "sentences") %in% names(ctx))) {
    stop("ctx must be a pubtator_context() result with relations and sentences")
  }
  if (!is.data.frame(ctx$relations) || !is.data.frame(ctx$sentences)) {
    stop("ctx$relations and ctx$sentences must be data.frames")
  }

  required <- c("pmid", "relation_type", "ent1_text", "ent1_identifier",
                "ent1_type", "ent2_text", "ent2_identifier", "ent2_type",
                "ent1_tiab", "ent1_sentence_id", "same_sentence",
                "sentence_distance")
  if (!all(required %in% names(ctx$relations))) {
    stop("ctx$relations is missing context columns; run pubtator_context() first")
  }

  rel <- data.table::copy(data.table::as.data.table(ctx$relations))
  rel[, pmid := as.character(pmid)]

  if (!is.null(relation_type)) {
    rt <- tolower(as.character(relation_type))
    rel <- rel[tolower(rel$relation_type) %in% rt]
  }
  if (!is.null(entity)) {
    e <- as.character(entity)
    el <- tolower(e)
    keep <- (!is.na(rel$ent1_identifier) & rel$ent1_identifier %in% e) |
            (!is.na(rel$ent2_identifier) & rel$ent2_identifier %in% e) |
            (!is.na(rel$ent1_text) & tolower(rel$ent1_text) %in% el) |
            (!is.na(rel$ent2_text) & tolower(rel$ent2_text) %in% el)
    rel <- rel[keep]
  }
  if (isTRUE(same_sentence)) {
    rel <- rel[!is.na(rel$same_sentence) & rel$same_sentence]
  }

  has_icite <- !is.null(icites)
  if (has_icite) {
    ic <- data.table::as.data.table(icites)
    if (!"citation_count" %in% names(ic)) {
      stop("icites must contain a 'citation_count' column; use get_records(endpoint = 'icites')")
    }
  }
  if (nrow(rel) == 0L) {
    return(.relation_evidence_empty(has_icite))
  }

  # attach the asserting sentence (anchored on entity 1's sentence)
  sent <- data.table::as.data.table(ctx$sentences)
  sent <- unique(sent[, .(pmid = as.character(pmid),
                          tiab = as.character(tiab),
                          sentence_id = as.integer(sentence_id),
                          sentence = as.character(sentence))])
  rel <- merge(rel, sent,
               by.x = c("pmid", "ent1_tiab", "ent1_sentence_id"),
               by.y = c("pmid", "tiab", "sentence_id"),
               all.x = TRUE, sort = FALSE)

  if (has_icite) {
    ic <- unique(ic[, .(pmid = as.character(pmid),
                        citation_count = suppressWarnings(as.integer(citation_count)))])
    rel <- merge(rel, ic, by = "pmid", all.x = TRUE, sort = FALSE)
  } else {
    rel[, citation_count := NA_integer_]
  }

  # entity identity: identifier when present, else type-scoped surface form
  rel[, ent1_key := data.table::fifelse(
    !is.na(ent1_identifier) & nzchar(ent1_identifier),
    as.character(ent1_identifier), paste(ent1_type, ent1_text, sep = ":"))]
  rel[, ent2_key := data.table::fifelse(
    !is.na(ent2_identifier) & nzchar(ent2_identifier),
    as.character(ent2_identifier), paste(ent2_type, ent2_text, sep = ":"))]
  rel[, sent_key := paste(pmid, ent1_tiab, ent1_sentence_id)]

  out <- rel[, .(
    ent1_type       = ent1_type[1L],
    ent1_identifier = ent1_identifier[1L],
    ent1_text       = .re_mode(ent1_text),
    ent2_type       = ent2_type[1L],
    ent2_identifier = ent2_identifier[1L],
    ent2_text       = .re_mode(ent2_text),
    n_pmids     = data.table::uniqueN(pmid),
    n_sentences = data.table::uniqueN(sent_key[!is.na(sentence)]),
    citation_support = sum(citation_count[!duplicated(pmid)], na.rm = TRUE),
    sentences = list(unique(sentence[!is.na(sentence) & nzchar(sentence)])),
    pmids     = list(unique(pmid))
  ), by = .(relation_type, ent1_key, ent2_key)]

  out[, c("ent1_key", "ent2_key") := NULL]

  if (has_icite) {
    data.table::setorderv(out, c("citation_support", "n_pmids", "n_sentences"),
                          order = c(-1L, -1L, -1L))
  } else {
    out[, citation_support := NULL]
    data.table::setorderv(out, c("n_pmids", "n_sentences"), order = c(-1L, -1L))
  }

  head_cols <- c("relation_type",
                 "ent1_type", "ent1_identifier", "ent1_text",
                 "ent2_type", "ent2_identifier", "ent2_text",
                 "n_pmids", "n_sentences")
  if (has_icite) head_cols <- c(head_cols, "citation_support")
  data.table::setcolorder(out, c(head_cols, "sentences", "pmids"))
  out[]
}

# Most frequent non-empty surface form; ties resolved by first appearance.
#' @noRd
.re_mode <- function(x) {
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return(NA_character_)
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

#' @noRd
.relation_evidence_empty <- function(has_icite) {
  out <- data.table::data.table(
    relation_type = character(),
    ent1_type = character(), ent1_identifier = character(), ent1_text = character(),
    ent2_type = character(), ent2_identifier = character(), ent2_text = character(),
    n_pmids = integer(), n_sentences = integer()
  )
  if (has_icite) out[, citation_support := integer()]
  out[, sentences := list()]
  out[, pmids := list()]
  out[]
}
