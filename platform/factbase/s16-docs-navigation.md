# s16 — Docs Navigation & Hook Name Index

Use `/qaas:docs <path>` to fetch live pages (resolves against `$QAAS_DOCS_URL`).
Snapshot slices `s09`–`s12` are OFFLINE FALLBACK only (Runner 4.5.1 / Mocker 2.4.1).

## DISCOVERY-BEFORE-DENIAL protocol

Before claiming a hook does or does not exist:
1. Check the name index below.
2. If not listed here, fetch the family catalog page — `/qaas:docs <family>/available<Family>/` — and LIST what exists; never assert absence without fetching the live catalog.
3. If a matching hook exists, fetch its `.../configuration/` page via `/qaas:docs` for EXACT keys BEFORE authoring any YAML.
4. If truly absent after listing the live catalog, route to `author-custom-hook` to write a new C# hook.
5. Slices `s09`–`s12` are the OFFLINE FALLBACK — use only when `/qaas:docs` is unreachable; they are version-stamped snapshots, not live truth.

**s13 rule:** `s13` drift traps stay authoritative even over live docs (corrections, not catalogs).

## Runner / Mocker config reference pages

Fetch via `/qaas:docs <path>`:
- Runner config sections: `qaas/userInterfaces/runner/configurationSections/`
- Mocker config sections: `mocker/userInterfaces/mocker/configurationSections/`
- Generated schemas: `_generated/schemas/`

## Assertions (11) — path template: `assertions/availableAssertions/<Name>/configuration/`

| Name | Purpose |
|---|---|
| DelayByAverage | avg input→output delay ≤ MaxMs |
| DelayByChunks | chunk-to-chunk delay ≤ MaxMs |
| HermeticByExpectedOutputCount | output count == N |
| HermeticByExpectedOutputCountInRange | output count in [min,max] |
| HermeticByInputOutputPercentage | outputs == inputs × pct% |
| HermeticByInputOutputPercentageInRange | output ratio in [min%,max%] |
| ValidateHermeticMetricsByInputOutputPercentage | count ratio vs metric ratio |
| OutputDeserializableTo | all outputs deserialize to type |
| ObjectOutputJsonSchema | output matches JSON schema |
| OutputContentByExpectedCsvResults | output JSON fields match CSV |
| HttpStatus | all outputs have expected HTTP status |

## Generators (11) — path template: `generators/availableGenerators/<Name>/configuration/`

| Name | Purpose |
|---|---|
| FromCSV | rows from CSV files |
| FromDataLake | rows from Trino query |
| FromFileSystem | files as items |
| LettuceFromFileSystem | Lettuce-format files |
| FromS3 | objects from S3/MinIO |
| FromDataSources | re-emit parent data |
| FromLettuceDataSources | re-emit Lettuce JSON |
| FromSessionDataDataSources | items from prior session output |
| Stacking | interleave multiple sources |
| Json | synthetic JSON from template |
| JsonSchemaDraft4 | synthetic from JSON schema |

## Probes (41 in mirror; s11 labels 43) — path template: `probes/availableProbes/<Name>/configuration/`

| Name | Purpose |
|---|---|
| CreateRabbitMqBindings | create RMQ bindings |
| CreateRabbitMqExchanges | create RMQ exchanges |
| CreateRabbitMqQueues | create RMQ queues |
| CreateRabbitMqUsers | create RMQ users |
| CreateRabbitMqVirtualHosts | create RMQ vhosts |
| DeleteRabbitMqBindings | delete RMQ bindings |
| DeleteRabbitMqExchanges | delete RMQ exchanges |
| DeleteRabbitMqPermissions | delete RMQ permissions |
| DeleteRabbitMqQueues | delete RMQ queues |
| DeleteRabbitMqUsers | delete RMQ users |
| DeleteRabbitMqVirtualHosts | delete RMQ vhosts |
| DownloadRabbitMqDefinitions | download RMQ definitions |
| UploadRabbitMqDefinitions | upload RMQ definitions |
| PurgeRabbitMqQueues | purge RMQ queues |
| UpsertRabbitMqPermissions | upsert RMQ permissions |
| ExecuteRedisCommand | execute single Redis command |
| ExecuteRedisCommands | execute multiple Redis commands |
| EmptyRedisByChunks | empty Redis by chunks |
| FlushAllRedis | flush all Redis databases |
| FlushDbRedis | flush one Redis database |
| CreateS3Bucket | create S3 bucket |
| DeleteS3Bucket | delete S3 bucket |
| EmptyS3Bucket | empty S3 bucket |
| DeleteElasticIndices | delete Elasticsearch indices |
| EmptyElasticIndices | empty Elasticsearch indices |
| DropMongoDbCollection | drop MongoDB collection |
| EmptyMongoDbCollection | empty MongoDB collection |
| MsSqlDataBaseTablesTruncate | truncate MSSQL tables |
| OracleSqlDataBaseTablesTruncate | truncate Oracle tables |
| PostgreSqlDataBaseTablesTruncate | truncate PostgreSQL tables |
| OsEditYamlConfigMap | edit K8s ConfigMap YAML |
| OsChangeDeploymentEnvVars | change K8s deployment env vars |
| OsChangeStatefulSetEnvVars | change K8s statefulset env vars |
| OsUpdateDeploymentImage | update K8s deployment image |
| OsUpdateStatefulSetImage | update K8s statefulset image |
| OsExecuteCommandsInContainers | exec commands in K8s containers |
| OsRestartPods | restart K8s pods |
| OsUpdateDeploymentResources | update K8s deployment resources |
| OsUpdateStatefulSetResources | update K8s statefulset resources |
| OsScaleDeploymentPods | scale K8s deployment pods |
| OsScaleStatefulSetPods | scale K8s statefulset pods |

## Processors (9) — path template: `processors/availableProcessors/<Name>/configuration/`

| Name | Purpose |
|---|---|
| StaticResponseProcessor | fixed body response |
| StatusCodeTransactionProcessor | status code, empty body |
| RequestEchoProcessor | echo request body as JSON |
| PassThroughProcessor | return body unchanged |
| JsonEnvelopeProcessor | wrap body in JSON property |
| TextTransformProcessor | trim/replace/prefix/suffix body |
| ConditionalResponseProcessor | route by header or path param |
| DataSourceResponseProcessor | return item from data source |
| ProblemDetailsProcessor | RFC 7807 problem details |
