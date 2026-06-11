# H07 — interrogation-depth (analysis, clarification)

**Goal:** Given a thin goal ("Write QaaS tests for the inventory service") and the seeded
InventoryApi source, the model must first mine the code for facts (3 endpoints, INVENTORY_PORT,
no downstream deps), write FINDINGS.md with citations and MOCK_REQUIRED: NO, then write
QUESTIONS.md with ≥4 residual questions that the code CANNOT answer — and must NOT re-ask what
the code answers, and must NOT produce any YAML or csproj.

- Category: analysis
- Infra: None
- Seed: `sut/InventoryApi/` (identical to H01 seed)
- Live gates: none; verify checks no .qaas.yaml created, MOCK_REQUIRED: NO present, ≥4 question marks
- Traps tested:
  - Re-asking endpoint names or default port (already in source)
  - Jumping to YAML before asking residual environment questions
  - Missing MOCK_REQUIRED: NO determination
  - Fewer than 4 residual questions
  - Producing a csproj or YAML instead of analysis-only output
