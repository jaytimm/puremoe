# mesh_keyness() scores corpus MeSH descriptors against a baseline.

make_records <- function() {
  data.table::data.table(
    pmid           = c("1", "2", "3", "4", "1", "1"),
    type           = c("MeSH", "MeSH", "MeSH", "MeSH", "MeSH", "Keyword"),
    DescriptorUI   = c("D1", "D1", "D1", "D1", "D2", "K1"),
    DescriptorName = c("Alpha", "Alpha", "Alpha", "Alpha", "Beta", "kw")
  )
}

make_freq <- function() {
  data.table::data.table(
    DescriptorUI   = c("D1", "D2"),
    DescriptorName = c("Alpha", "Beta"),
    n_pmids        = c(1000, 100000),
    prop_total     = c(1000 / 1e6, 100000 / 1e6)
  )
}

test_that("inputs are validated", {
  expect_error(mesh_keyness(make_records(), make_freq(), smoothing = 0), "smoothing")
  expect_error(mesh_keyness(make_records(), make_freq(), min_count = 0), "min_count")
  expect_error(mesh_keyness(make_freq()[, .(DescriptorUI)]),
               "annotations|DescriptorUI|pmid")
})

test_that("rarer-in-PubMed descriptors score higher (log_odds)", {
  res <- mesh_keyness(make_records(), make_freq(), measure = "log_odds")
  expect_equal(res$DescriptorUI[1], "D1")        # 4/4 corpus vs 0.001 baseline
  expect_true(all(c("log_odds", "std_error", "z") %in% names(res)))
  expect_true(all(res$direction == "over"))
  expect_equal(unique(res$corpus_total), 4L)
  expect_equal(res[DescriptorUI == "D1"]$corpus_count, 4L)
})

test_that("g2 measure returns a signed g2 column and orders by it", {
  res <- mesh_keyness(make_records(), make_freq(), measure = "g2")
  expect_true("g2" %in% names(res))
  expect_equal(res$DescriptorUI[1], "D1")
  expect_true(res$g2[1] >= res$g2[nrow(res)])
})

test_that("non-MeSH annotation rows are ignored", {
  res <- mesh_keyness(make_records(), make_freq())
  expect_false("K1" %in% res$DescriptorUI)
})

test_that("min_count drops infrequent descriptors", {
  res <- mesh_keyness(make_records(), make_freq(), min_count = 2)
  expect_equal(res$DescriptorUI, "D1")           # D2 appears in only one PMID
})

test_that("descriptors absent from the baseline get zero baseline count", {
  recs <- rbind(make_records(),
                data.table::data.table(pmid = "2", type = "MeSH",
                                       DescriptorUI = "D9", DescriptorName = "Novel"))
  res <- mesh_keyness(recs, make_freq())
  expect_equal(res[DescriptorUI == "D9"]$baseline_count, 0)
  expect_equal(res[DescriptorUI == "D9"]$direction, "over")
})

test_that("empty corpus yields a zero-row table with the right columns", {
  empty <- make_records()[type == "nope"]
  res <- mesh_keyness(empty, make_freq())
  expect_equal(nrow(res), 0L)
  expect_true(all(c("DescriptorUI", "corpus_prop", "baseline_prop",
                    "direction", "z") %in% names(res)))
})

test_that("an annotations list-column is unnested", {
  records <- data.table::data.table(
    pmid = c("1", "2"),
    annotations = list(
      data.frame(pmid = "1", type = "MeSH",
                 DescriptorName = "Alpha", DescriptorUI = "D1"),
      data.frame(pmid = "2", type = "MeSH",
                 DescriptorName = c("Alpha", "Beta"),
                 DescriptorUI = c("D1", "D2"))
    )
  )
  res <- mesh_keyness(records, make_freq())
  expect_equal(res[DescriptorUI == "D1"]$corpus_count, 2L)
  expect_equal(unique(res$corpus_total), 2L)
})
