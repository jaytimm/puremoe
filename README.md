[![](https://www.r-pkg.org/badges/version/puremoe)](https://cran.r-project.org/package=puremoe)
[![](http://cranlogs.r-pkg.org/badges/last-month/puremoe)](https://cran.r-project.org/package=puremoe)

# puremoe

**P**ubMed **U**nified **RE**trieval for **M**ulti-**O**utput
**E**xploration. An R package that provides a single interface for
accessing a range of **NLM/PubMed databases**, including:

-   [PubMed](https://pubmed.ncbi.nlm.nih.gov/) abstract records,

-   [iCite](https://icite.od.nih.gov/) bibliometric data,

-   [PubTator3](https://www.ncbi.nlm.nih.gov/research/pubtator3/) named
    entity annotations, and

-   full-text entries from [PubMed
    Central](https://pmc.ncbi.nlm.nih.gov/) (PMC).

This **unified interface** simplifies the data retrieval process,
allowing users to interact with multiple PubMed services/APIs/output
formats through a single R function.

Also included are **MeSH thesaurus resources** as simple data frames:
Descriptor Terms, Descriptor Tree Structures, and Supplementary Concept
Terms, via the
[mesh-resources](https://github.com/jaytimm/mesh-resources) library.

The package provides a straightforward retrieval interface for PubMed
literature, with **utility in LLM applications and RAG workflows**
requiring access to abstracts, full-text articles, entity annotations,
and bibliometric data.

## Installation

Get the released version from CRAN:

``` r
install.packages('puremoe')
```

Or the development version from GitHub with:

``` r
remotes::install_github("jaytimm/puremoe")
```

## PubMed search

The package has two basic functions: `search_pubmed` and `get_records`.
The former fetches PMIDs from the PubMed API based on user search; the
latter scrapes PMID records from a user-specified PubMed endpoint –
`pubmed_abstracts`, `pubmed_affiliations`, `pubtations`, `icites`, or
`pmc_fulltext`.

Search syntax is the same as that implemented in standard [PubMed
search](https://pubmed.ncbi.nlm.nih.gov/advanced/).

``` r
pmids <- puremoe::search_pubmed('("political ideology"[TiAb])') 
```

## Get record-level data

``` r
pubmed <- pmids |> 
  puremoe::get_records(endpoint = 'pubmed_abstracts', 
                       cores = 3, 
                       sleep = 1,
                       ncbi_key = ncbi_key) 

affiliations <- pmids |> 
  puremoe::get_records(endpoint = 'pubmed_affiliations', 
                       cores = 1, 
                       sleep = 0.5)

icites <- pmids |>
  puremoe::get_records(endpoint = 'icites',
                       cores = 3,
                       sleep = 0.25)

pubtations <- pmids |> 
  puremoe::get_records(endpoint = 'pubtations',
                       cores = 2)
```

## PMC full text

Full-text articles can be retrieved for PMIDs if available in PMC’s
open-access collection. Use **`pmid_to_ftp()`** to get download URLs,
then pass these to `get_records(endpoint = 'pmc_fulltext')` Useful for
quick retrieval in **LLM/chat contexts**.

For bulk downloads, use `data_pmc_list()`.

``` r
pmcs <- puremoe::pmid_to_ftp(pmids = pmids, ncbi_key = ncbi_key)
pmc_fulltext <- puremoe::get_records(pmcs[1:5]$url, endpoint = 'pmc_fulltext', cores = 1)
```

## Endpoint information

Returns schema, columns, and rate limits for each endpoint. Useful in
**LLM app contexts for tool schemas**.

`endpoint_info()` lists endpoints; `endpoint_info('endpoint_name')`
returns details; `format = 'json'` for machine-readable output.

``` r
puremoe::endpoint_info()
```

    ## [1] "pubmed_abstracts"    "pubmed_affiliations" "icites"             
    ## [4] "pubtations"          "pmc_fulltext"

``` r
puremoe::endpoint_info('pmc_fulltext')
```

    ## $description
    ## [1] "Full-text articles from PubMed Central"
    ## 
    ## $returns
    ## [1] "data.frame"
    ## 
    ## $columns
    ## $columns$pmid
    ## [1] "PubMed ID (character)"
    ## 
    ## $columns$section
    ## [1] "Section heading (character)"
    ## 
    ## $columns$text
    ## [1] "Section text content (character)"
    ## 
    ## 
    ## $parameters
    ## $parameters$cores
    ## [1] "parallel workers"
    ## 
    ## 
    ## $input
    ## [1] "Requires FTP URLs from pmid_to_ftp()"
    ## 
    ## $rate_limit
    ## [1] "NCBI FTP: be respectful"
    ## 
    ## $notes
    ## [1] "One row per section; use after pmid_to_ftp() to get URLs. Not all PMIDs have PMC full text available."

## License

MIT © \[Jason Timm, MA, PhD\]

## Citation

If you use this package in your research, please cite:

``` r
citation("puremoe")
```

## Issues

Report bugs or request features at
<https://github.com/username/puremoe/issues>

## Contributing

Contributions welcome! Please open an issue or submit a pull request.
