# Suppress R CMD check notes for data.table non-standard evaluation.
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    "..col_order", "..keep_cols", "..role_cols", "..update_cols",
    "baseline_count", "baseline_name", "baseline_prop",
    "citation_count", "citation_support", "corpus_count", "corpus_prop",
    "DescriptorName", "DescriptorUI", "direction", "doc_id", "end",
    "ent1_identifier", "ent1_key", "ent1_mention_index",
    "ent1_sentence_id", "ent1_text", "ent1_tiab", "ent1_type",
    "ent2_identifier", "ent2_key", "ent2_mention_index",
    "ent2_sentence_id", "ent2_text", "ent2_tiab", "ent2_type",
    "g2", "log_odds", "mention_index", "n_pmids", "n_sentences",
    "passage_end", "passage_id", "passage_offset", "passage_start",
    "passage_text", "pmid", "pmids", "prop_total", "relation_id",
    "relation_type", "same_sentence", "sent_end", "sent_key",
    "sent_start", "sentence", "sentence_distance", "sentence_end",
    "sentence_id", "sentence_start", "sentences", "std_error",
    "text", "tiab", "weight", "z"
  ))
}
