# H03 — analyze-helm-config (analysis)

**Goal:** Read the seeded Helm chart (no helm binary available) and produce
`qaas-analysis/runtime-config.md` with effective config for default and prod overlays, and
`qaas-analysis/QUESTIONS.md` for remaining unknowns (secrets, target overlay).

- Category: analysis
- Infra: None
- Seed: `chart/order-enricher/` — Chart.yaml, values.yaml, values-prod.yaml, templates/deployment.yaml, templates/configmap.yaml
- Live gates: none (analysis only)
- Traps tested:
  - Inventing the RABBIT_PASSWORD secret value — must write placeholder SECRET:rabbit-creds/password
  - Missing PREFETCH_COUNT from configmap.yaml (not in values.yaml)
  - Missing prod overlay ENRICHER_MODE "turbo" override
  - Not noting that helm binary may be absent (fallback to manual template reading)
  - Not asking which overlay to target for tests
