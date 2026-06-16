make_pubtator_payload <- function() {
  list(
    PubTator3 = list(
      list(
        id = "1",
        passages = list(
          list(
            infons = list(type = "title"),
            offset = 0L,
            text = "Gene A treats disease B.",
            annotations = list(
              list(
                id = "0",
                text = "A",
                infons = list(type = "Gene", identifier = "G1"),
                locations = list(list(offset = 5L, length = 1L))
              ),
              list(
                id = "1",
                text = "B",
                infons = list(type = "Disease", identifier = "D1"),
                locations = list(list(offset = 22L, length = 1L))
              )
            )
          ),
          list(
            infons = list(type = "abstract"),
            offset = 24L,
            text = "Chemical C helps. Disease B returns.",
            annotations = list(
              list(
                id = "2",
                text = "C",
                infons = list(type = "Chemical", identifier = "C1"),
                locations = list(list(offset = 33L, length = 1L))
              ),
              list(
                id = "3",
                text = "B",
                infons = list(type = "Disease", identifier = "D1"),
                locations = list(list(offset = 50L, length = 1L))
              )
            )
          )
        ),
        relations = list(
          list(
            id = "r1",
            infons = list(
              type = "Association",
              score = "0.9",
              role1 = list(type = "Gene"),
              role2 = list(type = "Disease")
            ),
            nodes = list(list(role = "0,1"))
          ),
          list(
            id = "r2",
            infons = list(
              type = "Positive_Correlation",
              score = "0.8",
              role1 = list(type = "Chemical"),
              role2 = list(type = "Disease")
            ),
            nodes = list(list(role = "2,3"))
          )
        )
      )
    )
  )
}

test_that("PubTator parser returns entities and compact relations", {
  pt <- .parse_pubtator_payload(make_pubtator_payload())

  expect_named(pt, c("entities", "relations"))
  expect_true(all(c("pmid", "mention_index", "text", "type", "identifier",
                    "tiab", "start", "end", "passage_text",
                    "passage_offset") %in% names(pt$entities)))
  expect_equal(pt$entities$mention_index, 0:3)

  expect_true(all(c("relation_id", "relation_type", "ent1_mention_index",
                    "ent1_type", "ent2_mention_index", "ent2_type") %in%
                    names(pt$relations)))
  expect_equal(pt$relations$relation_type,
               c("association", "positive_correlation"))
})

test_that("pubtator_context preserves relation row order", {
  pt <- .parse_pubtator_payload(make_pubtator_payload())
  pt$relations <- data.table::rbindlist(list(
    pt$relations,
    data.table::copy(pt$relations[1])
  ))
  pt$relations$relation_id <- c("R1", "R2", "R10")

  ctx <- pubtator_context(pt)

  expect_equal(ctx$relations$relation_id, pt$relations$relation_id)
})

test_that("pubtator_context adds entity labels and sentence anchors to relations", {
  pt <- .parse_pubtator_payload(make_pubtator_payload())
  ctx <- pubtator_context(pt)

  expect_named(ctx, c("entities", "relations", "sentences"))
  expect_true(all(c("start", "end", "sentence_id", "sentence_start",
                    "sentence_end") %in% names(ctx$entities)))
  expect_true(all(c("pmid", "tiab", "passage_offset", "sentence_id",
                    "sentence") %in% names(ctx$sentences)))
  expect_true(all(c("ent1_text", "ent1_identifier", "ent1_tiab", "ent1_sentence_id", "ent2_tiab",
                    "ent2_text", "ent2_identifier", "ent2_sentence_id", "same_sentence",
                    "sentence_distance") %in% names(ctx$relations)))

  ents_with_sentence <- merge(
    ctx$entities,
    ctx$sentences,
    by = c("pmid", "tiab", "passage_offset", "sentence_id")
  )
  recovered <- substr(
    ents_with_sentence$sentence,
    ents_with_sentence$sentence_start + 1L,
    ents_with_sentence$sentence_end
  )
  expect_equal(recovered, ents_with_sentence$text)

  r1 <- ctx$relations[relation_id == "r1"]
  expect_equal(r1$ent1_sentence_id, 0L)
  expect_equal(r1$ent2_sentence_id, 0L)
  expect_true(r1$same_sentence)
  expect_equal(r1$sentence_distance, 0L)

  r2 <- ctx$relations[relation_id == "r2"]
  expect_equal(r2$ent1_sentence_id, 1L)
  expect_equal(r2$ent2_sentence_id, 2L)
  expect_false(r2$same_sentence)
  expect_equal(r2$sentence_distance, 1L)
})
