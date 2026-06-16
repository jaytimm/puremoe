# pubtator_cooccurrence() counts from a pubtator_context() result or its entity table.

make_context_entities <- function() {
  data.table::data.table(
    pmid        = c("1", "1", "1", "1", "1", "1", "2"),
    tiab        = c("title", "abstract", "abstract", "abstract",
                    "abstract", "abstract", "abstract"),
    type        = c("Gene", "Gene", "Disease", "Gene", "Chemical",
                    "Disease", NA),
    identifier  = c("G1", "G1", "D1", "G1", "C1", "D1", NA),
    text        = c("A", "A", "B", "A", "C", "B", NA),
    sentence_id = c(0L, 1L, 1L, 1L, 2L, 2L, NA)
  )
}

make_context <- function() {
  list(
    entities = make_context_entities(),
    relations = data.table::data.table(),
    sentences = data.table::data.table()
  )
}

pair_n <- function(tab, a, b) {
  row <- tab[tab$type_x == a & tab$type_y == b]
  if (nrow(row) == 0L) 0L else row$n
}

test_that("input is validated", {
  expect_error(pubtator_cooccurrence(list()), "pubtator_context")
  expect_error(pubtator_cooccurrence(data.table::data.table(pmid = "1")),
               "must be a pubtator_context")
  expect_error(pubtator_cooccurrence(make_context(), window = -1), "window")
})

test_that("context list and entity table inputs give the same counts", {
  from_context <- pubtator_cooccurrence(make_context(), window = 0, by = "type")
  from_entities <- pubtator_cooccurrence(make_context_entities(), window = 0, by = "type")
  expect_equal(from_context, from_entities)
})

test_that("window = 0 counts same-sentence type pairs", {
  res <- pubtator_cooccurrence(make_context(), window = 0, by = "type")
  expect_equal(pair_n(res, "Disease", "Gene"), 1L)
  expect_equal(pair_n(res, "Chemical", "Disease"), 1L)
  expect_equal(pair_n(res, "Chemical", "Gene"), 0L)
})

test_that("window = 1 reaches across adjacent sentences", {
  res <- pubtator_cooccurrence(make_context(), window = 1, by = "type")
  expect_equal(pair_n(res, "Disease", "Gene"), 2L)
  expect_equal(pair_n(res, "Chemical", "Disease"), 2L)
  expect_equal(pair_n(res, "Chemical", "Gene"), 1L)
})

test_that("same entity does not pair with itself", {
  res <- pubtator_cooccurrence(make_context(), window = 2, by = "type")
  expect_equal(pair_n(res, "Gene", "Gene"), 0L)
})

test_that("by = 'entity' returns specific entity columns", {
  res <- pubtator_cooccurrence(make_context(), window = 0, by = "entity")
  expect_true(all(c("type_x", "identifier_x", "text_x",
                    "type_y", "identifier_y", "text_y",
                    "n", "n_pmids") %in% names(res)))
})

test_that("counts report distinct documents in n_pmids", {
  res <- pubtator_cooccurrence(make_context(), window = 0, by = "type")
  expect_true(all(res$n_pmids == 1L))
})

test_that("empty input yields a zero-row table with the right columns", {
  res <- pubtator_cooccurrence(make_context_entities()[type == "nope"], window = 0)
  expect_equal(nrow(res), 0L)
  expect_true(all(c("type_x", "type_y", "n", "n_pmids") %in% names(res)))
})
