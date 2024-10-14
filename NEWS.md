# puremoe 1.0.2 (2024-10-14)

## Bug Fixes
- Fixed an issue with the internal function responsible for handling Pubtator3 data. This was due to changes in the data structures provided by Pubtator3 API. The function now correctly processes data retrieved via the updated `biocjson` format from the API endpoint.


---

# puremoe 1.0.1 (2024-05-12)

## Bug Fixes
- Fixed a typo that caused the full text retrieval to fail in the `pmc_fulltext` endpoint.
- Improved the `data_pmc_list` function to handle timeouts more effectively when downloading the PMC Open Access file list.
