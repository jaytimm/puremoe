test_that("PMC section text excludes its separately returned heading", {
  xml <- paste0(
    "<article><front><article-meta>",
    "<article-id pub-id-type='pmid'>12345</article-id>",
    "</article-meta></front><body><sec>",
    "<title>INTRODUCTION</title>",
    "<p>Emergency department visits are common.</p>",
    "<p>A second paragraph follows.</p>",
    "<sec><title>Nested heading</title><p>Nested text remains.</p></sec>",
    "</sec></body></article>"
  )
  path <- tempfile(fileext = ".xml")
  writeLines(xml, path)
  on.exit(unlink(path), add = TRUE)

  result <- puremoe:::.get_pmc(path, sleep = 0)

  expect_equal(result$pmid, "12345")
  expect_equal(result$section, "INTRODUCTION")
  expect_false(startsWith(result$text, "INTRODUCTION"))
  expect_match(result$text, "^Emergency department")
  expect_match(result$text, "A second paragraph follows")
  expect_match(result$text, "Nested heading Nested text remains")
})
