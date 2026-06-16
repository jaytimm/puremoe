# pubtator_network() builds a relation network with lean evidence.

make_context_entities <- function() {
  data.table::data.table(
    pmid        = c("1", "1", "1", "2", "2", "2"),
    tiab        = "abstract",
    sentence_id = c(1L, 1L, 2L, 1L, 1L, 1L),
    type        = c("Chemical", "Disease", "Gene", "Chemical", "Disease", "Gene"),
    identifier  = c("MESH:D1", "MESH:D2", "G1", "MESH:D1", "MESH:D2", NA),
    text        = c("doxorubicin", "cardiotoxicity", "TOP2B",
                    "doxorubicin", "cardiomyopathy", "p53")
  )
}

make_relations <- function() {
  data.table::data.table(
    pmid               = c("1", "2", "2"),
    relation_id        = c("R1", "R2", "R3"),
    relation_type      = c("treat", "treat", "cause"),
    score              = c(0.9, 0.8, 0.7),
    ent1_mention_index = c(0L, 0L, 0L),
    ent1_type          = "Chemical",
    ent1_identifier    = "MESH:D1",
    ent1_text          = "doxorubicin",
    ent1_tiab          = "abstract",
    ent1_sentence_id   = c(1L, 1L, 1L),
    ent2_mention_index = c(1L, 1L, 2L),
    ent2_type          = c("Disease", "Disease", "Gene"),
    ent2_identifier    = c("MESH:D2", "MESH:D2", NA),
    ent2_text          = c("cardiotoxicity", "cardiomyopathy", "p53"),
    ent2_tiab          = "abstract",
    ent2_sentence_id   = c(1L, 1L, 2L),
    same_sentence      = c(TRUE, TRUE, FALSE),
    sentence_distance  = c(0L, 0L, 1L)
  )
}

make_sentences <- function() {
  data.table::data.table(
    pmid           = c("1", "2", "2"),
    tiab           = "abstract",
    passage_offset = 0L,
    sentence_id    = c(1L, 1L, 2L),
    sentence       = c("Doxorubicin treats cardiotoxicity.",
                       "Doxorubicin treats cardiomyopathy.",
                       "p53 changes later.")
  )
}

make_context <- function() {
  list(
    entities  = make_context_entities(),
    relations = make_relations(),
    sentences = make_sentences()
  )
}

test_that("input is validated", {
  expect_error(pubtator_network(list()), "pubtator_context")
  bad <- make_context()
  bad$relations <- data.table::data.table(pmid = "1")
  expect_error(pubtator_network(bad), "context columns")
})

test_that("network returns nodes, edges, and lean evidence", {
  net <- pubtator_network(make_context())

  expect_named(net, c("nodes", "edges", "evidence"))
  expect_true(all(c("id", "type", "label", "n_mentions", "n_pmids") %in% names(net$nodes)))
  expect_true(all(c("from", "to", "relation_type", "weight", "n_pmids",
                    "n_sentences") %in% names(net$edges)))
  expect_named(net$evidence, c("from", "to", "relation_type", "pmid",
                                "relation_id", "same_sentence",
                                "sentence_distance", "sentence"))
})

test_that("relation edges collapse by normalized entity endpoint", {
  net <- pubtator_network(make_context())

  d1d2 <- net$edges[net$edges$from == "MESH:D1" & net$edges$to == "MESH:D2"]
  expect_equal(nrow(d1d2), 1L)
  expect_equal(d1d2$relation_type, "treat")
  expect_equal(d1d2$weight, 2L)
  expect_equal(d1d2$n_pmids, 2L)
  expect_equal(d1d2$n_sentences, 2L)

  expect_equal(nrow(net$edges[net$edges$from == "MESH:D2"]), 0L)
})

test_that("evidence maps edges to relation ids and same-sentence text", {
  net <- pubtator_network(make_context())

  ev <- net$evidence[net$evidence$from == "MESH:D1" & net$evidence$to == "MESH:D2"]
  expect_setequal(ev$relation_id, c("R1", "R2"))
  expect_true(all(ev$same_sentence))
  expect_true(all(grepl("Doxorubicin", ev$sentence)))

  cross <- net$evidence[net$evidence$relation_id == "R3"]
  expect_false(cross$same_sentence)
  expect_true(is.na(cross$sentence))
  expect_equal(cross$to, "Gene:p53")
})

test_that("nodes key on identifiers with type:text fallback", {
  net <- pubtator_network(make_context())

  d2 <- net$nodes[net$nodes$id == "MESH:D2"]
  expect_equal(nrow(d2), 1L)
  expect_equal(d2$n_mentions, 2L)
  expect_true("Gene:p53" %in% net$nodes$id)
})

test_that("empty relation corpus yields zero-row outputs with the right columns", {
  empty <- list(
    entities  = make_context_entities()[type == "nope"],
    relations = make_relations()[0],
    sentences = make_sentences()[0]
  )
  net <- pubtator_network(empty)

  expect_equal(nrow(net$nodes), 0L)
  expect_equal(nrow(net$edges), 0L)
  expect_equal(nrow(net$evidence), 0L)
  expect_true(all(c("id", "type", "label", "n_mentions", "n_pmids") %in% names(net$nodes)))
  expect_true(all(c("from", "to", "relation_type", "weight", "n_pmids",
                    "n_sentences") %in% names(net$edges)))
  expect_true(all(c("from", "to", "relation_type", "pmid", "relation_id",
                    "sentence") %in% names(net$evidence)))
})
