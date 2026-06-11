---
name: pick-assertion
version: 1.0.0
description: Select the correct assertion from the 11 available, supply exact AssertionConfiguration keys, and apply the hermetic guard rule.
when_to_use: Authoring the Assertions block of a runner YAML; need to choose an assertion and its configuration.
inputs:
  - what_to_verify: e.g. "HTTP status 200", "all outputs arrived", "delay < 10s", "output matches CSV"
  - session_names: sessions whose SessionData the assertion reads
outputs:
  - assertion_name: simple class name for the Assertion field
  - assertion_configuration_yaml: exact AssertionConfiguration block
fact_base_slices: [s09, s13]
references: []
contract:
  done_rubric:
    - 'Assertion name and all AssertionConfiguration keys exist verbatim in FB s09'
    - 'Hermetic count guard present alongside any HttpStatus or content assertion'
    - 'QaaS.Common.Assertions PackageReference added to csproj'
  failure_modes:
    - 'HttpStatus uses ExpectedStatus/OutputName instead of StatusCode/OutputNames (FB s13#4)'
    - 'HermeticByExpectedOutputCount uses ExpectedOutputCount instead of ExpectedCount (FB s13#12)'
    - 'HttpStatus passes vacuously with 0 outputs — no hermetic guard (FB s13#13)'
    - 'Missing QaaS.Common.Assertions PackageReference -> FTL exit -532462766 (FB s13#8)'
    - 'Unknown AssertionConfiguration key silently ignored (FB s13#12)'
  escalation: 'NEEDS_CLARIFICATION: verification intent not mappable to the 11 assertions'
---

## When to use

Call this skill inside `author-runner-yaml` Step 6 (Assertions). All 11 built-in assertions
live in `QaaS.Common.Assertions` — add that PackageReference to the runner csproj (FB s13#8).

## Steps

### 1. Match intent to assertion (FB s09)

| What to verify | Assertion | Required AssertionConfiguration keys |
|---|---|---|
| **Output count == N** | `HermeticByExpectedOutputCount` | `OutputNames`(list), `ExpectedCount`(int) |
| **Output count in [min, max]** | `HermeticByExpectedOutputCountInRange` | `OutputNames`(list), `ExpectedMinimumCount`, `ExpectedMaximumCount` |
| **Outputs == inputs × pct%** | `HermeticByInputOutputPercentage` | `InputNames`(list), `OutputNames`(list), `ExpectedPercentage`; opt `InputsAreOutputs`, `MidpointRounding`(AwayFromZero\|ToEven) |
| **Output ratio in [min%, max%]** | `HermeticByInputOutputPercentageInRange` | `InputNames`, `OutputNames`, `ExpectedMinimumPercentage`, `ExpectedMaximumPercentage` |
| **Count ratio vs metric ratio** | `ValidateHermeticMetricsByInputOutputPercentage` | `InputNames`, `OutputNames`, `MetricOutputSourceName`, `InputMetricName`, `OutputMetricName`, `Tolerance`; opt Process/Combine/Filtered/SplitMetricName |
| **Average input→output delay ≤ MaxMs** | `DelayByAverage` | `InputName`, `OutputName`, `MaximumDelayMs`; opt `InputsAreOutputs`, `MaximumNegativeDelayBufferMs` |
| **Chunk-to-chunk delay ≤ MaxMs** | `DelayByChunks` | `Input: {Name, ChunkSize, ChunkTimeOption(First\|Average\|Last)}`, `Output: {Name, ChunkSize, ChunkTimeOption}`, `MaximumDelayMs`; opt `InputsAreOutputs` |
| **All outputs deserialize to type** | `OutputDeserializableTo` | `OutputName`, `Deserialize: {Deserializer, SpecificType: {AssemblyName, TypeFullName}}` |
| **Each output matches JSON Schema** | `ObjectOutputJsonSchema` | `OutputName`; + `DataSourceNames` (schema files) |
| **Output JSON fields match CSV expectations** | `OutputContentByExpectedCsvResults` | `OutputName`, `ColumnNameToFieldPathMap: {COL: {Path: $.x, FieldValidationConfig: {Type: ExactValue\|ErrorRange\|Override\|Base64ToHex}}}` ; opt `DataSourceName`, `CompareRowsNotInOrder`(false) |
| **All HTTP outputs have expected status** | `HttpStatus` | `StatusCode`(int), `OutputNames`(list) |

### 2. Assertion entry shape (FB s02 §2.9)

```yaml
Assertions:
  - Name: <reporting-name>           # shown in Allure
    Assertion: <SimpleClassName>     # from table above
    SessionNames: [<session-name>]   # REQUIRED — sessions whose SessionData is read
    DataSourceNames: [<ds-name>]     # OPTIONAL — needed by ObjectOutputJsonSchema, OutputContentByExpectedCsvResults
    AssertionConfiguration:
      # ... exact keys from table above
    SaveAttachments: true   # all Save* default true
    SaveSessionData: true
    SaveLogs: true
    SaveTemplate: true
    DisplayTrace: true
```

### 3. Result statuses: Passed / Failed / Broken (FB s02 §2.9, FB s13#6)

| Condition | Status |
|---|---|
| Hook returns `true` | **Passed** |
| Hook returns `false` | **Failed** |
| Hook throws any exception | **Broken** |
| Output missing (null source) | **Broken** — "Value cannot be null. (Parameter 'source')" |

**Broken ≠ Failed.** Broken means the assertion itself could not run (infra/data issue).
Failed means it ran and the condition was not met.

A broken assertion on a missing output (FB s13#6) means the session produced no data —
check: session ran, mocker up, connection OK, DataSourceNames present on Transaction.

### 4. Hermetic guard rule — MANDATORY (CONSTITUTION VII, FB s13#13)

Every HTTP/queue session MUST pair any content or status assertion with a count guard:

```yaml
# The content assertion:
  - Name: StatusOk
    Assertion: HttpStatus
    SessionNames: [HelloSession]
    AssertionConfiguration:
      StatusCode: 200
      OutputNames: [CallHello]   # NOT OutputName; must be a list

# REQUIRED guard — prevents vacuous pass with 0 outputs:
  - Name: ExactlyOneOutput
    Assertion: HermeticByExpectedOutputCount
    SessionNames: [HelloSession]
    AssertionConfiguration:
      OutputNames: [CallHello]
      ExpectedCount: 1           # NOT ExpectedOutputCount (FB s13#12)
```

HttpStatus passes **vacuously** when zero HTTP outputs arrive (FB s13#13, LAB L7).
A connection failure produces `Output Source X Contains 0 Outputs` in logs but does NOT
fail the run unless the hermetic guard is present.

### 5. Key exact-name pitfalls (FB s13#4, FB s13#12)

| WRONG (silently ignored) | CORRECT |
|---|---|
| `ExpectedStatus: 200` | `StatusCode: 200` |
| `OutputName: CallHello` | `OutputNames: [CallHello]` (list) |
| `ExpectedOutputCount: 1` | `ExpectedCount: 1` |
| `InputName: Publisher` | `InputNames: [Publisher]` (list) |

Unknown keys are **silently ignored** — no error, assertion compares against default,
produces a confusing failure or false-pass (FB s13#12, LAB L7).

### 6. Package reference (FB s13#8)

```xml
<PackageReference Include="QaaS.Common.Assertions" Version="3.5.1" />
```
(Version `3.5.1` — independent of `QaaS.Runner` `4.5.1`; never reuse the Runner version here.)

Missing → `FTL ... IAssertion hook instance X not found` then DI crash exit `-532462766`.

## Citations

- FB s09 (11 assertions catalog — all names and exact config keys)
- FB s02 §2.9 (assertion entry shape, result statuses)
- FB s13#4 (HttpStatus correct keys: StatusCode + OutputNames)
- FB s13#6 (missing output → Broken status)
- FB s13#8 (QaaS.Common.Assertions PackageReference mandatory)
- FB s13#12 (unknown config keys silently ignored)
- FB s13#13 (HttpStatus vacuous pass — zero outputs)
- CONSTITUTION VII (hermetic guard rule)
- LAB L7 (vacuous pass and silent-key verified in lab)

## Traps

- **s13#4** — `ExpectedStatus`/`OutputName` (old docs) → silently ignored; use `StatusCode`/`OutputNames`
- **s13#12** — `ExpectedOutputCount` instead of `ExpectedCount` → ignored; assertion compares against 0
- **s13#13** — omit hermetic guard → HttpStatus green even when mocker is down (false green, LAB L7)
- **s13#6** — broken assertion (exception) ≠ failed; investigate session data, not assertion config
- **s13#8** — `QaaS.Common.Assertions` absent from csproj → FTL + exit `-532462766`
- **Empty output + DelayByAverage** — `Empty output → pass` (assertion #1 in FB s09); pair with hermetic guard
