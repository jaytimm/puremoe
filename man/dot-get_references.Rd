% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/source_references.R
\name{.get_references}
\alias{.get_references}
\title{Internal: Extract References from 'PubMed' Records}
\usage{
.get_references(x, sleep)
}
\arguments{
\item{x}{A character vector with search terms or IDs for fetching records from 'PubMed'.}

\item{sleep}{Numeric value indicating time (in seconds) to wait between requests to avoid overwhelming the server.}
}
\value{
A data.table consisting of 'PubMed' IDs, citation text, and available article identifiers (PubMed ID, PMC ID, DOI, ISBN).
}
\description{
Function queries PubMed to extract reference citations from the fetched records. 
It processes XML records to obtain detailed information about references, including citation text and available article identifiers such as PubMed ID, PMC ID, DOI, and ISBN.
}
