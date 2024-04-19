[![](https://www.r-pkg.org/badges/version/puremoe)](https://cran.r-project.org/package=puremoe)
[![](http://cranlogs.r-pkg.org/badges/last-month/puremoe)](https://cran.r-project.org/package=puremoe)

# puremoe

> **P**ubMed **U**nified **RE**trieval for **M**ulti-**O**utput
> **E**xploration

An R package that provides a single interface for accessing a range of
NLM/PubMed databases, including
[PubMed](https://pubmed.ncbi.nlm.nih.gov/) abstract records,
[iCite](https://icite.od.nih.gov/) bibliometric data,
[PubTator3](https://www.ncbi.nlm.nih.gov/research/pubtator3/) named
entity annotations, and full-text entries from [PubMed
Central](https://www.ncbi.nlm.nih.gov/pmc/) (PMC). This unified
interface simplifies the data retrieval process, allowing users to
interact with multiple PubMed services/APIs/output formats through a
single R function.

The package also includes MeSH thesaurus resources as simple data
frames, including Descriptor Terms, Descriptor Tree Structures,
Supplementary Concept Terms, and Pharmacological Actions; it also
includes descriptor-level word embeddings [(Noh & Kavuluru
2021)](https://www.sciencedirect.com/science/article/pii/S1532046421001969).
Via the [mesh-resources](https://github.com/jaytimm/mesh-resources)
library.

## Installation

Get the released version from CRAN:

``` r
install.packages('puremoe')
```

    ## Installing package into '/home/jtimm/R/x86_64-pc-linux-gnu-library/4.3'
    ## (as 'lib' is unspecified)

Or the development version from GitHub with:

``` r
devtools::install_github("jaytimm/puremoe")
```

## Usage

## PubMed search

The package has two basic functions: `search_pubmed` and `get_records`.
The former fetches PMIDs from the PubMed API based on user search; the
latter scrapes PMID records from a user-specified PubMed endpoint –
`pubmed_abstracts`, `pubmed_affiliations`, `pubtations`, `icites`, or
`pmc_fulltext`.

Search syntax is the same as that implemented in standard [PubMed
search](https://pubmed.ncbi.nlm.nih.gov/advanced/).

``` r
pmids <- puremoe::search_pubmed('("political ideology"[TiAb])',
                                 use_pub_years = F)

# pmids <- puremoe::search_pubmed('immunity', 
#                                  use_pub_years = T,
#                                  start_year = 2022,
#                                  end_year = 2024) 
```

## Get record-level data

``` r
pubmed <- pmids |> 
  puremoe::get_records(endpoint = 'pubmed_abstracts', 
                       cores = 3, 
                       sleep = 1) 

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

> When the endpoint is PMC, the \`get_records() function takes a vector
> of filepaths (from the PMC Open Access list) instead of PMIDs.

``` r
pmclist <- puremoe::data_pmc_list(force_install = F)
pmc_pmids <- pmclist[PMID %in% pmids]

pmc_fulltext <- pmc_pmids$fpath[1:5] |> 
  puremoe::get_records(endpoint = 'pmc_fulltext', cores = 2)
```

## Summary
