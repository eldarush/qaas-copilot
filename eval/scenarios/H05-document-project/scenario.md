# H05 — document-project (analysis)

**Goal:** Read the complete seeded A01-style payment QaaS project (Runner + Mocker) and write a
`README.md` at the artifacts root with topology diagram, test table, exact run commands, artifact
paths, and troubleshooting rows citing FB s13 traps.

- Category: analysis
- Infra: None (documentation references port 8090; no live run required)
- Seed: complete Runner/ + Mocker/ with payment.qaas.yaml and payment.mocker.yaml
- Live gates: none (documentation only)
- Traps tested:
  - Omitting the HermeticByExpectedOutputCount hermetic-guard rationale
  - Omitting mocker-first run ordering
  - Missing ExitCode=0 as the expected green evidence
  - Not citing FB s13 traps in the Troubleshooting section (route leading slash, ProcessorConfiguration, vacuous HttpStatus)
  - Mermaid diagram absent or malformed
