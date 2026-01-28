# puremoe 1.0.3 (2026-01-17)

## Bug Fixes
- Fixed iCite API integration to handle changes in API response structure.
- Removed modern pipe operators to maintain compatibility with R >= 3.5.
- Improved error handling for Internet resource functions to comply with CRAN policy.

## New Features
- Added `pmid_to_pmc()` function to convert PubMed IDs (PMIDs) to PubMed Central (PMC) IDs and DOIs using the NCBI ID Converter API.
- Added `pmid_to_ftp()` function to convert PMIDs to PMC IDs and full-text URLs, enabling access to open access PMC articles without downloading the PMC file list.
- Added `endpoint_info()` function to provide detailed information about available endpoints.

## Removed Features
- Removed mesh descriptor embeddings functionality (`data_mesh_embeddings()` function).


---

# puremoe 1.0.2 (2024-10-14)

## Bug Fixes
- Fixed an issue with the internal function responsible for handling Pubtator3 data. This was due to changes in the data structures provided by Pubtator3 API. The function now correctly processes data retrieved via the updated `biocjson` format from the API endpoint.


---

# puremoe 1.0.1 (2024-05-12)

## Bug Fixes
- Fixed a typo that caused the full text retrieval to fail in the `pmc_fulltext` endpoint.
- Improved the `data_pmc_list` function to handle timeouts more effectively when downloading the PMC Open Access file list.
