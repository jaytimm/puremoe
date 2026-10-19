#' Scrape Full Text Entries from 'PubMed Central' (PMC)
#'
#' Retrieves full-text articles from the PMC Cloud Service on AWS S3
#' using direct XML URLs (e.g., from \code{\link{pmid_to_ftp}}).
#' @param x A vector of HTTPS URLs to PMC XML files.
#' @return A data.table with columns for pmid, section, and text.
#' @importFrom xml2 read_xml xml_find_all xml_find_first xml_text xml_ns_strip
#' @noRd
#'
#'
.get_pmc <- function(x, sleep) {

  flist <- list()

  for (q in seq_along(x)) {

    fn <- x[q]

    x0 <- tryCatch({
      xml2::read_xml(fn)
    }, error = function(e) {
      NULL
    })

    if (!is.null(x0)) {
      pmid <- xml2::xml_text(
        xml2::xml_find_first(
          x0,
          ".//article-meta//article-id[@pub-id-type='pmid']"
        )
      )

      body <- xml2::xml_find_first(x0, ".//body")

      if (!is.null(body) && length(body) > 0) {
        secs <- xml2::xml_find_all(body, "./sec")

        if (length(secs) > 0) {
          header_titles <- lapply(secs, function(sec) {
            title_node <- xml2::xml_find_first(sec, "./title")
            if (length(title_node) > 0) xml2::xml_text(title_node)
            else NA_character_
          })

          text <- lapply(secs, function(sec) {
            # The title is returned separately in the section column; remove
            # that direct child before collecting the remaining XML text.
            title_node <- xml2::xml_find_first(sec, "./title")
            if (length(title_node) > 0) {
              xml2::xml_remove(title_node)
            }

            text_parts <- xml2::xml_text(
              xml2::xml_find_all(sec, ".//text()")
            )
            text_parts <- trimws(gsub("[[:space:]]+", " ", text_parts))
            text_parts <- text_parts[nzchar(text_parts)]
            paste(text_parts, collapse = " ")
          })

          df <- data.frame(pmid,
                           section = unlist(header_titles),
                           text = unlist(text),
                           row.names = NULL)

          flist[[q]] <- df
        }
      }
    }
    Sys.sleep(sleep)
  }

  data.table::rbindlist(flist)
}
