# puremoe

[![CRAN version](https://www.r-pkg.org/badges/version/puremoe)](https://cran.r-project.org/package=puremoe)
[![CRAN downloads](http://cranlogs.r-pkg.org/badges/last-month/puremoe)](https://cran.r-project.org/package=puremoe)

`puremoe` is an R package that unifies access to PubMed and NLM data behind a single retrieval function. Search PubMed, then pull abstracts, citation metrics, named-entity annotations, full-text articles, or MeSH resources -- all as plain `data.table` objects, all pipe-compatible, no juggling separate APIs or output formats.

---

## Installation

From CRAN:

```r
install.packages("puremoe")
```

Development version:

```r
remotes::install_github("jaytimm/puremoe")
```

---

## The `puremoe` API

### Search

- **`search_pubmed(query, ...)`** -- PubMed query string → character vector of PMIDs. Accepts standard PubMed syntax: field tags (`[TiAb]`, `[MeSH Terms]`, `[DP]`), Boolean operators, wildcards.

### Retrieve

**`get_records(pmids, endpoint, cores, sleep, ncbi_key)`** -- the single retrieval function. Pass PMIDs and name an endpoint; get back a `data.table`.

| endpoint | returns | source |
| --- | --- | --- |
| `pubmed_abstracts` | title, abstract, journal, year, authors, MeSH terms | PubMed E-utilities |
| `pubmed_affiliations` | author × affiliation rows | PubMed E-utilities |
| `icites` | citation count, RCR, NIH percentile, field rate | NIH iCite |
| `pubtations` | gene, disease, chemical, species, mutation annotations | PubTator3 |
| `pmc_fulltext` | full-text sections (requires URLs from `pmid_to_ftp()`) | PMC Open Access |

### ID conversion

- **`pmid_to_pmc(pmids, ...)`** -- PMID → PMC ID + DOI via the NCBI ID Converter.
- **`pmid_to_ftp(pmids, ...)`** -- PMID → PMC ID + open-access FTP URL; pass URLs to `get_records(endpoint = "pmc_fulltext")`.

### MeSH reference data

- **`data_mesh_thesaurus()`** -- MeSH descriptor thesaurus + supplementary concept records; one row per term/synonym.
- **`data_mesh_trees()`** -- MeSH hierarchical tree structure; tree numbers encode the classification path.
- **`data_pmc_list()`** -- PMC open-access file list mapping PMC IDs to file paths and licenses.

### Utilities

- **`endpoint_info(endpoint)`** -- column definitions, rate limits, and notes for each endpoint. Returns a list or JSON; useful for tool schemas in LLM applications.

---

## Vignettes

- [Getting started](https://jaytimm.github.io/puremoe/articles/getting-started.html) -- `search_pubmed()` + all `get_records()` endpoints end-to-end
- [MeSH-guided search](https://jaytimm.github.io/puremoe/articles/mesh-search.html) -- thesaurus lookup, tree navigation, and controlled-vocabulary queries

---

## License

MIT © [Jason Timm](https://github.com/jaytimm)

## Citation

```r
citation("puremoe")
```

## Issues

Report bugs or request features at <https://github.com/jaytimm/puremoe/issues>
