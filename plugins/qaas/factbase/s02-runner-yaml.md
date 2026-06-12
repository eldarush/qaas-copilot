## 2. TASK: Author Runner YAML

Top-level sections: `MetaData`, `variables`, `anchors`, `Storages`, `DataSources`, `Sessions`,
`Assertions`, `Links`. (docs/qaas/architecture.md)

### 2.1 MetaData (docs .../configurationSections/metaData/overview.md)
- `System` (req), `Team` (req), `ExtraLabels` (opt dict). Identifies/filters the run in reports.

### 2.2 Variables (placeholders) (docs/qaas/quickStart/makeTestMoreMaintainable.md)
- Syntax `${variables:key1:key2}`, default `${variables:key:subkey??default}`.
- `variables:` section, camelCase, **non-logical values only**.

### 2.3 Anchors (YAML merge) (same doc)
- `&name`, `*name`, `<<: *name`. Put under `anchors:`. **Anchors do NOT work across overwrite files.**

### 2.4 Storages — persistence for act/assert SessionData
- **[LAB] CORRECT SHAPE** (schema-verified):
```yaml
Storages:
  - FileSystem:
      Path: ./session-data        # relative to runner CWD at act-time
      # optionally: Configuration / JsonStorageFormat, or S3 instead of FileSystem
```
- ⚠️ Docs quickstart shows `Name:` + `StorageConfiguration: {Type: Local, Path: ...}` and
  `StorageType: FileSystem` + `Configuration:` — **both are doc-drift; use the FileSystem shape above.**
  (LAB L3 #2; cf. docs 01/09 which are outdated.)
- S3 storage fields: AccessKey, SecretKey, ServiceURL, StorageBucket (req); Prefix, Delimiter,
  ForcePathStyle=true, MaximumRetryCount=0, SkipEmptyObjects=true. (06)
- Case runs append a subfolder named after the case (illegal chars `/ \` → `_`); `assert` must read
  the same path `act` wrote. (06, 09)

### 2.5 DataSources / Generators
Required: `Name`, `Generator` (hook simple name). Optional: `GeneratorConfiguration`, `Lazy`(false),
`DataSourceNames`, `DataSourcePatterns`, `Serialize` XOR `Deserialize`. (03)
- `DataArrangeOrder` (deterministic recommended): **AsciiAsc** (A–Z, RECOMMENDED), AsciiDesc,
  FirstNumericalAsc/Desc, Unordered. (03)
- `StorageMetaData`: FullPath/RelativePath(default)/ItemName/None.
- **11 generators catalog → §10.** Package: `QaaS.Common.Generators`.
- Minimal:
```yaml
DataSources:
  - Name: FromFileSystemTestData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData/orders }
```
- **The file filter is `SearchPattern` inside `FileSystem:`** (`FileSystem: {Path: TestData,
  SearchPattern: '*.csv'}`) — LAB-verified at template AND runtime. There is NO `Pattern` key
  (warns `not found`, silently ignored → generator reads ALL files under `Path`, s13#20).
  Subfolder-per-DataSource also works and keeps layouts obvious.
- **Sending a JSON file's content over HTTP**: FromFileSystem items carry raw file `byte[]`;
  `InputSerialize: Json` would base64-wrap them into a quoted JSON string on the wire (s13#26).
  Add DataSource-level `Deserialize: {Deserializer: Json}` (DataSourceBuilder: `Serialize` XOR
  `Deserialize`) so the bytes decode to a JSON node and the wire body is the real JSON object. [LAB H132]

### 2.6 Sessions (docs .../sessions/**)
Session-level fields: `Name`(req), `Category`(filter via `-I`), `Stage`(default=array index),
`RunUntilStage`, `SaveData`(true), `TimeZoneId`("Asia/Jerusalem"), `TimeoutBeforeSessionMs`(0),
`TimeoutAfterSessionMs`(0); `Stages[]`: StageNumber/TimeoutBefore/TimeoutAfter. (04)
Action collections: **Publishers, Consumers, Transactions, Collectors, Probes, MockerCommands** +
shared **Policies**. Each session emits SessionData `inputs`/`outputs` arrays (ascending timestamp).

Default stages: Consumers=0, Publishers=1, Transactions=2, Probes=3, MockerCommands=4. Same-stage
actions run together. (04)

**Action → evidence picker** (actionSelectionPlaybook):
| Intent | Use | SessionData |
|---|---|---|
| send + verify downstream | Publisher | Input named after publisher |
| read broker/table/bucket/queue | Consumer | Output named after consumer |
| request/response (HTTP/gRPC) | Transaction | Input + Output named after transaction |
| query telemetry over window | Collector | Output named after collector |
| prepare/clean infra | Probe | none |
| change/consume mock at runtime | MockerCommand | Consume can create Input+Output |

#### Publishers (Sessions[].Publishers[]) — creates an Input
Fields: Name(req), Iterations(1), Loop(false), SleepTimeMs(0), Stage(1), DataSourceNames,
DataSourcePatterns, Policies, Chunk{ChunkSize}, DataFilter{Body,MetaData,Timestamp}, Serialize,
Parallel{Parallelism}. (04)
Protocols (11): RabbitMq, KafkaTopic, Redis, MsSqlTable, PostgreSqlTable, OracleSqlTable,
MongoDbCollection, ElasticIndex, S3Bucket, Socket, Sftp. (key fields → §4-sessions notes; e.g.
RabbitMq: Host req, Port 5672, Username/Password "admin", ExchangeName/QueueName, RoutingKey "/").
NOTE: Consumers ALWAYS need ExchangeName — QueueName alone binds to the default exchange → ACCESS_REFUSED (s13#28).

#### Consumers (Sessions[].Consumers[]) — creates an Output
Fields: Name(req), **TimeoutMs(req)** = time since last message read; InitialTimeoutMs(before first
msg), Stage(0), Policies, DataFilter, Deserialize{Deserializer,SpecificType}. (04)
Protocols (10): RabbitMq, KafkaTopic, MsSqlTable, PostgreSqlTable, OracleSqlTable, TrinoSqlTable,
ElasticIndices, S3Bucket, Socket, IbmMqQueue.
- Consumer timeout must exceed expected async processing time, else flaky/empty output.
- **Bind-before-publish (s13#24):** messages published before the consumer binds are DROPPED.
  Keep Publisher+Consumer in the SAME session (Consumers=0 binds before Publishers=1); a Consumer
  in a later session gets 0 outputs unless a durable queue+binding pre-exists (Stage-0 probes).

#### Transactions (Sessions[].Transactions[]) — creates Input + Output
Fields: Name(req), **TimeoutMs(req)**, Iterations(1), Loop(false), SleepTimeMs(0), Stage(2),
**DataSourceNames or DataSourcePatterns (REQUIRED — validation error otherwise) [LAB L3#3]**,
InputDataFilter, InputSerialize, OutputDataFilter, OutputDeserialize, Parallel. (04)
Protocols (2): **Http**, **Grpc**.
- Http: BaseAddress(req `http(s)://`), Method(Post/Put/Get/Delete req), Port(8080), Route(""),
  Headers, RequestHeaders, Retries(1), MessageSendRetriesIntervalMs(1000), JwtAuth{Secret,
  BuildJwtConfig=true, Claims, HierarchicalClaims, HttpAuthScheme(Bearer/Basic/Digest/JWT/ApiKey/
  Token), JwtAlgorithm(HMACSHA256Algorithm)}.
  - **[LAB L3#5] `Route` must NOT have a leading slash.** `BaseAddress` already ends `/`; `Route:/hello`
    → `//hello` → mocker DefaultNotFoundTransaction → 404. Use `Route: hello`.
- Grpc: Host, Port, AssemblyName, ProtoNameSpace, ServiceName, RpcName (all req).

#### Collectors (Sessions[].Collectors[]) — creates an Output
Fields: Name(req), EndTimeReachedCheckIntervalMs(1000), CollectionRange{StartTimeMs(0),EndTimeMs(0)
relative to session start}, DataFilter. Protocol (1): **Prometheus** {Url(req base, no route),
Expression(req query_range), ApiKey, SampleIntervalMs(30000), TimeoutMs(120000)}. Returns matrix
`{metric{__name__,label}, value:[epochSec,"str"]}`. (04)

#### Probes (Sessions[].Probes[]) — no SessionData
Fields: Name(req), **Probe**(impl simple name, req), ProbeConfiguration(dict), Configuration,
Stage(3), DataSourceNames, DataSourcePatterns. **Probes catalog (41 documented) → §11.** Pkg `QaaS.Common.Probes`.

#### MockerCommands (Sessions[].MockerCommands[]) — Redis control plane
Fields: Name(req), ServerName(req — must byte-match mocker `Controller.ServerName`),
RequestDurationMs(3000), RequestRetries(3), Stage(4), Command(req), Redis(req). (04, r07)
- Redis: Host(req "host:port"), AbortOnConnectFail(true), AsyncTimeoutMs(5000), ConnectRetry(3),
  KeepAliveSeconds(60), Password, RedisDataBase(0), Ssl(false), Username...
- Commands:
  - `ChangeActionStub{ActionName, StubName}` — idempotent.
  - `TriggerAction{ActionName, TimeoutMs(0)}`.
  - `Consume{TimeoutMs(req), ActionName(opt=all), InputDataFilter, InputDeserialize{Deserializer,
    SpecificType}, OutputDataFilter, OutputDeserialize}` — **destructive** (drains mock queue once).
- If Redis unreachable / Controller unconfigured → Mocker servers still run, but MockerCommands
  **silently time out** (no error). (r07 #7/#10)

### 2.7 Policies (on Publishers/Consumers/Transactions) (docs .../sessions/types/policies.md)
- `LoadBalance{Rate(req), TimeIntervalMs(1000)}` — constant rate.
- `IncreasingLoadBalance{StartRate, MaxRate, RateIncrease(1), RateIncreaseIntervalMs(1000),
  TimeIntervalMs(1000)}`.
- `AdvancedLoadBalance{Stages:[{Rate, Amount?, TimeIntervalMs(1000), TimeoutMs?}]}`.
- `Count{Count}` — cap N actions. `Timeout{TimeoutMs}` — stop after timeout.

### 2.8 Serializers / Deserializers (04)
Both sets: **Binary, Json, MessagePack, Xml, Yaml, ProtobufMessage, XmlElement**.
- Serialize on Publishers (`Serialize`) and Transactions (`InputSerialize`).
- Deserialize on Consumers (`Deserialize`), Transactions (`OutputDeserialize`), MockerCommands
  (Input/OutputDeserialize). `SpecificType{TypeFullName(req), AssemblyName(opt=entry asm)}`.

### 2.9 Assertions (top-level array)
Entry shape (docs .../assertions/overview.md):
```yaml
Assertions:
  - Name: <reporting name>
    Assertion: <hook simple name>
    SessionNames: [ ... ]        # required: data providers
    DataSourceNames: [ ... ]     # optional: some assertions need schemas/expected data
    AssertionConfiguration: { ... }
    Links: [ ... ]
    SaveAttachments: true        # defaults all true
    SaveSessionData: true
    SaveLogs: true
    SaveTemplate: true
    DisplayTrace: true
    StatusesToReport: [ ... ]
```
- Result statuses: **Passed | Failed | Broken**. Bool return: true→Passed, false→Failed; thrown
  exception→Broken. Hook sets `AssertionMessage`/`AssertionTrace`/`AssertionAttachments`. (05)
- **11 assertions catalog → §9.** Package `QaaS.Common.Assertions`.

### 2.10 Links (docs .../links/overview.md) — observability deep links
Report-level `Links[]` or per-assertion. Types: **Kibana** {Url req, DataViewId, KqlQuery,
TimestampField(@timestamp)}, **Prometheus** {Url req, Expressions[]}, **Grafana** {Url req,
DashboardId req, Variables[{Key,Value}]}. Use placeholders for dynamic URLs. (06)

### 2.11 Maintainability: overwrite files, cases (makeTestMoreMaintainable.md)
- **Overwrite files** `-w`: env-specific values; files use plain `.yaml` (not `.qaas.yaml`).
  e.g. `Variables/local.yaml`. Anchors don't cross these.
- **Cases** `-c <folder>`: test variants. Path-key notation `DataSources:0:`,
  `Sessions:0:Publishers:0:Serialize:Serializer`. Allure groups results under each case file.
- Overwrite-argument format `-r Path:To:Key=Value` (e.g. `-r MetaData:Environment=qa`).

---

