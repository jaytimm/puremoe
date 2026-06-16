# puremoe

[![CRAN version](https://www.r-pkg.org/badges/version/puremoe)](https://cran.r-project.org/package=puremoe)
[![CRAN downloads](http://cranlogs.r-pkg.org/badges/last-month/puremoe)](https://cran.r-project.org/package=puremoe)

`puremoe` provides a consistent R interface for retrieving and analyzing biomedical literature data from public NIH/NLM services. Starting from PubMed identifiers, users can assemble article records, abstracts, affiliations, citation data, PubTator3 annotations and relations, open-access full text, and MeSH resources. The returned data frames feed a small local analysis layer for tasks such as citation expansion, network construction, MeSH keyness, entity co-occurrence, and sentence-level relation evidence.

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
| `pubmed_abstracts` | title, abstract, journal, year, publication type, MeSH terms | PubMed E-utilities |
| `pubmed_affiliations` | author × affiliation rows | PubMed E-utilities |
| `icites` | citation count, RCR, NIH percentile, field rate, clinical flags, citation links | NIH iCite |
| `pubtator` | gene, disease, chemical, species, mutation, and relation annotations (`pubtations` is accepted as a legacy alias) | PubTator3 |
| `pmc_fulltext` | section-level open-access full text (requires URLs from `pmid_to_ftp()`) | PMC Cloud Service |

### Analyze

Functions that transform already-retrieved tables -- no additional API calls.

- **`citation_snowball(icites, direction, min_links, max_nodes)`** -- expand a corpus one hop along iCite citation links; returns a ranked candidate table with audit columns (`seed`, `cited_links`, `citing_links`, `link_count`).
- **`citation_network(icites)`** -- convert an `icites` table into `nodes` + `edges` (within-corpus citations only), carrying RCR and clinical flags as node attributes; ready for `igraph`/`tidygraph`.
- **`pubtator_context(pubtator)`** -- add sentence IDs, sentence-relative entity spans, relation entity labels, relation sentence anchors, and a sentence lookup table to PubTator output.
- **`pubtator_cooccurrence(ctx, window, by)`** -- count entity pairs co-occurring within or across sentences in a `pubtator_context()` result.
- **`pubtator_network(ctx)`** -- convert PubTator relations into `nodes`, `edges`, and lean `evidence` tables for graph workflows and edge inspection.
- **`relation_evidence(ctx, relation_type, entity, icites)`** -- return the sentence-level evidence behind PubTator3 relations (the sentence that asserts each relation), optionally ranked by iCite citation count.
- **`mesh_keyness(records, measure)`** -- score a corpus's MeSH descriptors against PubMed-wide frequencies (log-odds or Dunning G2) to surface over- and under-represented terms.

### ID conversion

- **`pmid_to_pmc(pmids, ...)`** -- PMID → PMC ID + DOI via the NCBI ID Converter.
- **`pmid_to_ftp(pmids, ...)`** -- PMID → PMC ID + open-access PMC Cloud Service XML URL; pass URLs to `get_records(endpoint = "pmc_fulltext")`.

### MeSH reference data

- **`data_mesh_thesaurus()`** -- MeSH descriptor thesaurus + supplementary concept records; one row per term/synonym.
- **`data_mesh_trees()`** -- MeSH hierarchical tree structure; tree numbers encode the classification path.
- **`data_mesh_frequencies`** -- bundled PubMed-wide descriptor frequencies for enrichment-style baselines.

### Utilities

- **`endpoint_info(endpoint)`** -- column definitions, rate limits, and notes for each endpoint. Returns a list or JSON; useful for tool schemas in LLM applications.

---

## Vignettes

- [Getting started](https://jaytimm.github.io/puremoe/articles/getting-started.html) -- `search_pubmed()` + all `get_records()` endpoints end-to-end
- [MeSH tables](https://jaytimm.github.io/puremoe/articles/mesh-search.html) -- thesaurus lookup, tree navigation, and PubMed-wide descriptor frequencies
- [Citation snowballing](https://jaytimm.github.io/puremoe/articles/citation-snowball.html) -- expand a seed corpus along citation links, audit why each paper was admitted, and quantify the expansion space against PubMed-wide MeSH keyness
- [PubTator sentences](https://jaytimm.github.io/puremoe/articles/pubtator-sentences.html) -- map entity annotations to their sentences and count entity co-occurrence

---

## License

MIT © [Jason Timm](https://github.com/jaytimm)

## Citation

```r
citation("puremoe")
```

## Issues

Report bugs or request features at <https://github.com/jaytimm/puremoe/issues>
