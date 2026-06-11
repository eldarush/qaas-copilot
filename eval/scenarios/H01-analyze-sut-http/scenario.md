# H01 — analyze-sut-http (analysis)

**Goal:** Read the seeded `sut/InventoryApi/` ASP.NET minimal-API source and produce a structured
`qaas-analysis/sut-profile.md` covering all HTTP surfaces with file:line citations, plus a
`qaas-analysis/QUESTIONS.md` capturing residual reachability unknowns.

- Category: analysis
- Infra: None
- Seed: `sut/InventoryApi/` — Program.cs (3 endpoints + INVENTORY_PORT), Models/ReserveRequest.cs, csproj, README
- Live gates: none (analysis only, no dotnet build/run)
- Traps tested:
  - Forgetting to list POST /inventory/reserve
  - Missing file:line citations in the profile
  - Re-asking questions the source code already answers (endpoint names, default port)
  - Fabricating downstream dependencies (SUT has none — MOCK_REQUIRED: NO)
