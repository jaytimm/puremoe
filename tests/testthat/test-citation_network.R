# citation_network() is a pure transform of an iCite table; no network needed.

make_icites <- function() {
  data.table::data.table(
    pmid = c("1", "2", "3"),
    relative_citation_ratio = c(1.0, 2.0, 3.0),
    is_clinical = c(TRUE, FALSE, TRUE),
    citation_net = list(
      # 1 -> 2 (in corpus), 1 -> 99 (out of corpus, dropped), duplicate 1 -> 2
      data.table::data.table(from = c("1", "1", "1"),
                             to   = c("2", "99", "2")),
      data.table::data.table(from = "3", to = "2"),
      data.table::data.table(from = character(), to = character())
    )
  )
}

test_that("input is validated", {
  expect_error(citation_network(list()), "data.frame")
  expect_error(citation_network(data.table::data.table(x = 1)), "pmid")
  expect_error(citation_network(data.table::data.table(pmid = "1")),
               "citation_net")
})

test_that("returns a nodes/edges list", {
  net <- citation_network(make_icites())
  expect_named(net, c("nodes", "edges"))
  expect_s3_class(net$nodes, "data.table")
  expect_s3_class(net$edges, "data.table")
})

test_that("nodes carry metadata but drop the citation_net list column", {
  net <- citation_network(make_icites())
  expect_equal(nrow(net$nodes), 3L)
  expect_false("citation_net" %in% names(net$nodes))
  expect_true(all(c("relative_citation_ratio", "is_clinical") %in%
                    names(net$nodes)))
})

test_that("edges keep only within-corpus pairs, de-duplicated", {
  net <- citation_network(make_icites())
  expect_equal(names(net$edges), c("from_pmid", "to_pmid"))
  pairs <- paste(net$edges$from_pmid, net$edges$to_pmid)
  expect_setequal(pairs, c("1 2", "3 2"))   # 1 -> 99 dropped; dup 1 -> 2 collapsed
})

test_that("a corpus with no within-corpus edges returns empty edges", {
  ic <- data.table::data.table(
    pmid = c("1", "2"),
    citation_net = list(
      data.table::data.table(from = "1", to = "99"),
      data.table::data.table(from = character(), to = character())
    )
  )
  net <- citation_network(ic)
  expect_equal(nrow(net$nodes), 2L)
  expect_equal(nrow(net$edges), 0L)
})
