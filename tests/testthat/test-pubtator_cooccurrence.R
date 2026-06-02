# pubtator_cooccurrence() is a pure transform of a sentence-mapped table.

make_mapped <- function() {
  # PMID 1 abstract: s1 "Gene A causes disease B." (Gene A + Disease B),
  #                  s2 "Chemical C treats disease B." (Chemical C + Disease B);
  # the duplicate Gene A in s1 tests per-sentence de-duplication.
  # PMID 2 has a placeholder row that must be ignored.
  data.table::data.table(
    pmid        = c("1", "1", "1", "1", "1", "1", "2"),
    tiab        = c("title", "abstract", "abstract", "abstract",
                    "abstract", "abstract", "abstract"),
    type        = c("Gene", "Gene", "Disease", "Gene", "Chemical",
                    "Disease", NA),
    identifier  = c("G1", "G1", "D1", "G1", "C1", "D1", NA),
    text        = c("A", "A", "B", "A", "C", "B", NA),
    sentence_id = c(0L, 1L, 1L, 1L, 2L, 2L, NA),
    sentence    = c("Gene A.", "Gene A causes disease B.",
                    "Gene A causes disease B.", "Gene A causes disease B.",
                    "Chemical C treats disease B.",
                    "Chemical C treats disease B.", NA)
  )
}

# count for a canonical (sorted) type pair
pair_n <- function(tab, a, b) {
  row <- tab[tab$type_x == a & tab$type_y == b]
  if (nrow(row) == 0L) 0L else row$n
}

test_that("input is validated", {
  expect_error(pubtator_cooccurrence(list()), "data.frame")
  expect_error(pubtator_cooccurrence(data.table::data.table(pmid = "1")),
               "must contain columns")
  expect_error(pubtator_cooccurrence(make_mapped(), window = -1), "window")
  expect_error(pubtator_cooccurrence(make_mapped(), evidence = NA), "evidence")
})

test_that("window = 0 counts same-sentence type pairs", {
  res <- pubtator_cooccurrence(make_mapped(), window = 0, by = "type")
  expect_equal(pair_n(res, "Disease", "Gene"), 1L)
  expect_equal(pair_n(res, "Chemical", "Disease"), 1L)
  expect_equal(pair_n(res, "Chemical", "Gene"), 0L)   # different sentences
})

test_that("window = 1 reaches across adjacent sentences", {
  res <- pubtator_cooccurrence(make_mapped(), window = 1, by = "type")
  expect_equal(pair_n(res, "Disease", "Gene"), 2L)
  expect_equal(pair_n(res, "Chemical", "Disease"), 2L)
  expect_equal(pair_n(res, "Chemical", "Gene"), 1L)
})

test_that("same entity does not pair with itself", {
  # duplicate Gene A plus Gene A across the window must never yield Gene-Gene
  res <- pubtator_cooccurrence(make_mapped(), window = 2, by = "type")
  expect_equal(pair_n(res, "Gene", "Gene"), 0L)
})

test_that("by = 'entity' returns specific entity columns", {
  res <- pubtator_cooccurrence(make_mapped(), window = 0, by = "entity")
  expect_true(all(c("type_x", "identifier_x", "text_x",
                    "type_y", "identifier_y", "text_y",
                    "n", "n_pmids") %in% names(res)))
})

test_that("counts report distinct documents in n_pmids", {
  res <- pubtator_cooccurrence(make_mapped(), window = 0, by = "type")
  expect_true(all(res$n_pmids == 1L))   # only PMID 1 has co-occurrences
})

test_that("evidence returns de-duplicated contexts for counted pairs", {
  ev <- pubtator_cooccurrence(make_mapped(), window = 1, evidence = TRUE)
  counts <- pubtator_cooccurrence(make_mapped(), window = 1, by = "type")
  expect_true(all(c("pmid", "tiab", "type_x", "identifier_x", "text_x",
                    "type_y", "identifier_y", "text_y", "context") %in%
                    names(ev)))
  expect_false("sentence_id_x" %in% names(ev))
  expect_false(any(is.na(ev$context)))
  expect_equal(anyDuplicated(ev), 0L)   # de-duplicated
  # every counted type-pair is represented in the evidence
  ev_pairs <- unique(ev[, .(type_x, type_y)])
  expect_setequal(paste(ev_pairs$type_x, ev_pairs$type_y),
                  paste(counts$type_x, counts$type_y))
})

test_that("empty input yields a zero-row table with the right columns", {
  res <- pubtator_cooccurrence(make_mapped()[type == "nope"], window = 0)
  expect_equal(nrow(res), 0L)
  expect_true(all(c("type_x", "type_y", "n", "n_pmids") %in% names(res)))
})
