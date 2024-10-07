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

# A unified R package for streamlined access to multiple PubMed and NLM databases, simplifying the retrieval of bibliometric, abstract, and full-text data for comprehensive exploration. This package provides key functionalities for:

**PubMed Abstract Retrieval**: Access
[PubMed](https://pubmed.ncbi.nlm.nih.gov/) abstract records with a
single function for seamless research integration.

**Bibliometric Data**: Retrieve [iCite](https://icite.od.nih.gov/)
bibliometric data to explore citation-based metrics and evaluate
scientific impact.

**Named Entity Annotations**: Extract
[PubTator3](https://www.ncbi.nlm.nih.gov/research/pubtator3/) named
entity annotations to support advanced text mining and entity
recognition.

**Full-Text Retrieval**: Access full-text articles from [PubMed
Central](https://www.ncbi.nlm.nih.gov/pmc/) (PMC), allowing in-depth
exploration of scholarly content.

**MeSH Thesaurus Resources**: Leverage MeSH thesaurus data, including
Descriptor Terms, Tree Structures, Supplementary Concepts, and
Pharmacological Actions, presented as easily accessible data frames.
Descriptor-level word embeddings [(Noh & Kavuluru
2021)](https://www.sciencedirect.com/science/article/pii/S1532046421001969)
are also available through the
[mesh-resources](https://github.com/jaytimm/mesh-resources) library for
enhanced semantic analysis.

Ideal for users who need a cohesive, multi-output interface to the wide
array of PubMed services and resources within R.

## Installation

Get the released version from CRAN:

``` r
install.packages('puremoe')
```

Or the development version from GitHub with:

``` r
remotes::install_github("jaytimm/puremoe")
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

> When the endpoint is PMC, the `get_records()` function takes a vector
> of filepaths (from the PMC Open Access list) instead of PMIDs.

``` r
pmclist <- puremoe::data_pmc_list(use_persistent_storage = T)
pmc_pmids <- pmclist[PMID %in% pmids]

pmc_fulltext <- pmc_pmids$fpath[1:5] |> 
  puremoe::get_records(endpoint = 'pmc_fulltext', cores = 1)
```

## Summary
