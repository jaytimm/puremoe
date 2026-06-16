---
title: 'puremoe: An R toolkit for integrated retrieval and analysis of PubMed and NIH/NLM literature data'
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
date: 2 June 2026
bibliography: references.bib
---

# Summary

`puremoe` is an R package for reproducible biomedical literature retrieval and
analysis across public NIH/NLM data services. It uses PubMed identifiers (PMIDs)
to provide a consistent interface for assembling article records, abstracts,
author affiliations, citation data, biomedical entity and relation annotations,
and open-access full text from their respective native sources. Results are
returned as data frames that can be combined, filtered, and inspected within R,
supporting downstream workflows such as statistical analysis, bibliometrics, and
text mining.

Researchers can then assemble analysis-ready corpora and reshape them locally
for analyses such as citation networks, entity co-occurrence, and sentence-level
relation evidence. The workflow stays entirely within R; it does not require
maintaining a local PubMed mirror, a search index, or a separate client and NLP
pipeline for each upstream service. This makes `puremoe` useful for rapid,
transparent evidence work by researchers who need structured literature data but
do not specialize in large-scale text-mining infrastructure.

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
joined to MeSH tables, or compared against PubMed-wide descriptor frequencies
while retaining PMIDs as the join key.

# State of the field

Several mature R packages support literature and bibliometric workflows, but
they tend to focus on one layer of the broader biomedical data ecosystem.
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
shapes. Existing R clients cover important parts of this ecosystem, but they do
not make PubMed, iCite, PubTator3, PMC full text, and MeSH available through one
PMID-centered workflow. Reconciling those services is the work `puremoe` does.

# Software design

`puremoe` separates remote retrieval from local analysis. Remote retrieval
functions query public NIH/NLM services and return data frames with stable column
structures, or, for PubTator3, a list of data frames for entities and relations.
Local analysis functions then transform those tables without making additional
API calls. This design keeps workflows reproducible: a retrieved corpus can be
saved once, inspected, and reused across downstream analyses.

A single `get_records()` call dispatches to one service endpoint. The same PMIDs
can be reused across endpoints, while `pmid_to_ftp()` resolves open-access PMC
URLs when full text is needed. MeSH resources and the local analysis functions
then build on the retrieved tables (Table 1).

| Stage | Package role | Output |
|-------|--------------|--------|
| Corpus definition | Resolve PubMed queries or accept user-supplied PMIDs | Article identifiers for downstream retrieval |
| Retrieval | Query NIH/NLM services through a common interface | Article records, author affiliations, citation data, annotations, and full text |
| Full-text resolution | Identify open-access PMC records available through the PMC Cloud Service | URLs for machine-readable full text |
| Vocabulary resources | Provide MeSH thesaurus, tree, and frequency data | Descriptor lookup, hierarchy, and PubMed-wide baselines |
| Local analysis | Transform retrieved tables without additional API calls | Keyness scores, citation expansions and networks, co-occurrence counts, entity networks, and relation evidence |

: `puremoe` workflow stages and outputs.

A typical workflow resolves a query to PMIDs, pulls records across one or more
services, and analyzes those tables locally:

```r
library(puremoe)

# 1. Resolve a query to PMIDs
pmids <- search_pubmed('"doxorubicin"[TiAb] AND "cardiotoxicity"[TiAb]')

# 2. Retrieve records for the same PMIDs (one endpoint per call)
records <- get_records(pmids, endpoint = "pubmed_abstracts")
icites  <- get_records(pmids, endpoint = "icites")
pt      <- get_records(pmids, endpoint = "pubtator")  # entities + relations

# 3. Local analysis reuses the retrieved tables -- no new API calls
mesh_keyness(records)                                  # MeSH terms over-represented vs. PubMed
network <- citation_network(icites)                    # within-corpus citation network

ctx <- pubtator_context(pt)                            # anchor mentions to sentences
pubtator_cooccurrence(ctx, window = 0, by = "type")    # entity-type co-occurrence
entity_net <- pubtator_network(ctx, edges = "relations", by = "entity")
relation_evidence(ctx, relation_type = "positive_correlation",
                  icites = icites)                     # ranked drug-disease evidence summary
```

In this example, the final block yields a compact summary:
`mesh_keyness()` identifies the MeSH terms that distinguish the corpus from
PubMed as a whole; the co-occurrence table surfaces the entity types most often
discussed together; `pubtator_network()` converts relations into graph-ready
tables; and `relation_evidence()` summarizes selected relations, ranked by
citation support and traceable through the sentences and papers behind each one.

Retrieval is batched and optionally parallelized, with endpoint-specific batch
sizes and rate-limit pauses handled inside the package rather than repeated in
each analysis script.

# Research impact statement

`puremoe` has been available on CRAN since 2024. It includes reproducible
vignettes for core tasks: PubMed retrieval; MeSH-guided search; citation
snowballing; and sentence-level PubTator3 annotation analysis. These examples
demonstrate complete biomedical literature workflows rather than isolated API
calls, and provide reusable templates for researchers constructing evidence
corpora from public NIH/NLM data.

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
