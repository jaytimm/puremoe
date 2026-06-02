# puremoe 1.1.0 (tentative)

*in development*

## New Features
- Added `pubtator_sentences()` for mapping PubTator3 entity annotations to the
  sentence in which they occur. The function uses PubTator's own passage text
  and offsets for alignment, preserves empty PubTator title/abstract placeholder
  rows for transparency, and returns a clean annotation table with
  `sentence_id` and `sentence` columns.
- Added `pubtator_cooccurrence()` for entity co-occurrence counts from the
  sentence-mapped table returned by `pubtator_sentences()`. Counts unordered
  entity pairs within the same sentence (`window = 0`) or within `window`
  sentences of each other, aggregated `by` entity type or by specific entity.
  De-duplicates entities per sentence and drops same-entity pairs. With
  `evidence = TRUE`, returns one row per co-occurrence instance with the joined
  sentence `context`, so every count is traceable to concrete text.
- Added `citation_snowball()` for citation-based corpus expansion. Takes an `icites`
  data.table and follows one-hop citation links using the NIH Open Citation
  Collection data already embedded in every iCite response. Supports
  `max_nodes` (hard ceiling on corpus size), `direction`, and `min_links`.
  Returns a candidate table with seed flags and citation-link counts, and does
  not make a second iCite call; pass `snowball$pmid` explicitly to
  `get_records()` when metadata for the expanded corpus is needed.
- Added `citation_network()` for citation network analysis. Takes an
  `icites` data.table from `get_records()` and returns a
  named list with `nodes` (full iCite metadata as node attributes, including
  `relative_citation_ratio` and `is_clinical`) and `edges`
  (`from_pmid`, `to_pmid`), filtered to within-corpus pairs only. Output is
  ready for `igraph` or `tidygraph`.

## Changes
- `get_records(endpoint = "pubtations")` now includes PubTator passage text and
  passage offsets in its raw output, allowing downstream sentence mapping to use
  the same text that PubTator annotated.

---

# puremoe 1.0.4

*2026-04-21*

## New Features
- Added `data_mesh_frequencies`, a bundled dataset of MeSH descriptor frequencies
  across the full PubMed corpus (39.7 M PMIDs, April 2026). Columns `DescriptorUI`,
  `DescriptorName`, `n_pmids`, and `prop_total`. Intended as a baseline for
  MeSH term enrichment analyses.

## Changes
- `pmid_to_ftp()` updated to use the PMC Cloud Service on AWS S3
  (`pmc-oa-opendata.s3.amazonaws.com`) in response to NCBI's migration away from
  the legacy PMC FTP Service (transition period February–August 2026; FTP
  decommissioned August 2026). The function interface is unchanged.

---

# puremoe 1.0.3

*2026-01-26*

## Bug Fixes
- Fixed iCite API integration to handle changes in API response structure.
- Removed modern pipe operators to maintain compatibility with R >= 3.5.
- Improved error handling for Internet resource functions to comply with CRAN policy.

## New Features
- Added `pmid_to_ftp()` to convert PMIDs to full-text download URLs for open-access PMC articles; pass `$url` to `get_records(endpoint = 'pmc_fulltext')`.
- Added `endpoint_info()` to provide schema, columns, and rate limits for each endpoint.

## Removed Features
- Removed mesh descriptor embeddings functionality (`data_mesh_embeddings()` function).


---

# puremoe 1.0.2

*2024-10-15*

## Bug Fixes
- Fixed an issue with the internal function responsible for handling Pubtator3 data. This was due to changes in the data structures provided by Pubtator3 API. The function now correctly processes data retrieved via the updated `biocjson` format from the API endpoint.


---

# puremoe 1.0.1

*2024-05-13*

## Bug Fixes
- Fixed a typo that caused the full text retrieval to fail in the `pmc_fulltext` endpoint.
