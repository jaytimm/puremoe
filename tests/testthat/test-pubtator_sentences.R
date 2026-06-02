# pubtator_sentences() splits passage text via textpress (no network needed).

make_pubtations <- function() {
  data.table::data.table(
    pmid           = c("1", "1", "1"),
    tiab           = c("title", "abstract", "abstract"),
    text           = c("A", "B", NA),          # row 3 = empty placeholder
    identifier     = c("G1", "D1", NA),
    type           = c("Gene", "Disease", NA),
    start          = c(5L, 8L, NA),
    end            = c(6L, 9L, NA),
    passage_text   = c("Gene A.", "Disease B occurs.", NA),
    passage_offset = c(0L, 0L, NA)
  )
}

test_that("required columns are enforced", {
  expect_error(pubtator_sentences(list()), "data.frame")
  expect_error(pubtator_sentences(data.table::data.table(pmid = "1")),
               "must contain columns")
})

test_that("sentence columns are added and passage metadata is dropped", {
  mapped <- pubtator_sentences(make_pubtations())
  expect_true(all(c("sentence_id", "sentence", "sentence_start",
                    "sentence_end") %in% names(mapped)))
  expect_false(any(c("passage_text", "passage_offset") %in% names(mapped)))
})

test_that("sentence offsets locate the entity within its sentence", {
  mapped <- pubtator_sentences(make_pubtations())
  hit <- mapped[!is.na(mapped$text)]
  # sentence_start/end are zero-based, end-exclusive offsets into `sentence`
  recovered <- substr(hit$sentence, hit$sentence_start + 1L, hit$sentence_end)
  expect_equal(recovered, hit$text)
})

test_that("title annotations get sentence_id 0", {
  mapped <- pubtator_sentences(make_pubtations())
  title_row <- mapped[mapped$tiab == "title" & !is.na(mapped$text)]
  expect_equal(title_row$sentence_id, 0L)
})

test_that("empty placeholder rows are preserved with missing sentence fields", {
  mapped <- pubtator_sentences(make_pubtations())
  placeholder <- mapped[is.na(mapped$text)]
  expect_equal(nrow(placeholder), 1L)
  expect_true(is.na(placeholder$sentence_id))
  expect_true(is.na(placeholder$sentence))
})
