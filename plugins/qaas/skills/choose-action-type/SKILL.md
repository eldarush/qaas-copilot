---
name: choose-action-type
version: 1.0.0
description: Maps a testing intent to the correct QaaS session action type (Publisher/Consumer/Transaction/Collector/Probe/MockerCommands).
when_to_use: Before authoring a Sessions block; uncertain which action type to use for a given intent.
inputs:
  - intent: what the test needs to do (e.g. "send a message to RabbitMQ", "call REST API and check 200")
outputs:
  - action_type: one of Publisher/Consumer/Transaction/Collector/Probe/MockerCommands
  - protocol: specific protocol under that type
  - evidence_note: which SessionData field is populated (Input/Output/none)
fact_base_slices: [s02, s13]
references: []
contract:
  done_rubric:
    - 'Choice names the exact row used from the decision table below'
    - 'Protocol is one of the supported protocols for that action type'
    - 'evidence_note identifies whether action creates Input, Output, both, or none'
  failure_modes:
    - 'Using Consumer to produce a message (wrong direction)'
    - 'Using Transaction without DataSourceNames -> validation error (FB s13#3)'
    - 'Omitting hermetic guard with HttpStatus -> vacuous pass (FB s13#13)'
  escalation: 'NEEDS_CLARIFICATION: intent is ambiguous between Producer and Transaction'
---

## When to use

Call this skill before writing any `Sessions[]` entry. Map the intent to one row in the table
below, then cite that row in your output.

## Steps

### 1. Match intent to action type (FB s02 §2.6)

| Intent | Action type | SessionData created | Notes |
|---|---|---|---|
| **Send / produce** a message to a broker, table, bucket | **Publisher** | Input named after publisher | DataSourceNames provides the payload |
| **Receive / verify output** from broker, table, bucket, queue | **Consumer** | Output named after consumer | TimeoutMs REQUIRED |
| **Call an API and check response** (HTTP or gRPC request/response) | **Transaction** | Input + Output named after transaction | DataSourceNames REQUIRED (FB s13#3) |
| **Scrape metrics** over a time window | **Collector** (Prometheus) | Output named after collector | Protocol: Prometheus only |
| **Setup / teardown / wait-for-ready** infra (create queue, flush DB, ping endpoint) | **Probe** | none | 41 documented probes (FB s11) |
| **Change mocker behavior mid-test** at runtime | **MockerCommands** | none (Consume variant creates Input+Output) | Requires mocker Controller + Redis (FB s02) |

### 2. Protocol matrix per action type (FB s02 §2.6)

#### Publisher — 11 protocols

| Protocol | Key config fields |
|---|---|
| RabbitMq | Host, Port(5672), Username, Password, ExchangeName, QueueName, RoutingKey("/") |
| KafkaTopic | (see docs) |
| Redis | (see docs) |
| MsSqlTable | (see docs) |
| PostgreSqlTable | (see docs) |
| OracleSqlTable | (see docs) |
| MongoDbCollection | (see docs) |
| ElasticIndex | (see docs) |
| S3Bucket | (see docs) |
| Socket | (see docs) |
| Sftp | (see docs) |

#### Consumer — 10 protocols

RabbitMq, KafkaTopic, MsSqlTable, PostgreSqlTable, OracleSqlTable, TrinoSqlTable,
ElasticIndices, S3Bucket, Socket, IbmMqQueue.

TimeoutMs (ms since last message) REQUIRED; set higher than expected async processing time.

#### Transaction — 2 protocols

| Protocol | Key config fields |
|---|---|
| Http | BaseAddress(req), Method(req), Port(8080), Route("" — NO leading slash FB s13#5), Headers, Retries(1), JwtAuth{...} |
| Grpc | Host, Port, AssemblyName, ProtoNameSpace, ServiceName, RpcName (all req) |

**DataSourceNames or DataSourcePatterns REQUIRED** (FB s13#3 — validation error otherwise).

#### Collector — 1 protocol

Prometheus: `Url` (req base), `Expression` (req query_range), `SampleIntervalMs`(30000),
`TimeoutMs`(120000), `ApiKey`.

#### Probe — 43 implementations (FB s11)

Selected useful probes by category:
- **RabbitMQ**: CreateRabbitMqQueues, PurgeRabbitMqQueues, DeleteRabbitMqQueues, CreateRabbitMqExchanges
- **Redis**: ExecuteRedisCommand, FlushDbRedis, EmptyRedisByChunks
- **Databases**: MsSqlDataBaseTablesTruncate, PostgreSqlDataBaseTablesTruncate, DropMongoDbCollection
- **Cluster**: OsRestartPods, OsScaleDeploymentPods, OsChangeDeploymentEnvVars

Package: `QaaS.Common.Probes` (FB s13#8). Probes are synchronous — no Task.Run (CONSTITUTION V).

#### MockerCommands — Commands

- `ChangeActionStub: {ActionName, StubName}` — swap stub at runtime
- `TriggerAction: {ActionName, TimeoutMs}` — trigger mocker action
- `Consume: {TimeoutMs(req), ActionName}` — drain mock queue (destructive)

Requires mocker `Controller: {ServerName, Redis: {Host: host:port}}` (FB s02 §2.6, LAB L6).
If Redis unreachable → silently times out, no error (FB s02).

### 3. Evidence wiring rule (FB s00)

Each action writes named `Inputs`/`Outputs` into `SessionData`. Assertion `OutputNames`/
`InputNames` **must match the action `Name` exactly** (FB s00).

```
Publisher "Pub1"   → SessionData.Inputs["Pub1"]
Consumer "Con1"    → SessionData.Outputs["Con1"]
Transaction "Tx1"  → SessionData.Inputs["Tx1"] + SessionData.Outputs["Tx1"]
```

### 4. Hermetic guard requirement (CONSTITUTION VII, FB s13#13)

Every session with an `HttpStatus` or content assertion MUST also include:
- `HermeticByExpectedOutputCount` (exact count), OR
- `HermeticByInputOutputPercentage` (ratio guard)

HttpStatus passes **vacuously** when zero outputs arrive (false green, LAB L7).

## Citations

- FB s02 §2.6 (action type field lists, protocols, default stages)
- FB s00 (evidence model: action Name → SessionData Input/Output)
- FB s11 (41 documented probes catalog)
- FB s13#3 (Transaction DataSourceNames required)
- FB s13#5 (Route no leading slash)
- FB s13#13 (HttpStatus vacuous pass)
- CONSTITUTION VII (hermetic guard)

## Traps

- **Consumer ≠ Producer** — Consumer reads FROM a broker; Publisher writes TO a broker
- **Transaction without DataSourceNames** → `FTL Runner execution configuration is invalid` exit 1 (FB s13#3)
- **MockerCommands silently time out** if Controller/Redis not configured (FB s02)
- **HttpStatus vacuous pass** with 0 outputs — always pair with hermetic guard (FB s13#13)
