## Build data_mesh_frequencies dataset
## Run from package root: source("data-raw/data_mesh_frequencies.R")

library(data.table)
library(puremoe)

# Read raw frequency CSV
freq <- data.table::fread("data-raw/mesh_term_frequency_202604161031.csv")

# Get thesaurus: DescriptorUI + DescriptorName per unique lowercased TermName
thesaurus <- suppressMessages(puremoe::data_mesh_thesaurus())

# Build a unique term -> descriptor_ui lookup (prefer RecordPreferredTermYN == "Y")
lookup <- thesaurus[, .(term_lower = tolower(TermName),
                        descriptor_ui = DescriptorUI,
                        descriptor_name = DescriptorName,
                        record_preferred = RecordPreferredTermYN)]

# Sort so preferred terms come first, then deduplicate on term_lower
data.table::setorder(lookup, term_lower, -record_preferred)
lookup <- unique(lookup, by = "term_lower")
lookup[, record_preferred := NULL]

# Join
data_mesh_frequencies <- lookup[freq, on = c(term_lower = "mesh_term_lower"),
                                nomatch = NULL]
data_mesh_frequencies[, term_lower := NULL]
data.table::setnames(
  data_mesh_frequencies,
  c("descriptor_ui", "descriptor_name"),
  c("DescriptorUI", "DescriptorName")
)
data.table::setcolorder(
  data_mesh_frequencies,
  c("DescriptorUI", "DescriptorName", "n_pmids", "prop_total")
)
data.table::setorder(data_mesh_frequencies, -n_pmids)

cat("Rows:", nrow(data_mesh_frequencies), "\n")

usethis::use_data(data_mesh_frequencies, overwrite = TRUE, compress = "xz")
