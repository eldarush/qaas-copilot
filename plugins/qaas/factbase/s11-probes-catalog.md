> SNAPSHOT at Runner 4.5.1 / Mocker 2.4.1 — fetch live docs first (see FB s16); verify against your docs when reachable.

## 11. CATALOG — Probes (pkg `QaaS.Common.Probes`; src 06; 41 documented — docs prose says "43" but only 41 have doc pages)
Attach: `Sessions[].Probes[]` with Name, Probe(type), ProbeConfiguration(dict), Stage(3),
DataSourceNames/Patterns. Per-probe required fields vary; full schema `docs/_generated/schemas/
probes.md`.
- **RabbitMQ:** CreateRabbitMqBindings, DeleteRabbitMqBindings, CreateRabbitMqExchanges,
  DeleteRabbitMqExchanges, CreateRabbitMqQueues, DeleteRabbitMqQueues, PurgeRabbitMqQueues,
  CreateRabbitMqUsers, DeleteRabbitMqUsers, CreateRabbitMqVirtualHosts, DeleteRabbitMqVirtualHosts,
  DownloadRabbitMqDefinitions, UploadRabbitMqDefinitions, DeleteRabbitMqPermissions,
  UpsertRabbitMqPermissions.
- **Redis:** ExecuteRedisCommand, ExecuteRedisCommands, EmptyRedisByChunks, FlushAllRedis,
  FlushDbRedis.
- **Databases:** DeleteElasticIndices, EmptyElasticIndices, DropMongoDbCollection,
  EmptyMongoDbCollection, CreateS3Bucket, DeleteS3Bucket, EmptyS3Bucket, MsSqlDataBaseTablesTruncate,
  OracleSqlDataBaseTablesTruncate, PostgreSqlDataBaseTablesTruncate.
- **Cluster (OpenShift/K8s):** OsEditYamlConfigMap, OsChangeDeploymentEnvVars,
  OsChangeStatefulSetEnvVars, OsUpdateDeploymentImage, OsUpdateStatefulSetImage,
  OsExecuteCommandsInContainers, OsRestartPods, OsUpdateDeploymentResources,
  OsUpdateStatefulSetResources, OsScaleDeploymentPods, OsScaleStatefulSetPods.
(Common idiom: a readiness/setup probe at an early stage before transactions; e.g. PingProbe at
stage 0 to wait for the mocker. 01)

### 11.1 Rabbit topology setup (declare exchanges/queues BEFORE publish/consume)
A RabbitMQ Publisher/Consumer does NOT create missing topology. If the exchange (or queue)
does not already exist in the broker, the action fails at connect time with
`NOT_FOUND - no exchange '<name>' in vhost '/'` (AMQP classId=40) or the consumer's
`queue.bind` fails (classId=50) — Session ends Outputs=0, Failures>0, `ExitCode=1`.
Fix: add a `CreateRabbitMqExchanges` (and/or `CreateRabbitMqQueues`) **setup probe at Stage 0**,
BEFORE the publisher/consumer actions, so the test owns its topology and does not depend on the
SUT/broker pre-creating it. Schema (docs `_generated/schemas/probes.md` §CreateRabbitMqExchanges):
**⚠ Using ANY probe REQUIRES the `QaaS.Common.Probes` PackageReference in the Runner `.csproj`
(FB s13#8).** It is commented out in the default scaffold — if you scaffolded without it (T-001) and
then add a probe here, you MUST go back and add `<PackageReference Include="QaaS.Common.Probes"
Version="1.5.1" />`, or the run crashes at hook resolution with Autofac `exit -532462766` (NOT a YAML
error). Look-ahead: if the plan mentions any probe, scaffold WITH `QaaS.Common.Probes` from the start. Schema (docs `_generated/schemas/probes.md` §CreateRabbitMqExchanges):
`ProbeConfiguration` = Host(**req**), Port, Username, Password, VirtualHost, Exchanges(**req** list).
Each Exchanges item: Name(**req**), Type, Durable, AutoDelete, Arguments. Worked example:
```yaml
Sessions:
  - Name: OrderSession
    Probes:
      - Name: DeclareTopology
        Probe: CreateRabbitMqExchanges
        Stage: 0
        ProbeConfiguration:
          Host: 127.0.0.1
          Port: 5672
          Username: admin
          Password: admin
          Exchanges:
            - { Name: orders-input,  Type: direct, Durable: false }
            - { Name: orders-output, Type: direct, Durable: false }
    Actions:
      # Stage 1+ publishers/consumers now connect to topology that already exists
```
`CreateRabbitMqQueues` mirrors this: Queues(**req**) list, item = Name(**req**), Exclusive(**req**),
Durable, AutoDelete, Arguments. `CreateRabbitMqBindings` wires exchange→queue. Teardown counterparts:
`DeleteRabbitMqExchanges`/`DeleteRabbitMqQueues`/`PurgeRabbitMqQueues`. (src 06; verified probes.md)

---

