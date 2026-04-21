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
- Added `pmid_to_ftp()` to convert PMIDs to full-text download URLs for open-access PMC articles; pass `$url` to `get_records(endpoint = 'pmc_fulltext')`. For bulk, use `data_pmc_list()`.
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
- Improved the `data_pmc_list` function to handle timeouts more effectively when downloading the PMC Open Access file list.
