> SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1 — fetch live docs first (see FB s16); verify against your docs when reachable.

## 10. CATALOG — 11 Generators (pkg `QaaS.Common.Generators`; src 03)
External (5): **FromCSV, FromDataLake, FromFileSystem, LettuceFromFileSystem, FromS3**.
DataSource consumers (4): **FromDataSources, FromLettuceDataSources, FromSessionDataDataSources,
Stacking**. JSON templating (2): **Json, JsonSchemaDraft4**.

| Generator | Purpose | Key config |
|---|---|---|
| *(live docs path)* | *fetch exact keys via `/qaas:docs generators/availableGenerators/<Name>/configuration/` (see FB s16)* | *SNAPSHOT fallback only* |
| FromCSV | rows from CSV files | FileSystem{Path,SearchPattern}, **DataArrangeOrder**, **Delimiter**(','), HasHeaderRecord(true), ColumnNames[], SkipEmptyRows(true), TrimWhiteSpace(false), Count, DataUuidRegexExpression('.*'), StorageMetaData |
| FromDataLake | rows from Trino query | TrinoServerUri(http://localhost:8080), **Username**, **Password**, ClientTag(qaas), Catalog(hive), **Query**, ColumnsToIgnore[] |
| FromFileSystem | files as items | **FileSystem.Path**, SearchPattern, **DataArrangeOrder**, Count, DataUuidRegexExpression, StorageMetaData |
| LettuceFromFileSystem | Lettuce files | same as FromFileSystem |
| FromS3 | objects from S3/MinIO | S3{**StorageBucket,ServiceURL,AccessKey,SecretKey**,ForcePathStyle(true),Delimiter,Prefix,SkipEmptyObjects(true)}, **DataArrangeOrder**, LoadMetadataFirst(true), Count, StorageMetaData |
| FromDataSources | re-emit parent data | Count, **Parent.DataSourceNames** |
| FromLettuceDataSources | re-emit Lettuce JSON | Count, **Parent.DataSourceNames** |
| FromSessionDataDataSources | items from prior SessionData | [{**SessionName**, **CommunicationDataList**:[{Name, Type: Input|Output}]}] |
| Stacking | interleave multiple sources | **Count**, **ItemsPerGenerator[]**, LoopFinishedGenerators(false), **Parent.DataSourceNames** |
| Json | template JSON, replace fields | **JsonDataSourceName**, **Count**, OutputObjectType(Json|Custom), JsonFieldReplacements[{Path(JSONPath), ValueType, <Type>{Value}}] |
| JsonSchemaDraft4 | generate from JSON schema | **JsonDataSourceName**, **Count**, Seed, JsonFieldReplacements[] |

---

