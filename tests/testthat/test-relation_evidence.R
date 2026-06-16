# relation_evidence() aggregates relations into a per-relation evidence summary.

make_ctx <- function() {
  relations <- data.table::data.table(
    pmid               = c("1", "2", "3", "4"),
    relation_id        = c("R1", "R2", "R3", "R4"),
    relation_type      = c("treat", "treat", "cause", "treat"),
    score              = c(0.9, 0.8, 0.5, 0.7),
    # rows 1, 2, 4 are the same Doxorubicin->Cardiotoxicity relation
    # (row 2 uses a synonym surface form sharing the identifier)
    ent1_text          = c("Doxorubicin", "DOX", "DrugX", "Doxorubicin"),
    ent1_type          = c("Chemical", "Chemical", "Chemical", "Chemical"),
    ent1_identifier    = c("MESH:D004317", "MESH:D004317", "X1", "MESH:D004317"),
    ent1_tiab          = c("abstract", "abstract", "abstract", "abstract"),
    ent1_sentence_id   = c(1L, 1L, 0L, 2L),
    ent2_text          = c("Cardiotoxicity", "cardiotoxicity", "DiseaseY", "Cardiotoxicity"),
    ent2_type          = c("Disease", "Disease", "Disease", "Disease"),
    ent2_identifier    = c("MESH:D066126", "MESH:D066126", "Y1", "MESH:D066126"),
    ent2_tiab          = c("abstract", "abstract", "abstract", "abstract"),
    ent2_sentence_id   = c(1L, 1L, 1L, 2L),
    same_sentence      = c(TRUE, TRUE, FALSE, TRUE),
    sentence_distance  = c(0L, 0L, 1L, 0L)
  )
  sentences <- data.table::data.table(
    pmid           = c("1", "2", "4", "2", "3"),
    tiab           = "abstract",
    passage_offset = 0L,
    sentence_id    = c(1L, 1L, 2L, 0L, 1L),
    sentence       = c("Doxorubicin induced cardiotoxicity in patients.",
                       "DOX caused cardiotoxicity here.",
                       "Doxorubicin and cardiotoxicity again.",
                       "DrugX was administered.",
                       "DiseaseY then appeared.")
  )
  list(entities = data.table::data.table(),
       relations = relations, sentences = sentences)
}

make_icites <- function() {
  data.table::data.table(pmid = c("1", "2", "3", "4"),
                         citation_count = c(50L, 10L, 100L, 5L))
}

test_that("input is validated", {
  expect_error(relation_evidence(list()), "pubtator_context")
  bad <- make_ctx()
  bad$relations <- data.table::data.table(pmid = "1")
  expect_error(relation_evidence(bad), "context columns")
})

test_that("synonymous mentions collapse into one relation row", {
  res <- relation_evidence(make_ctx(), relation_type = "treat")
  # pmids 1, 2, 4 share MESH:D004317 -> MESH:D066126 despite text variants
  expect_equal(nrow(res), 1L)
  expect_equal(res$n_pmids, 3L)
  expect_equal(res$ent1_identifier, "MESH:D004317")
  expect_equal(res$ent1_text, "Doxorubicin")          # most frequent surface form
})

test_that("supporting sentences and pmids are returned as list-columns", {
  res <- relation_evidence(make_ctx(), relation_type = "treat")
  expect_type(res$sentences, "list")
  expect_type(res$pmids, "list")
  expect_equal(res$n_sentences, length(res$sentences[[1]]))
  expect_setequal(res$pmids[[1]], c("1", "2", "4"))
  expect_true(any(grepl("cardiotoxicity", res$sentences[[1]], ignore.case = TRUE)))
})

test_that("relation_type matching is case-insensitive", {
  expect_equal(nrow(relation_evidence(make_ctx(), relation_type = "TREAT")), 1L)
})

test_that("same_sentence = TRUE drops cross-sentence relations", {
  res <- relation_evidence(make_ctx())
  expect_equal(res$relation_type, "treat")            # the "cause" relation spans sentences
})

test_that("entity matches by text (case-insensitive) and identifier", {
  by_text <- relation_evidence(make_ctx(), entity = "doxorubicin")
  expect_equal(by_text$ent1_identifier, "MESH:D004317")

  by_id <- relation_evidence(make_ctx(), entity = "X1", same_sentence = FALSE)
  expect_equal(by_id$ent1_identifier, "X1")
})

test_that("icites adds citation_support summed over distinct papers and ranks by it", {
  res <- relation_evidence(make_ctx(), same_sentence = FALSE, icites = make_icites())
  expect_true("citation_support" %in% names(res))
  # cause relation (pmid 3) has 100 citations; treat relation has 50+10+5 = 65
  expect_equal(res$relation_type, c("cause", "treat"))
  expect_equal(res$citation_support, c(100L, 65L))
})

test_that("no matches yields a zero-row table with the right columns", {
  res <- relation_evidence(make_ctx(), relation_type = "nope")
  expect_equal(nrow(res), 0L)
  expect_true(all(c("relation_type", "ent1_identifier", "ent2_identifier",
                    "n_pmids", "n_sentences", "sentences", "pmids") %in% names(res)))

  res_ic <- relation_evidence(make_ctx(), relation_type = "nope",
                              icites = make_icites())
  expect_true("citation_support" %in% names(res_ic))
})
