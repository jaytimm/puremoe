# data.table is generally careful to minimize the scope for namespace
# conflicts (i.e., functions with the same name as in other packages);
# a more conservative approach using @importFrom should be careful to
# import any needed data.table special symbols as well, e.g., if you
# run DT[ , .N, by='grp'] in your package, you'll need to add
# @importFrom data.table .N to prevent the NOTE from R CMD check.
# See ?data.table::`special-symbols` for the list of such symbols
# data.table defines; see the 'Importing data.table' vignette for more
# advice (vignette('datatable-importing', 'data.table')).
#
#' @import data.table
NULL

# Declare global variables for data.table column references to avoid R CMD check NOTES
utils::globalVariables(c(
  ".", ".SD", ".N",  # data.table special symbols
  "pmid", "X_id", "ref_count", "references", "cited_by",
  "citation_net", "doc_id", "from", "to",
  "locations", "start", "end", "tiab",
  "file_path", "pmcid", "i.url", "url"  # data.table column references
))
