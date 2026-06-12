# H04 — test-inventory-gaps (analysis)

**Goal:** Inventory the existing `existing-tests/inventory.qaas.yaml` against the premade
`qaas-analysis/sut-profile.md` and produce a gap-analysis: `qaas-analysis/test-inventory.md`
(per-test behavioral inventory) and `qaas-analysis/coverage-gaps.md` (surface coverage table).
No new YAML files may be produced.

- Category: analysis
- Infra: None
- Seed: `existing-tests/inventory.qaas.yaml` (covers only GET /inventory/items), `qaas-analysis/sut-profile.md` (all 3 surfaces)
- Live gates: none (analysis only); verify checks no new .qaas.yaml created
- Traps tested:
  - Not noting HermeticByExpectedOutputCount in the existing test inventory
  - Missing gap entries for GET /inventory/items/{id} and POST /inventory/reserve
  - Generating new YAML instead of analysis-only output
  - Marking covered surfaces as gaps or vice versa
