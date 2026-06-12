# author-runner-yaml — Session Field Reference (FB s02)

Overflow from SKILL.md §5. Full field lists for each action type.

## Publishers (FB s02 §2.6)

Creates an **Input** named after the publisher.

| Field | Required | Default | Notes |
|---|---|---|---|
| Name | yes | — | names the Input in SessionData |
| Iterations | no | 1 | |
| Loop | no | false | |
| SleepTimeMs | no | 0 | |
| Stage | no | 1 | |
| DataSourceNames | no | — | |
| DataSourcePatterns | no | — | |
| Policies | no | — | LoadBalance/IncreasingLoadBalance/AdvancedLoadBalance/Count/Timeout |
| Chunk.ChunkSize | no | — | |
| DataFilter | no | — | Body/MetaData/Timestamp |
| Serialize.Serializer | no | — | Binary/Json/MessagePack/Xml/Yaml/ProtobufMessage/XmlElement |
| Parallel.Parallelism | no | — | |

**Protocols (11):** RabbitMq, KafkaTopic, Redis, MsSqlTable, PostgreSqlTable, OracleSqlTable,
MongoDbCollection, ElasticIndex, S3Bucket, Socket, Sftp.

RabbitMq key fields: `Host` (req), `Port` (5672), `Username` ("admin"), `Password` ("admin"),
`ExchangeName`, `QueueName`, `RoutingKey` ("/"). Consumers MUST set `ExchangeName` —
`QueueName` alone makes the runner bind on the DEFAULT exchange → `ACCESS_REFUSED` (FB s13#28).

## Consumers (FB s02 §2.6)

Creates an **Output** named after the consumer.

| Field | Required | Default | Notes |
|---|---|---|---|
| Name | yes | — | names the Output in SessionData |
| TimeoutMs | yes | — | time since last message read |
| InitialTimeoutMs | no | — | before first message |
| Stage | no | 0 | runs before publishers by default |
| Policies | no | — | |
| DataFilter | no | — | |
| Deserialize.Deserializer | no | — | |
| Deserialize.SpecificType | no | — | TypeFullName(req), AssemblyName(opt) |

**Protocols (10):** RabbitMq, KafkaTopic, MsSqlTable, PostgreSqlTable, OracleSqlTable,
TrinoSqlTable, ElasticIndices, S3Bucket, Socket, IbmMqQueue.

⚠️ Consumer `TimeoutMs` must exceed expected async processing time, else flaky/empty output.

## Transactions (FB s02 §2.6)

Creates **Input + Output** named after the transaction.

| Field | Required | Default | Notes |
|---|---|---|---|
| Name | yes | — | |
| TimeoutMs | yes | — | |
| DataSourceNames OR DataSourcePatterns | **YES** | — | validation error if both missing (FB s13#3) |
| Iterations | no | 1 | |
| Loop | no | false | |
| SleepTimeMs | no | 0 | |
| Stage | no | 2 | |
| InputDataFilter | no | — | |
| InputSerialize | no | — | |
| OutputDataFilter | no | — | |
| OutputDeserialize | no | — | |
| Parallel.Parallelism | no | — | |

**Protocols (2):** Http, Grpc.

Http fields: `BaseAddress` (req, `http(s)://`), `Method` (req), `Port` (8080), `Route` (""),
`Headers`, `RequestHeaders`, `Retries` (1), `MessageSendRetriesIntervalMs` (1000).
JwtAuth: `Secret`, `BuildJwtConfig` (true), `Claims`, `HierarchicalClaims`,
`HttpAuthScheme` (Bearer/Basic/Digest/JWT/ApiKey/Token), `JwtAlgorithm` (HMACSHA256Algorithm).

**`Route` MUST NOT have a leading slash (FB s13#5).** `Route: /hello` → `//hello` → 404.

Grpc fields: `Host`, `Port`, `AssemblyName`, `ProtoNameSpace`, `ServiceName`, `RpcName` (all req).

## Collectors (FB s02 §2.6)

Creates an **Output** named after the collector.

Protocol (1): **Prometheus** — `Url` (req base URL, no route), `Expression` (req query_range),
`ApiKey`, `SampleIntervalMs` (30000), `TimeoutMs` (120000).
`CollectionRange`: `StartTimeMs` (0), `EndTimeMs` (0) relative to session start.

## Probes (FB s02 §2.6, FB s11)

No SessionData. 41 documented probes available (FB s11).
Fields: `Name` (req), `Probe` (impl simple name, req), `ProbeConfiguration` (dict),
`Configuration`, `Stage` (3), `DataSourceNames`, `DataSourcePatterns`.
Package: `QaaS.Common.Probes` (FB s13#8).

Common pattern: readiness probe at Stage 0 before transactions.

## MockerCommands (FB s02 §2.6)

Redis control plane — requires mocker `Controller` configured.
Fields: `Name` (req), `ServerName` (req — must byte-match `Controller.ServerName`),
`RequestDurationMs` (3000), `RequestRetries` (3), `Stage` (4), `Command` (req), `Redis` (req).

Redis: `Host` (req "host:port"), `AbortOnConnectFail` (true), `AsyncTimeoutMs` (5000),
`ConnectRetry` (3), `Password`, `RedisDataBase` (0), `Ssl` (false).

Commands:
- `ChangeActionStub: {ActionName, StubName}` — idempotent stub swap
- `TriggerAction: {ActionName, TimeoutMs(0)}`
- `Consume: {TimeoutMs(req), ActionName(opt), InputDataFilter, InputDeserialize, OutputDataFilter, OutputDeserialize}` — destructive (drains queue)

If Redis unreachable or Controller unconfigured → MockerCommands **silently time out** (FB s02).

## Policies (FB s02 §2.7)

On Publishers/Consumers/Transactions:
```yaml
Policies:
  - LoadBalance: { Rate: 50 }
  # - IncreasingLoadBalance: { StartRate: 1, MaxRate: 100, RateIncrease: 1, RateIncreaseIntervalMs: 1000, TimeIntervalMs: 1000 }
  # - Count: { Count: 10 }
  # - Timeout: { TimeoutMs: 30000 }
```

## Serializers / Deserializers (FB s02 §2.8)

Types: Binary, Json, MessagePack, Xml, Yaml, ProtobufMessage, XmlElement.
`SpecificType`: `TypeFullName` (req), `AssemblyName` (opt, default = entry assembly).

```yaml
# On Publisher:
Serialize: { Serializer: Json }

# On Consumer:
Deserialize: { Deserializer: Json, SpecificType: { TypeFullName: MyApp.MyDto } }

# On Transaction:
InputSerialize: { Serializer: Json }
OutputDeserialize: { Deserializer: Json }
```
