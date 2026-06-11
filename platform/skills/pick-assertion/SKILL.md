---
name: pick-assertion
version: 1.0.0
description: Select the correct assertion from the 11 available; fetch exact AssertionConfiguration keys from live docs.
when_to_use: Authoring the Assertions block of a runner YAML; need to choose an assertion and its configuration.
inputs:
  - what_to_verify: e.g. "HTTP status 200", "all outputs arrived", "delay < 10s", "output matches CSV"
  - session_names: sessions whose SessionData the assertion reads
outputs:
  - assertion_name: simple class name for the Assertion field
  - assertion_configuration_yaml: exact AssertionConfiguration block
fact_base_slices: [s09, s13, s16]
references: []
contract:
  done_rubric:
    - 'Assertion name exists in the decision table or was found via s16 discovery protocol'
    - 'All AssertionConfiguration keys fetched from live docs page OR verbatim from FB s09 snapshot (noted as fallback)'
    - 'Hermetic count guard present alongside any HttpStatus or content assertion'
  failure_modes:
    - 'HttpStatus uses ExpectedStatus/OutputName instead of StatusCode/OutputNames (FB s13#4)'
    - 'HermeticByExpectedOutputCount uses ExpectedOutputCount instead of ExpectedCount (FB s13#12)'
    - 'HttpStatus passes vacuously with 0 outputs — no hermetic guard (FB s13#13)'
    - 'Missing QaaS.Common.Assertions PackageReference -> FTL exit -532462766 (FB s13#8)'
  escalation: 'NEEDS_CLARIFICATION: verification intent not mappable to the 11 assertions'
---

## When to use

Call this skill inside `author-runner-yaml` Step 6 (Assertions). All 11 built-in assertions
live in `QaaS.Common.Assertions` — add that PackageReference to the runner csproj (FB s13#8).

## Steps

### 1. Match intent to assertion

Docs-path template: `assertions/availableAssertions/<Name>/configuration/`

| What to verify | Assertion |
|---|---|
| Output count == N | `HermeticByExpectedOutputCount` |
| Output count in [min, max] | `HermeticByExpectedOutputCountInRange` |
| Outputs == inputs × pct% | `HermeticByInputOutputPercentage` |
| Output ratio in [min%, max%] | `HermeticByInputOutputPercentageInRange` |
| Count ratio vs metric ratio | `ValidateHermeticMetricsByInputOutputPercentage` |
| Average input→output delay ≤ MaxMs | `DelayByAverage` |
| Chunk-to-chunk delay ≤ MaxMs | `DelayByChunks` |
| All outputs deserialize to type | `OutputDeserializableTo` |
| Each output matches JSON Schema | `ObjectOutputJsonSchema` |
| Output JSON fields match CSV expectations | `OutputContentByExpectedCsvResults` |
| All HTTP outputs have expected status | `HttpStatus` |

### 2. Fetch exact config keys from live docs

Run `/qaas:docs assertions/availableAssertions/<Name>/configuration/` for the chosen assertion.
Use the `yamlView` page. Copy keys verbatim — unknown keys are silently ignored (FB s13#12).

### 3. If `/qaas:docs` is unreachable, use FB s09 snapshot

Fall back to `FB s09` (version-stamped Runner 4.5.1 / Mocker 2.4.1). Note that keys come from
snapshot. Critical traps: HttpStatus keys are `StatusCode` + `OutputNames` (list) — NOT
`ExpectedStatus`/`OutputName` (FB s13#4). `ExpectedCount` NOT `ExpectedOutputCount` (FB s13#12).

### 4. If assertion not in table, run s16 discovery protocol

Before claiming an assertion does not exist: fetch `/qaas:docs assertions/availableAssertions/`
and list what is available. If still absent, route to `author-custom-hook` (FB s16).

## Hermetic guard rule — MANDATORY (CONSTITUTION VII, FB s13#13)

Every HTTP/queue session MUST pair any content or status assertion with a count guard:

```yaml
- Name: StatusOk
  Assertion: HttpStatus
  SessionNames: [HelloSession]
  AssertionConfiguration:
    StatusCode: 200
    OutputNames: [CallHello]   # NOT OutputName; must be a list

- Name: ExactlyOneOutput       # REQUIRED guard — prevents vacuous pass
  Assertion: HermeticByExpectedOutputCount
  SessionNames: [HelloSession]
  AssertionConfiguration:
    OutputNames: [CallHello]
    ExpectedCount: 1           # NOT ExpectedOutputCount (FB s13#12)
```

HttpStatus passes **vacuously** when zero HTTP outputs arrive (FB s13#13, LAB L7).

## Key exact-name pitfalls (FB s13#4, FB s13#12)

| WRONG (silently ignored) | CORRECT |
|---|---|
| `ExpectedStatus: 200` | `StatusCode: 200` |
| `OutputName: CallHello` | `OutputNames: [CallHello]` (list) |
| `ExpectedOutputCount: 1` | `ExpectedCount: 1` |

## Package reference (FB s13#8)

```xml
<PackageReference Include="QaaS.Common.Assertions" Version="3.5.1" />
```

Missing → `FTL ... IAssertion hook instance X not found` then DI crash exit `-532462766`.

## Citations

- FB s16 (hook name index + discovery-before-denial protocol)
- FB s09 (11 assertions catalog — snapshot fallback, Runner 4.5.1 / Mocker 2.4.1)
- FB s02 §2.9 (assertion entry shape, result statuses)
- FB s13#4 (HttpStatus correct keys: StatusCode + OutputNames)
- FB s13#8 (QaaS.Common.Assertions PackageReference mandatory)
- FB s13#12 (unknown config keys silently ignored)
- FB s13#13 (HttpStatus vacuous pass — zero outputs)
- CONSTITUTION VII (hermetic guard rule)

## Traps

- **s13#4** — `ExpectedStatus`/`OutputName` (old docs) → silently ignored; use `StatusCode`/`OutputNames`
- **s13#12** — `ExpectedOutputCount` instead of `ExpectedCount` → ignored; assertion compares against 0
- **s13#13** — omit hermetic guard → HttpStatus green even when mocker is down (false green, LAB L7)
- **s13#6** — broken assertion (exception) ≠ failed; investigate session data, not assertion config
- **s13#8** — `QaaS.Common.Assertions` absent from csproj → FTL + exit `-532462766`
