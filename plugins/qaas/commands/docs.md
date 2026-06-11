---
description: Fetch a QaaS documentation page from the configured docs mirror over curl (airgap-friendly, no WebFetch).
argument-hint: "<doc-path>  e.g. llms.txt | runner/configuration | qaas/quickStart/writeTestYaml.md"
allowed-tools: Bash(curl:*)
---
Live QaaS documentation for `$ARGUMENTS`, fetched over curl from the configured
mirror (`$QAAS_DOCS_URL`, default `https://docs.qaas.online`):

!`curl -fsSL --max-time 30 "${QAAS_DOCS_URL:-https://docs.qaas.online}/${ARGUMENTS:-llms.txt}" || echo "[qaas:docs] curl failed — check QAAS_DOCS_URL or fall back to the offline Fact Base via /qaas:fact"`

Use ONLY the content above plus the QaaS Fact Base to answer. The QaaS docs index
lives at `llms.txt` (terse) and `llms-full.txt` (complete). If the page is empty
or missing, say so and consult the offline Fact Base with `/qaas:fact`. Never
invent QaaS field names, config keys, or defaults.
