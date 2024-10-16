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
    Central](https://www.ncbi.nlm.nih.gov/pmc/) (PMC).

This unified interface simplifies the data retrieval process, allowing
users to interact with multiple PubMed services/APIs/output formats
through a single R function.

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

| Output              | Colname             | Description                         |
|:------------------|:------------------|:---------------------------------|
| pubmed_abstracts    | pmid                | PMID                                |
| pubmed_abstracts    | year                | Publication year                    |
| pubmed_abstracts    | journal             | Journal name                        |
| pubmed_abstracts    | articletitle        | Article title                       |
| pubmed_abstracts    | abstract            | Article abstract                    |
| pubmed_abstracts    | annotations         | Mesh/Chem/Keywords annotations      |
| pubmed_affiliations | pmid                | PMID                                |
| pubmed_affiliations | Author              | Author name                         |
| pubmed_affiliations | affiliation         | Author affiliation                  |
| pubtations          | pmid                | PMID                                |
| pubtations          | tiab                | Title or abstract                   |
| pubtations          | id                  | Entity ID                           |
| pubtations          | entity              | Extracted entity                    |
| pubtations          | identifier          | Knowledge base link (KB link)       |
| pubtations          | type                | Entity type                         |
| pubtations          | start               | Start position (char)               |
| pubtations          | end                 | End position (char)                 |
| pmc_fulltext        | pmid                | PMID                                |
| pmc_fulltext        | section             | Full text section                   |
| pmc_fulltext        | text                | Full text content                   |
| icites              | pmid                | PMID                                |
| icites              | is_research_article | Research article indicator          |
| icites              | nih_percentile      | NIH percentile rank                 |
| icites              | is_clinical         | Clinical article indicator          |
| icites              | citation_count      | Citation count                      |
| icites              | ref_count           | Reference count                     |
| icites              | citation_net        | Citation network (to/from edgelist) |
