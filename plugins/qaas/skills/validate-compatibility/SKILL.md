---
name: validate-compatibility
version: 1.0.0
description: >-
  Validate every QaaS field, package version, and feature reference against the
  Fact Base (s13, s14) and live docs before authoring any file. Rejects deprecated
  left-column drift forms and non-existent features. Use whenever you are unsure
  whether a field, version, or config key exists in the current packages.
when_to_use: >-
  Run before writing any .qaas.yaml / .mocker.yaml, csproj, or Dockerfile when
  any field, version, or config key is uncertain. Required whenever the Fact Base
  or live docs are NOT already loaded in context. Invoke explicitly via name if
  uncertain — never guess.
inputs:
  - field_or_feature: the QaaS field name, config key, package version, or behavior to validate
  - context_slice: the Fact Base slice id (e.g. s13) or docs path that should contain the answer
outputs:
  - validation_verdict: VALID | DEPRECATED | NOT_FOUND | NEEDS_CLARIFICATION
  - citation: exact FB slice + row, or docs path + heading that backs the verdict
fact_base_slices: [s13, s14, s00, s01, s02, s03]
references:
  - factbase/s13-doc-drift.md
  - factbase/s14-golden-examples.md
contract:
  done_rubric:
    - 'Every QaaS field checked carries a citation (FB sN or docs/path) — no uncited field'
    - 'No deprecated drift-left-column form present in the validated output'
    - 'template verb output consulted as authoritative when schema oracle is needed'
    - 'Runner 4.5.1, Common.Processors 1.5.1 (and all independent version facts) confirmed before use'
  failure_modes:
    - 'Used a deprecated drift-left-column form (e.g. TransactionData, StorageConfiguration, ExpectedStatus) — must use right-column reality (FB s13)'
    - 'Assumed a uniform package version — versions are INDEPENDENT: Runner 4.5.1, Mocker 2.4.1, Common.Assertions 3.5.1, Common.Generators 3.5.1, Common.Probes 1.5.1, Common.Processors 1.5.1 (FB s13#9)'
    - 'Validated a feature not present in the current packages without citing the Fact Base — NEEDS_CLARIFICATION'
    - 'Skipped template verb output when schema oracle was available — template is authoritative (s13 preamble)'
  escalation: 'NEEDS_CLARIFICATION: <field or version> not found in Fact Base or docs context'
---

# validate-compatibility

> **When in doubt, run this skill before authoring any file.**
> The uncertainty rule: if a field name, config key, package version, or feature behavior
> is NOT confirmed in your current context (Fact Base or fetched docs), invoke this skill
> before writing. Never guess a name, base-class signature, or default.

## Purpose

This skill enforces the **DOCS-OR-SILENCE** and **DRIFT-AWARE** constitutional articles by
requiring an explicit citation for every QaaS field and rejecting any deprecated or
non-existent left-column drift form before it reaches an authored file.

The `template` verb output (schema oracle) is the authoritative resolver at runtime
(`dotnet run -- template <file>.yaml`). When a field's valid values are unclear,
run `template` and read its output — it overrides any documentation.

## The Independent Version Matrix (FB s13#9 — LAB-verified, DO NOT mix versions)

| Package | Correct Version |
|---|---|
| `QaaS.Runner` | `4.5.1` |
| `QaaS.Mocker` | `2.4.1` |
| `QaaS.Common.Assertions` | `3.5.1` |
| `QaaS.Common.Generators` | `3.5.1` |
| `QaaS.Common.Probes` | `1.5.1` |
| `QaaS.Common.Processors` | `1.5.1` |
| `.NET SDK` | `10.0.203` |

**Rule:** `Runner 4.5.1` and `Common.Processors 1.5.1` are NOT the same version —
putting `4.5.1` on a `QaaS.Common.*` reference → `NU1102 Unable to find package`.
Always cite FB s13#9 when using any version number.

## Deprecated drift-left-column forms — NEVER use these

The following are the outdated forms documented in the official docs. Using them causes
silent failures or runtime errors. The right column is the verified reality (FB s13).
No deprecated drift-left-column form present in any file validated by this skill.

| OUTDATED — left-column drift (REJECT) | CORRECT — right-column reality (USE THIS) |
|---|---|
| `TransactionData:` (mocker stub config) | `ProcessorConfiguration:` |
| `StorageConfiguration: {Type: Local, Path: ...}` | `- FileSystem: {Path: ./session-data}` |
| `ExpectedStatus:` + `OutputName:` (scalar) | `StatusCode:` + `OutputNames:` (list) |
| `Route: /hello` (leading slash) | `Route: hello` (no leading slash) |
| `mcr.microsoft.com/dotnet/runtime:10.0` (Dockerfile base) | `mcr.microsoft.com/dotnet/aspnet:10.0` |

## Validation procedure

### Step 1 — Load context

Load Fact Base slice `s13` (always) plus the relevant protocol slice (`s02` runner,
`s03` mocker, `s09` assertions). Fetch live docs with `/qaas:docs <path>` if a field is
not in the Fact Base.

### Step 2 — Validate every QaaS field with citation

For every QaaS field, config key, package version, or CLI flag you plan to use:

1. Find the field in the Fact Base or docs.
2. Record the citation: `<field> → FB s<n>#<row>` or `<field> → docs/<path>#<heading>`.
3. If the field is in the **OUTDATED left-column** of the drift table — REJECT it.
   Use the right-column reality instead and note `(drift-corrected per FB s13#N)`.
4. If the field is NOT found in any loaded context → emit
   `NEEDS_CLARIFICATION: <field> not found in Fact Base or docs` and stop.

### Step 3 — Confirm version matrix

Before referencing any NuGet package version, confirm each version against FB s13#9.
Do not assume a shared/uniform version. Runner 4.5.1 ≠ Common.Processors 1.5.1.

### Step 4 — Run template oracle (when available)

For any YAML schema uncertainty, run:

```powershell
dotnet run -- template <file>.yaml
```

The `template` output is authoritative — it overrides any documentation page or
Fact Base inference. If `template` exits non-zero, the YAML is invalid.

### Step 5 — Emit verdict

```
VALID: <field> — citation: FB s13#<n> (or docs/<path>#<heading>)
DEPRECATED: <field> — use <corrected form> per FB s13#<n>
NOT_FOUND: <field> — no citation found; emitting NEEDS_CLARIFICATION
```

## Citations

- FB s13 (all 19 drift rows — the complete compatibility source of truth)
- FB s14 (golden examples — authoritative schema shapes)
- FB s00 (index — all slice ids)
- `template` verb (schema oracle at runtime — overrides docs)
