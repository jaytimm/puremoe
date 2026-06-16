# Contributing to puremoe

Thanks for your interest in improving `puremoe`. This document explains how to
report problems, suggest changes, and submit code.

## Reporting bugs and requesting features

Please use the [issue tracker](https://github.com/jaytimm/puremoe/issues).

A good bug report includes:

- a short description of what you expected and what happened instead;
- a **minimal reproducible example** — ideally a small set of PMIDs and the
  `get_records()` / analysis call that misbehaves;
- the output of `sessionInfo()` and your `puremoe` version.

Because `puremoe` talks to external services (PubMed E-utilities, iCite,
PubTator3, PMC, MeSH), please note whether the problem looks like a change in an
upstream API response — those are useful to flag explicitly.

## Asking questions

For usage questions that aren't bugs, open an issue with the question and the
code you've tried. The vignettes (`getting-started`, `mesh-search`,
`citation-snowball`, `pubtator-sentences`) cover the main workflows and are a
good first stop.

## Development setup

```r
# from a clone of the repo
install.packages(c("devtools", "roxygen2", "testthat"))
devtools::install_deps(dependencies = TRUE)

devtools::load_all()    # load the package
devtools::test()        # run the test suite
devtools::document()    # regenerate NAMESPACE + man/ from roxygen
devtools::check()       # full R CMD check
```

## Pull requests

1. Fork the repository and create a topic branch off `main`.
2. Make your change, following the conventions below.
3. Add or update tests in `tests/testthat/` and make sure `devtools::test()`
   passes.
4. Run `devtools::document()` if you changed any roxygen comments, and
   `devtools::check()` to confirm a clean build.
5. Update `NEWS.md` with a short entry describing the change.
6. Open a pull request describing the motivation and the change.

## Conventions

- **Data structures.** Functions return `data.table` objects; new code should
  use `data.table` rather than introducing a `dplyr`/tidyverse dependency in
  `R/` (`dplyr` is used only in vignettes).
- **Naming.** Retrieval functions that call an external service are verb-first
  (`search_pubmed()`, `get_records()`, `pmid_to_*()`); local analysis functions
  that transform already-retrieved tables are source-first
  (`citation_snowball()`, `citation_network()`, `pubtator_context()`,
  `pubtator_cooccurrence()`). Please keep new functions consistent with this
  split.
- **Documentation.** Document exported functions with roxygen2 and regenerate
  `man/` rather than editing `.Rd` files by hand.
- **Tests.** Prefer testing pure transforms on small synthetic inputs (no
  network). Guard any test that hits a live service with `skip_on_cran()` and
  `skip_if_offline()`.
