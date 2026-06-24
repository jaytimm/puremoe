---
title: 'puremoe: An R package for integrated retrieval and analysis of PubMed and NIH/NLM literature data'
tags:
  - R
  - PubMed
  - biomedical informatics
  - bibliometrics
  - literature mining
  - MeSH
authors:
  - name: Jason Timm
    orcid: 0009-0007-9681-5157
    affiliation: 1
affiliations:
  - name: University of New Mexico, Albuquerque, NM, USA
    index: 1
    ror: 05fs6jp91
date: 23 June 2026
bibliography: references.bib
---

# Summary

`puremoe` is an R package for reproducible biomedical literature retrieval and
analysis across public NIH/NLM data services. It provides a single interface
to the NIH/NLM data stack, assembling article records, abstracts, author
affiliations, citation data, biomedical entity and relation annotations, and
open-access full text from their respective native sources. Retrieved tables
feed directly into a local analysis layer included in the package. The workflow
stays entirely within R; it does not require maintaining a local PubMed mirror,
a search index, or a separate client and NLP pipeline for each upstream service.
This makes `puremoe` useful for rapid, transparent evidence work by researchers
who need structured literature data but do not specialize in large-scale
text-mining infrastructure.

# Statement of need

Biomedical literature workflows routinely draw on several related but separate
data products. NCBI E-utilities support article discovery and metadata
retrieval [@sayers2022eutilities]; NIH iCite supplies citation counts and
article-to-article citation links [@hutchins2016rcr]; PubTator3
provides biomedical concept annotations and relations [@wei2024pubtator3]; PubMed
Central distributes machine-readable open-access full text through services
including the PMC Cloud Service [@pmccloud; @pmcoa]; and MeSH offers a
controlled, hierarchical vocabulary for indexing and searching the literature
[@mesh].

In R, these resources are typically reached through different packages, APIs,
or manual downloads, with no single interface spanning the NIH/NLM products that
biomedical workflows commonly need together. The resulting fragmentation adds
avoidable friction whenever an analysis must move from a search result to iCite
metrics, entity annotations, vocabulary structure, and full text.

`puremoe` closes this gap by keeping those steps in one R workflow. The same
article set can be queried across multiple services, expanded along iCite links,
joined to MeSH tables, or scored with MeSH keyness against PubMed-wide descriptor
frequencies while retaining PMIDs as the join key.

# State of the field

Several mature R packages support literature and bibliometric workflows, but
they tend to focus on one layer of the NIH/NLM data stack.
`rentrez` [@winter2017rentrez] and `easyPubMed` [@fantini2022easypubmed] provide
well-established access to PubMed and related NCBI E-utilities records.
`openalexR` [@arlia2023openalexr] supports analysis of the OpenAlex scholarly
graph, which is broader than PubMed and useful for general bibliometrics. The
rOpenSci `europepmc` client [@jahn2024europepmc] is closest in spirit, binding
search, full text, citations, and text-mined annotations through one interface
over the Europe PMC corpus. These tools are valuable, and `puremoe` does not
replace them. Its contribution is not a broader corpus, but tighter integration
with native NIH/NLM services and a local analysis layer. It binds the live
PubTator3 pipeline with its current entities and relations, iCite citation data
and links, and MeSH as inspectable thesaurus, tree, and frequency tables. It also
adds analyses that the upstream services do not provide, including keyness
testing, citation expansion, and sentence-level entity and relation analysis.

The integration is the contribution. A workflow spanning PubMed, iCite,
PubTator3, PMC full text, and MeSH requires consistent batching, rate-limit
handling, and output normalization across services with different APIs and data
shapes. Existing R clients cover important parts of this stack, but none makes all of
them available through a single PMID-centered workflow. Reconciling those
services is the work `puremoe` does.

# Software design

`puremoe` separates remote retrieval from local analysis. Remote retrieval
functions query public NIH/NLM services and return data frames with stable column
structures, or, for PubTator3, a list of data frames for entities and relations.
Local analysis functions then transform those tables without making additional
API calls. This design keeps workflows reproducible: a retrieved corpus can be
saved once, inspected, and reused across downstream analyses.

`get_records()` dispatches to one service endpoint by name; `pmid_to_ftp()`
resolves open-access PMC URLs when full text is needed. MeSH resources and
the local analysis functions then build on the retrieved tables (Table 1).

| Stage | Package role | Output |
|-------|--------------|--------|
| Corpus definition | Resolve PubMed queries or accept user-supplied PMIDs | Article identifiers for downstream retrieval |
| Retrieval | Query NIH/NLM services through a common interface | Article records, author affiliations, citation data, annotations, and full text |
| Full-text resolution | Identify open-access PMC records available through the PMC Cloud Service | URLs for machine-readable full text |
| Vocabulary resources | Provide MeSH thesaurus, tree, and frequency data | Descriptor lookup, hierarchy, and PubMed-wide baselines |
| Local analysis | Transform retrieved tables without additional API calls | Keyness scores, citation expansions and networks, entity co-occurrence counts, relation networks, and edge-level evidence |

: `puremoe` workflow stages and outputs.





A typical workflow resolves a query to PMIDs, pulls records across one or more
services, and analyzes those tables locally:

```r
library(puremoe)

# 1. Resolve a query to PMIDs
pmids <- search_pubmed('"doxorubicin"[TiAb] AND "cardiotoxicity"[TiAb]')

# 2. Retrieve records for the same PMIDs (one endpoint per call)
article_metadata   <- get_records(pmids, endpoint = "pubmed_abstracts")
citation_metrics   <- get_records(pmids, endpoint = "icites")
entity_annotations <- get_records(pmids, endpoint = "pubtator")

# 3. Local analysis -- no new API calls
descriptor_keyness  <- mesh_keyness(article_metadata)
article_network     <- citation_network(citation_metrics)
sentence_context    <- pubtator_context(entity_annotations)
entity_cooccurrence <- pubtator_cooccurrence(sentence_context, window = 0)
relation_network    <- pubtator_network(sentence_context)
```

Retrieval is batched and optionally parallelized, with endpoint-specific batch
sizes and rate-limit pauses handled inside the package rather than repeated in
each analysis script.

# Research impact statement

`puremoe` has been available on CRAN since 2024. It is suited to evidence
work across a range of tasks — systematic and scoping reviews, drug-disease
literature mapping, grant preparation — where rapid corpus assembly is the
bottleneck. Vignettes covering each workflow stage are included.

# AI usage disclosure

Anthropic's Claude, through the Claude Code interface, was used during
development of `puremoe` to assist with routine coding work: refactoring
existing functions, drafting roxygen documentation, and writing unit tests.
The author directed this work, inspected every suggested change, and edited or
discarded output as needed. The author is responsible for the correctness of the
code and its documentation.

# Acknowledgements

This package builds on public data services maintained by NCBI, NLM, NIH, and
PMC, including PubMed E-utilities, iCite, PubTator3, MeSH, and the PMC
Open Access / Cloud Service.

# References
