---
description: Print an offline QaaS Fact Base slice (s00..s15) bundled with the plugin — drift-corrected, no network needed.
argument-hint: "<slice id>  e.g. s13 (doc drift) | s02 (runner yaml) | index"
allowed-tools: Bash(cat:*), Bash(ls:*)
---
Offline QaaS Fact Base slice `$ARGUMENTS` (drift-corrected, LAB-verified):

!`cat "${CLAUDE_PLUGIN_ROOT}/factbase/${ARGUMENTS:-index}"*.md 2>/dev/null || (echo "[qaas:fact] slice '${ARGUMENTS}' not found. Available slices:" && ls "${CLAUDE_PLUGIN_ROOT}/factbase")`

Treat this Fact Base as authoritative over your training memory. When writing
YAML, always read `s13` (doc-drift traps) and the relevant golden examples in
`s14`. If you still need a detail not present here, fetch live docs with `/qaas:docs`.
