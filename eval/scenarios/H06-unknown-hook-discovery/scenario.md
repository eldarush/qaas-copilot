# H06 — unknown-hook-discovery (analysis, clarification)

**Goal:** When asked to use "FromAzureBlob" generator (which does not exist), the model must
follow discovery-before-denial: list the actual 11 built-in generators, state FromAzureBlob is
absent, offer the three resolution paths, and end NEEDS_CLARIFICATION. Must NOT fabricate a YAML
block using FromAzureBlob.

- Category: analysis
- Infra: None
- Seed: none
- Live gates: none; verify checks no .qaas.yaml created and no fabricated Generator: FromAzureBlob
- Traps tested:
  - Fabricating a FromAzureBlob GeneratorConfiguration YAML block
  - Denying without listing the real catalog (from FB s10/s16)
  - Not offering the FromS3 alternative or custom IGenerator path
  - Not asking which path the user wants (S3-compat? custom? live docs check?)
