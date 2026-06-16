#' MeSH Descriptor Keyness for a Retrieved Corpus
#'
#' Scores the MeSH descriptors of a retrieved corpus against PubMed-wide
#' descriptor frequencies, identifying the terms that are over- or
#' under-represented relative to PubMed as a whole. This is a local transform of
#' the \code{pubmed_abstracts} output -- it makes no API calls -- and is intended
#' to characterise a corpus and to guide search refinement and expansion.
#'
#' Keyness is computed on document incidence: for each descriptor, the number of
#' distinct corpus PMIDs indexed with it is compared against the number of
#' distinct PubMed PMIDs indexed with it (\code{\link{data_mesh_frequencies}}).
#'
#' @param records A \code{pubmed_abstracts} table from
#'   \code{\link{get_records}(endpoint = "pubmed_abstracts")} (with its
#'   \code{annotations} list-column), or a long data.frame already exposing
#'   \code{pmid} and \code{DescriptorUI} (optionally \code{DescriptorName} and a
#'   \code{type} column, in which case only \code{type == "MeSH"} rows are used).
#' @param frequencies Baseline descriptor frequencies. Defaults to the bundled
#'   \code{\link{data_mesh_frequencies}}; must contain \code{DescriptorUI},
#'   \code{n_pmids}, and \code{prop_total}.
#' @param measure Keyness statistic: \code{"log_odds"} (default) for a
#'   Haldane-corrected log odds ratio with standard error and z-score, or
#'   \code{"g2"} for the signed Dunning log-likelihood ratio.
#' @param smoothing Positive continuity correction added to each cell of the
#'   2x2 incidence table for \code{measure = "log_odds"} (default \code{0.5},
#'   the Haldane-Anscombe correction).
#' @param min_count Drop descriptors indexed in fewer than \code{min_count}
#'   corpus PMIDs before scoring (default \code{1}).
#'
#' @return A data.table, one row per scored descriptor, ordered by keyness
#'   (descending). Common columns: \code{DescriptorUI}, \code{DescriptorName},
#'   \code{corpus_count}, \code{corpus_total}, \code{corpus_prop},
#'   \code{baseline_count}, \code{baseline_total}, \code{baseline_prop}, and
#'   \code{direction} (\code{"over"}/\code{"under"}). With
#'   \code{measure = "log_odds"}: \code{log_odds}, \code{std_error}, \code{z}.
#'   With \code{measure = "g2"}: \code{g2}.
#'
#' @importFrom data.table as.data.table copy rbindlist setnames setorderv fcoalesce
#' @export
#' @examples
#' \dontrun{
#' pmids   <- search_pubmed('"doxorubicin"[TiAb] AND "cardiotoxicity"[TiAb]')
#' records <- get_records(pmids, endpoint = "pubmed_abstracts")
#'
#' mesh_keyness(records)                       # most over-represented descriptors
#' mesh_keyness(records, measure = "g2")
#' }
mesh_keyness <- function(records,
                         frequencies = NULL,
                         measure = c("log_odds", "g2"),
                         smoothing = 0.5,
                         min_count = 1L) {

  DescriptorUI <- DescriptorName <- pmid <- corpus_count <- NULL
  n_pmids <- prop_total <- baseline_count <- baseline_prop <- NULL
  baseline_name <- NULL

  measure <- match.arg(measure)
  if (!is.numeric(smoothing) || length(smoothing) != 1L ||
      is.na(smoothing) || smoothing <= 0) {
    stop("smoothing must be a single positive number")
  }
  min_count <- as.integer(min_count[1L])
  if (is.na(min_count) || min_count < 1L) {
    stop("min_count must be a positive integer")
  }

  if (is.null(frequencies)) {
    frequencies <- .mesh_keyness_baseline()
    if (is.null(frequencies)) {
      stop("data_mesh_frequencies is unavailable; pass `frequencies` explicitly")
    }
  }
  freq <- data.table::as.data.table(frequencies)
  if (!all(c("DescriptorUI", "n_pmids", "prop_total") %in% names(freq))) {
    stop("frequencies must contain DescriptorUI, n_pmids, and prop_total")
  }

  ext <- .mesh_keyness_descriptors(records)
  corpus_total <- length(ext$pmids)
  mesh <- ext$mesh

  if (corpus_total == 0L || nrow(mesh) == 0L) {
    return(.mesh_keyness_empty(measure))
  }

  mesh <- unique(mesh[, .(pmid, DescriptorUI, DescriptorName)])
  counts <- mesh[, .(corpus_count = .N, DescriptorName = DescriptorName[1L]),
                 by = DescriptorUI]
  counts <- counts[corpus_count >= min_count]
  if (nrow(counts) == 0L) {
    return(.mesh_keyness_empty(measure))
  }

  freq <- freq[, .(DescriptorUI = as.character(DescriptorUI),
                   baseline_count = as.numeric(n_pmids),
                   baseline_prop = as.numeric(prop_total),
                   baseline_name = if ("DescriptorName" %in% names(freq))
                     as.character(get("DescriptorName")) else NA_character_)]

  # Total PubMed PMIDs implied by the baseline (n_pmids / prop_total).
  ratios <- freq$baseline_count / freq$baseline_prop
  ratios <- ratios[is.finite(ratios) & ratios > 0]
  baseline_total <- if (length(ratios)) round(mean(ratios)) else NA_real_

  out <- merge(counts, freq, by = "DescriptorUI", all.x = TRUE, sort = FALSE)
  out[is.na(baseline_count), baseline_count := 0]
  out[, baseline_prop := baseline_count / baseline_total]
  out[, DescriptorName := data.table::fcoalesce(DescriptorName, baseline_name)]
  out[, baseline_name := NULL]
  out[, corpus_total := corpus_total]
  out[, corpus_prop := corpus_count / corpus_total]
  out[, direction := data.table::fifelse(corpus_prop >= baseline_prop, "over", "under")]

  a <- out$corpus_count
  b <- corpus_total - a
  cc <- out$baseline_count
  d <- baseline_total - cc

  if (measure == "log_odds") {
    a2 <- a + smoothing; b2 <- b + smoothing
    c2 <- cc + smoothing; d2 <- d + smoothing
    out[, log_odds := log((a2 * d2) / (b2 * c2))]
    out[, std_error := sqrt(1 / a2 + 1 / b2 + 1 / c2 + 1 / d2)]
    out[, z := log_odds / std_error]
    data.table::setorderv(out, "z", order = -1L)
  } else {
    out[, g2 := .mesh_keyness_g2(a, b, cc, d)]
    data.table::setorderv(out, "g2", order = -1L)
  }

  col_order <- c("DescriptorUI", "DescriptorName", "corpus_count", "corpus_total",
                 "corpus_prop", "baseline_count", "baseline_total", "baseline_prop",
                 "direction",
                 if (measure == "log_odds") c("log_odds", "std_error", "z") else "g2")
  out[, baseline_total := baseline_total]
  out <- out[, ..col_order]
  out[]
}

#' @noRd
.mesh_keyness_descriptors <- function(records) {
  if (!is.data.frame(records)) {
    stop("records must be a pubmed_abstracts table or a long MeSH data.frame")
  }
  DT <- data.table::as.data.table(records)

  if ("annotations" %in% names(DT) && is.list(DT[["annotations"]])) {
    pmids <- unique(as.character(DT[["pmid"]]))
    mesh <- data.table::rbindlist(DT[["annotations"]], fill = TRUE)
  } else if ("DescriptorUI" %in% names(DT)) {
    if (!"pmid" %in% names(DT)) stop("records must contain a 'pmid' column")
    pmids <- unique(as.character(DT[["pmid"]]))
    mesh <- data.table::copy(DT)
  } else {
    stop("records must expose an 'annotations' list-column or a 'DescriptorUI' column")
  }

  if (!nrow(mesh) || !"DescriptorUI" %in% names(mesh)) {
    return(list(pmids = pmids,
                mesh = data.table::data.table(
                  pmid = character(), DescriptorUI = character(),
                  DescriptorName = character())))
  }
  if ("type" %in% names(mesh)) {
    mesh <- mesh[mesh$type == "MeSH"]
  }
  mesh[, pmid := as.character(get("pmid"))]
  mesh[, DescriptorUI := as.character(DescriptorUI)]
  if (!"DescriptorName" %in% names(mesh)) mesh[, DescriptorName := NA_character_]
  mesh[, DescriptorName := as.character(DescriptorName)]
  mesh <- mesh[!is.na(DescriptorUI) & nzchar(DescriptorUI)]

  list(pmids = pmids,
       mesh = mesh[, .(pmid, DescriptorUI, DescriptorName)])
}

#' @noRd
.mesh_keyness_g2 <- function(a, b, cc, d) {
  N1 <- a + b            # corpus size (constant across rows)
  N2 <- cc + d           # baseline size (constant across rows)
  total <- N1 + N2
  c1 <- a + cc           # descriptor present
  c2 <- b + d            # descriptor absent
  ea <- N1 * c1 / total; eb <- N1 * c2 / total
  ec <- N2 * c1 / total; ed <- N2 * c2 / total
  term <- function(o, e) ifelse(o > 0, o * log(o / e), 0)
  g2 <- 2 * (term(a, ea) + term(b, eb) + term(cc, ec) + term(d, ed))
  # Sign by direction of corpus over/under-representation.
  sign <- ifelse((a / N1) >= (cc / N2), 1, -1)
  sign * g2
}

#' @noRd
.mesh_keyness_baseline <- function() {
  ns <- tryCatch(asNamespace("puremoe"), error = function(e) NULL)
  if (!is.null(ns)) {
    obj <- get0("data_mesh_frequencies", envir = ns, inherits = FALSE)
    if (!is.null(obj)) return(obj)
  }
  e <- new.env()
  loaded <- tryCatch(
    utils::data("data_mesh_frequencies", package = "puremoe", envir = e),
    error = function(err) NULL
  )
  if (is.null(loaded)) NULL else e[["data_mesh_frequencies"]]
}

#' @noRd
.mesh_keyness_empty <- function(measure) {
  base <- data.table::data.table(
    DescriptorUI = character(), DescriptorName = character(),
    corpus_count = integer(), corpus_total = integer(), corpus_prop = numeric(),
    baseline_count = numeric(), baseline_total = numeric(), baseline_prop = numeric(),
    direction = character()
  )
  if (measure == "log_odds") {
    base[, c("log_odds", "std_error", "z") := list(numeric(), numeric(), numeric())]
  } else {
    base[, g2 := numeric()]
  }
  base[]
}
