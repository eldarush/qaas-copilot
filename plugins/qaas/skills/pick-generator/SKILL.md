---
name: pick-generator
version: 1.0.0
description: Select the correct generator from the 11 available and supply exact GeneratorConfiguration keys.
when_to_use: Authoring a DataSources entry and need to choose a Generator and its configuration.
inputs:
  - data_location: where test data lives (folder, CSV, S3, DB query, chained datasource, etc.)
  - data_shape: fixed files / synthetic JSON / schema-generated / combined sources
outputs:
  - generator_name: simple class name to use as Generator value
  - generator_configuration_yaml: exact GeneratorConfiguration block
fact_base_slices: [s10, s13]
references: []
contract:
  done_rubric:
    - 'Generator name and all config keys exist verbatim in FB s10'
    - 'QaaS.Common.Generators PackageReference added to csproj when any built-in generator is used'
    - 'No config key is guessed — every key copied from FB s10 table'
  failure_modes:
    - 'Missing QaaS.Common.Generators PackageReference -> FTL exit -532462766 (FB s13#8)'
    - 'Unknown GeneratorConfiguration key silently ignored -> wrong behavior (FB s13#12)'
    - 'DataArrangeOrder omitted on filesystem generators -> non-deterministic order'
  escalation: 'NEEDS_CLARIFICATION: data source type not in the 11-generator list'
---

## When to use

Call this skill inside `author-runner-yaml` Step 4 (DataSources). All 11 built-in generators
live in `QaaS.Common.Generators` — add that PackageReference to the runner csproj (FB s13#8).

## Steps

### 1. Select generator from the decision table (FB s10)

| When you need... | Use generator | Key config fields |
|---|---|---|
| **Fixed files on disk** (JSON, XML, CSV payloads in TestData/) | `FromFileSystem` | `FileSystem.Path`(req), `SearchPattern`, `DataArrangeOrder`(AsciiAsc recommended), `Count`, `StorageMetaData` |
| **Fixed Lettuce-format files** | `LettuceFromFileSystem` | same as FromFileSystem |
| **Rows from a CSV file** | `FromCSV` | `FileSystem.Path`(req), `SearchPattern`, `DataArrangeOrder`, `Delimiter`(','), `HasHeaderRecord`(true), `ColumnNames[]`, `SkipEmptyRows`(true), `TrimWhiteSpace`(false), `Count` |
| **Objects from S3 / MinIO** | `FromS3` | `S3.StorageBucket`(req), `S3.ServiceURL`(req), `S3.AccessKey`(req), `S3.SecretKey`(req), `S3.ForcePathStyle`(true), `DataArrangeOrder`, `Count` |
| **Rows from Trino / DataLake query** | `FromDataLake` | `TrinoServerUri`(http://localhost:8080), `Username`(req), `Password`(req), `ClientTag`(qaas), `Catalog`(hive), `Query`(req), `ColumnsToIgnore[]` |
| **Re-emit items from parent datasource** | `FromDataSources` | `Count`, `Parent.DataSourceNames`(req) |
| **Re-emit Lettuce JSON from parent** | `FromLettuceDataSources` | `Count`, `Parent.DataSourceNames`(req) |
| **Items from prior SessionData outputs/inputs** | `FromSessionDataDataSources` | array of `{SessionName(req), CommunicationDataList:[{Name(req), Type: Input\|Output}]}` |
| **Interleave / combine multiple sources** | `Stacking` | `Count`(req), `ItemsPerGenerator[]`(req), `LoopFinishedGenerators`(false), `Parent.DataSourceNames`(req) |
| **Synthetic JSON from a template + field replacements** | `Json` | `JsonDataSourceName`(req), `Count`(req), `OutputObjectType`(Json\|Custom), `JsonFieldReplacements[{Path(JSONPath), ValueType, <Type>{Value}}]` |
| **Synthetic JSON generated from a JSON Schema Draft 4** | `JsonSchemaDraft4` | `JsonDataSourceName`(req), `Count`(req), `Seed`(for reproducibility), `JsonFieldReplacements[]` |

### 2. Configuration notes

**DataArrangeOrder** (applicable to FromFileSystem, FromCSV, FromS3):
- `AsciiAsc` — A→Z, RECOMMENDED for deterministic test order (FB s02 §2.5)
- `AsciiDesc`, `FirstNumericalAsc`, `FirstNumericalDesc`, `Unordered`

**StorageMetaData** (FromFileSystem, FromCSV, FromS3):
- `RelativePath` (default), `FullPath`, `ItemName`, `None`

**Seed** (JsonSchemaDraft4): integer; set for reproducible synthetic data across runs.

**JsonFieldReplacements** (Json, JsonSchemaDraft4): JSONPath `Path`, then `ValueType` +
type-specific sub-key (e.g. `Constant: {Value: "foo"}`, `Random: {Min:0, Max:100}`).

**Lazy** (all generators): `false` by default; `true` defers data load until needed.

**Serialize / Deserialize on DataSource** (FB s02 §2.5): use `Serialize` XOR `Deserialize`
on the DataSource entry, not on the generator.

### 3. Minimal examples

**FromFileSystem** (most common):
```yaml
DataSources:
  - Name: HelloData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData }
```

**FromCSV**:
```yaml
DataSources:
  - Name: CsvInput
    Generator: FromCSV
    GeneratorConfiguration:
      FileSystem: { Path: TestData, SearchPattern: "*.csv" }
      DataArrangeOrder: AsciiAsc
      Delimiter: ","
      HasHeaderRecord: true
```

**Json** (synthetic from template):
```yaml
DataSources:
  - Name: Template
    Generator: FromFileSystem
    GeneratorConfiguration:
      FileSystem: { Path: Templates }
  - Name: Synthetic
    Generator: Json
    GeneratorConfiguration:
      JsonDataSourceName: Template
      Count: 10
      JsonFieldReplacements:
        - Path: "$.id"
          ValueType: Guid
          Guid: {}
```

**FromSessionDataDataSources** (chain prior session output):
```yaml
DataSources:
  - Name: PriorOutput
    Generator: FromSessionDataDataSources
    GeneratorConfiguration:
      - SessionName: UpstreamSession
        CommunicationDataList:
          - Name: Consumer
            Type: Output
```

### 4. Package reference requirement (FB s13#8)

All 11 built-in generators require `QaaS.Common.Generators` in the runner csproj (version `3.5.1`,
NOT `4.5.1` — it is versioned independently of `QaaS.Runner`):

```xml
<PackageReference Include="QaaS.Common.Generators" Version="3.5.1" />
```

Missing → `FTL ... IGenerator hook instance X not found in any of the provided assemblies`
then DI crash exit `-532462766`.

## Citations

- FB s10 (generator catalog — all 11 generators, exact config keys)
- FB s02 §2.5 (DataSources section, DataArrangeOrder, StorageMetaData)
- FB s13#8 (QaaS.Common.Generators PackageReference mandatory)
- FB s13#12 (unknown config keys silently ignored — copy keys verbatim)

## Traps

- **s13#8** — `QaaS.Common.Generators` PackageReference missing → FTL + exit `-532462766`
- **s13#12** — unknown key in `GeneratorConfiguration` silently ignored; no warning, wrong behavior;
  copy ALL keys verbatim from FB s10 table
- **DataArrangeOrder omitted** — order non-deterministic; flaky tests; always set `AsciiAsc`
- **FromDataSources / Stacking need `Parent.DataSourceNames`** — req; omitting → no data emitted
- **JsonSchemaDraft4 without Seed** — different data each run; set `Seed` for reproducibility
