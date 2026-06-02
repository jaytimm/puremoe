---
title: 'puremoe: Unified retrieval and analysis of PubMed and NIH literature data in R'
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
date: 2 June 2026  # TODO: update at submission
bibliography: references.bib
---

# Summary

`puremoe` is an R package for reproducible biomedical literature retrieval and
analysis. It connects a PubMed search to the wider NLM/NIH data stack through
one consistent interface: a single set of PMIDs can be enriched with article
metadata and abstracts, author affiliations, citation metrics, biomedical
entity annotations, open-access full text, and within-corpus citation
structure. Every endpoint returns a `data.table`, so results from different
services share one tabular shape and compose directly with the rest of the R
ecosystem.

The package is built around a small set of pipe-friendly functions. Users
search PubMed with `search_pubmed()`, then pass the returned PMIDs to
`get_records()`, which dispatches to one of five endpoints —
`pubmed_abstracts`, `pubmed_affiliations`, `icites`, `pubtations`, or
`pmc_fulltext` — selected by a single argument. The two PubMed endpoints draw
on the same E-utilities records but expose different slices (article metadata
versus author–affiliation rows), letting users request only what a given
analysis needs. Utility helpers resolve PMIDs to open-access PMC full-text URLs
and expose MeSH thesaurus and tree tables, while a set of analysis functions
operates on the retrieved tables: expanding a corpus along citation links,
building within-corpus citation networks, mapping entity annotations to their
source sentences, and counting sentence-level entity co-occurrence.

# Statement of need

Biomedical literature workflows routinely draw on several related but separate
data products. NCBI E-utilities support article discovery and metadata
retrieval [@sayers2022eutilities]; NIH iCite supplies field-normalized citation
metrics such as the Relative Citation Ratio [@hutchins2016rcr]; PubTator
Central provides biomedical concept annotations [@wei2019pubtator]; PubMed
Central distributes machine-readable open-access full text through services
including the PMC Cloud Service [@pmccloud; @pmcoa]; and MeSH offers a
controlled, hierarchical vocabulary for indexing and searching the literature
[@mesh].

In R, these resources are typically reached through different packages, APIs,
or manual downloads. Established tools cover parts of the space well —
`rentrez` [@winter2017rentrez] and `easyPubMed` [@fantini2022easypubmed] for
E-utilities workflows, and `openalexR` [@arlia2023openalexr] for the broader
OpenAlex scholarly graph — but none offers a single PMID-centered interface
spanning PubMed, iCite, PubTator3, PMC, and MeSH. The resulting fragmentation
adds avoidable friction whenever a workflow must connect a search result to
citation metrics, entity annotations, vocabulary structure, and full text.

`puremoe` closes this gap by making the PMID the unit of exchange across all of
these products. A PubMed search result feeds directly into every retrieval
endpoint and can also be expanded along iCite citation links, joined to MeSH
tables, or reshaped into a citation network — all without ID conversions or a
change in calling convention. The citation-expansion, network-construction,
sentence-mapping, and co-occurrence functions are original to `puremoe`: the
underlying services expose data, not these analyses. Because it requires no
local PubMed mirror, custom index, or per-service client, the package is well
suited to rapid
proof-of-concept work: researchers can quickly test corpus definitions, MeSH
strategies, citation expansions, and annotation-based analyses from within R.
This lowers the barrier for users who need structured evidence retrieval but do
not specialize in large-scale NLP infrastructure.

# Functionality

The primary interface is `get_records()`, which keeps one calling convention
across endpoints while returning outputs appropriate to each:

```r
pmids |> puremoe::get_records(endpoint = "icites")
```

Retrieval is batched and optionally parallelized, with rate-limit pauses and
graceful degradation: a failed or slow iCite batch returns PMID-only rows
annotated with a note rather than aborting the call. Surrounding helpers handle
steps before and after retrieval. `search_pubmed()` turns a PubMed query into
PMIDs; `pmid_to_pmc()` and `pmid_to_ftp()` resolve PMIDs to PMC identifiers and
open-access full-text URLs; and MeSH thesaurus, tree, and PubMed-wide frequency
tables support vocabulary-guided search and enrichment baselines.

`pubtator_sentences()` aligns each PubTator3 entity annotation to the title or
abstract sentence in which it occurs, using PubTator's own passage text and
character offsets, and returns a `sentence_id`/`sentence` annotation table for
sentence-level evidence review and downstream NLP. `pubtator_cooccurrence()`
counts entity pairs that co-occur within or across sentences and can return the
supporting sentence context, so each count is traceable to concrete text.

Two citation helpers extend the design to corpus expansion and network
analysis, reusing the NIH Open Citation Collection links already embedded in
every iCite response — so neither makes a second API call. `citation_snowball()`
follows those links one hop out and returns an auditable candidate table:

```text
pmid   seed   cited_links   citing_links   link_count
```

The `seed` flag separates the original corpus from discovered papers; the link
counts record how many seed papers connect to each candidate; and `min_links`
and `max_nodes` bound the expansion. `citation_network()` converts an
iCite corpus into `nodes` and `edges` tables — keeping within-corpus edges only
and carrying the Relative Citation Ratio, NIH percentile, and clinical flags as
node attributes — ready for `igraph` or `tidygraph`.

# Use cases

`puremoe` supports several common biomedical literature workflows:

- Programmatic literature-review pipelines that begin with a PubMed query and
  retrieve abstracts, metadata, affiliations, citation metrics, and
  sentence-level entity annotations.
- MeSH-guided search construction using thesaurus and tree tables, with
  retrieved-corpus MeSH terms compared against PubMed-wide descriptor
  frequencies.
- Citation-based corpus expansion via iCite links, with audit columns that
  document why each candidate PMID was admitted.
- Translational analyses that combine iCite metrics, clinical flags, and
  directed citation edges to examine links between a seed corpus and clinically
  oriented literature.
- LLM-assisted literature synthesis, where `puremoe` functions serve as
  tool-call backends for agents that iteratively search, expand, and retrieve.
  The structured outputs — audited candidate tables, node/edge networks, and
  entity annotations — are designed to be consumed programmatically.

# Related software

`puremoe` complements existing R packages rather than replacing them. `rentrez`
[@winter2017rentrez] and `easyPubMed` [@fantini2022easypubmed] provide access
to PubMed and related NCBI resources, and `openalexR` [@arlia2023openalexr]
supports analysis of the OpenAlex scholarly graph. `puremoe` is narrower by
design, focusing on PMID-centered workflows where PubMed, iCite, PubTator3,
PMC, and MeSH are first-class inputs.

# Acknowledgements

This package builds on public data services maintained by NCBI, NLM, NIH, and
PMC, including PubMed E-utilities, iCite, PubTator Central, MeSH, and the PMC
Open Access / Cloud Service.

# References
