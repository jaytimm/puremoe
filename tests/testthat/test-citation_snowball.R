# citation_snowball() is a pure transform of an iCite table; no network needed.

make_icites <- function() {
  # Seeds 1, 2. Candidate 100 is cited by both seeds; candidate 200 cites both.
  # PMIDs must be all-digit: citation_snowball() drops non-numeric links.
  data.table::data.table(
    pmid = c("1", "2"),
    citation_net = list(
      data.table::data.table(from = c("1", "200"), to = c("100", "1")),
      data.table::data.table(from = c("2", "200"), to = c("100", "2"))
    )
  )
}

test_that("input is validated", {
  expect_error(citation_snowball(list()), "data.frame")
  expect_error(citation_snowball(data.table::data.table(x = 1)), "pmid")
  expect_error(citation_snowball(data.table::data.table(pmid = "1")),
               "citation_net")
})

test_that("seeds are always returned and flagged", {
  res <- citation_snowball(make_icites(), direction = "both", min_links = 1)
  expect_true(is.logical(res$seed))
  expect_setequal(res$pmid[res$seed], c("1", "2"))
  expect_true(all(c("pmid", "seed", "cited_links", "citing_links",
                    "link_count") %in% names(res)))
})

test_that("direction = 'cited' counts seeds that cite a candidate", {
  res <- citation_snowball(make_icites(), direction = "cited", min_links = 2)
  cand <- res[!res$seed]
  expect_equal(cand$pmid, "100")
  expect_equal(cand$cited_links, 2L)
  expect_equal(cand$link_count, 2L)
})

test_that("direction = 'citing' counts seeds cited by a candidate", {
  res <- citation_snowball(make_icites(), direction = "citing", min_links = 2)
  cand <- res[!res$seed]
  expect_equal(cand$pmid, "200")
  expect_equal(cand$citing_links, 2L)
})

test_that("direction = 'both' admits candidates from either direction", {
  res <- citation_snowball(make_icites(), direction = "both", min_links = 2)
  expect_setequal(res$pmid[!res$seed], c("100", "200"))
})

test_that("min_links filters out weakly linked candidates", {
  res <- citation_snowball(make_icites(), direction = "cited", min_links = 3)
  expect_true(all(res$seed))
})

test_that("max_nodes caps the corpus after seeds are retained", {
  res <- citation_snowball(make_icites(), direction = "both",
                           min_links = 1, max_nodes = 2)
  expect_equal(nrow(res), 2L)
  expect_true(all(res$seed))
})

test_that("empty citation links return seeds only", {
  ic <- data.table::data.table(
    pmid = "1",
    citation_net = list(
      data.table::data.table(from = character(), to = character())
    )
  )
  res <- citation_snowball(ic)
  expect_equal(res$pmid, "1")
  expect_true(res$seed)
})
