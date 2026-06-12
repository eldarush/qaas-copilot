---
name: pick-generator
version: 1.0.0
description: Select the correct generator from the 11 available; fetch exact GeneratorConfiguration keys from live docs.
when_to_use: Authoring a DataSources entry and need to choose a Generator and its configuration.
inputs:
  - data_location: where test data lives (folder, CSV, S3, DB query, chained datasource, etc.)
  - data_shape: fixed files / synthetic JSON / schema-generated / combined sources
outputs:
  - generator_name: simple class name to use as Generator value
  - generator_configuration_yaml: exact GeneratorConfiguration block
fact_base_slices: [s10, s13, s16]
references: []
contract:
  done_rubric:
    - 'Generator name exists in the decision table or was found via s16 discovery protocol'
    - 'All config keys fetched from live docs page OR verbatim from FB s10 snapshot (noted as fallback)'
    - 'QaaS.Common.Generators PackageReference added to csproj when any built-in generator is used'
  failure_modes:
    - 'Missing QaaS.Common.Generators PackageReference -> FTL exit -532462766 (FB s13#8)'
    - 'Unknown GeneratorConfiguration key silently ignored -> wrong behavior (FB s13#12)'
    - 'DataArrangeOrder omitted on filesystem generators -> non-deterministic order'
  escalation: 'NEEDS_CLARIFICATION: data source type not in the 11-generator list and discovery protocol found no match'
---

## When to use

Call this skill inside `author-runner-yaml` Step 4 (DataSources). All 11 built-in generators
live in `QaaS.Common.Generators` — add that PackageReference to the runner csproj (FB s13#8).

## Steps

### 1. Select generator from the decision table

Docs-path template: `generators/availableGenerators/<Name>/configuration/`

| When you need... | Use generator |
|---|---|
| Fixed files on disk (JSON, XML, CSV payloads) | `FromFileSystem` |
| Fixed Lettuce-format files | `LettuceFromFileSystem` |
| Rows from a CSV file | `FromCSV` |
| Objects from S3 / MinIO | `FromS3` |
| Rows from Trino / DataLake query | `FromDataLake` |
| Re-emit items from parent datasource | `FromDataSources` |
| Re-emit Lettuce JSON from parent | `FromLettuceDataSources` |
| Items from prior SessionData outputs/inputs | `FromSessionDataDataSources` |
| Interleave / combine multiple sources | `Stacking` |
| Synthetic JSON from a template + field replacements | `Json` |
| Synthetic JSON generated from a JSON Schema Draft 4 | `JsonSchemaDraft4` |

### 2. Fetch exact config keys from live docs

Run `/qaas:docs generators/availableGenerators/<Name>/configuration/` to get the current,
exact `GeneratorConfiguration` keys for the chosen generator. Use the `yamlView` page.
Copy keys verbatim — unknown keys are silently ignored (FB s13#12).

### 3. If `/qaas:docs` is unreachable, use FB s10 snapshot

Fall back to `FB s10` (version-stamped Runner 4.5.1 / Mocker 2.4.1). Note in your output
that keys come from the snapshot fallback, not live docs.

### 4. If hook not in table, run s16 discovery protocol

Before claiming a generator does not exist: fetch `/qaas:docs generators/availableGenerators/`
and list what is available. If still absent, route to `author-custom-hook` (FB s16).

## Key configuration notes

**DataArrangeOrder** (FromFileSystem, FromCSV, FromS3): `AsciiAsc` recommended for
deterministic order; also `AsciiDesc`, `FirstNumericalAsc`, `FirstNumericalDesc`, `Unordered`.

**Seed** (JsonSchemaDraft4): set for reproducible synthetic data across runs.

**Lazy** (all generators): `false` by default; `true` defers data load until needed.

**Parent.DataSourceNames** (FromDataSources, Stacking): required; omitting → no data emitted.

## Package reference (FB s13#8)

All 11 built-in generators require `QaaS.Common.Generators` in the runner csproj:

```xml
<PackageReference Include="QaaS.Common.Generators" Version="3.5.1" />
```

Missing → `FTL ... IGenerator hook instance X not found` then DI crash exit `-532462766`.

## Citations

- FB s16 (hook name index + discovery-before-denial protocol)
- FB s10 (generator catalog — snapshot fallback, Runner 4.5.1 / Mocker 2.4.1)
- FB s02 §2.5 (DataSources section, DataArrangeOrder, StorageMetaData)
- FB s13#8 (QaaS.Common.Generators PackageReference mandatory)
- FB s13#12 (unknown config keys silently ignored — copy keys verbatim)

## Traps

- **s13#8** — `QaaS.Common.Generators` PackageReference missing → FTL + exit `-532462766`
- **s13#12** — unknown key in `GeneratorConfiguration` silently ignored; copy ALL keys verbatim
- **DataArrangeOrder omitted** — order non-deterministic; flaky tests; always set `AsciiAsc`
- **FromDataSources / Stacking need `Parent.DataSourceNames`** — req; omitting → no data emitted
- **JsonSchemaDraft4 without Seed** — different data each run; set `Seed` for reproducibility
