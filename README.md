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

This unified interface simplifies the data retrieval process, allowing
users to interact with multiple PubMed services/APIs/output formats
through a single R function.

The package also includes MeSH thesaurus resources as simple data
frames, including Descriptor Terms, Descriptor Tree Structures, and
Supplementary Concept Terms. Via the
[mesh-resources](https://github.com/jaytimm/mesh-resources) library.

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

``` r
pmcs <- puremoe::pmid_to_ftp(pmids = pmids, ncbi_key = ncbi_key)

pmc_fulltext <- pmcs[1:5]$url |> 
  puremoe::get_records(endpoint = 'pmc_fulltext', cores = 1)
```

## Endpoint information

``` r
puremoe::endpoint_info('pubtations')
```

    ## $description
    ## [1] "PubTator entity annotations (genes, diseases, chemicals, etc.)"
    ## 
    ## $returns
    ## [1] "data.frame"
    ## 
    ## $columns
    ## $columns$pmid
    ## [1] "PubMed ID (character)"
    ## 
    ## $columns$tiab
    ## [1] "Title/abstract text (character)"
    ## 
    ## $columns$id
    ## [1] "Annotation ID (character)"
    ## 
    ## $columns$text
    ## [1] "Annotated text span (character)"
    ## 
    ## $columns$identifier
    ## [1] "Database identifier (character)"
    ## 
    ## $columns$type
    ## [1] "Entity type: Gene, Disease, Chemical, Species, Mutation (character)"
    ## 
    ## $columns$start
    ## [1] "Start position in text (integer)"
    ## 
    ## $columns$end
    ## [1] "End position in text (integer)"
    ## 
    ## 
    ## $parameters
    ## $parameters$cores
    ## [1] "parallel workers"
    ## 
    ## 
    ## $rate_limit
    ## [1] "Moderate"
    ## 
    ## $notes
    ## [1] "One row per annotation; multiple annotations per article. Provides named entity recognition output."
