# P131 -- schema-evolution-v1v2 (rabbit ETL contract)

**Complex system simulated:** A schema-evolution ETL gateway consuming a mixed stream of V1 and V2
records from RabbitMQ, normalizing them to a unified output shape. V1 records carry
`{"schemaVersion":1,"name":"<n>"}` and must be migrated (rename `name` to `fullName`, add
`"migrated":true`). V2 records carry `{"schemaVersion":2,"fullName":"<n>"}` and pass through
with `"migrated":false`. All outputs must have a `fullName` field regardless of input version.

**Weak-model job:** author six interleaved data source files (3 V1 + 3 V2), a custom
`BaseAssertion<SchemaEvolutionConfig>` that verifies `fullName` presence and correct `migrated`
flag counts, runner YAML wiring a Publisher + Consumer with a hermetic count guard, and a seeded
`transform-relay.ps1` SUT that performs the V1->V2 normalization over RabbitMQ.

- Category: rabbit ETL (Publisher/Consumer, custom assertion, seeded relay SUT)
- Infra: RabbitMQ broker (127.0.0.1:5672 admin/admin); transform-relay.ps1 seeded into artifacts/
- Live gates: build exit 0, template exit 0, e2e run with relay exit 0
- Traps tested: s13#3 (DataSourceNames plural required for Publisher), s13#6 (Consumer TimeoutMs
  required), s13#11 (exact YAML key names), s13#12 (HermeticByExpectedOutputCount -- Consumer
  vacuously passes on zero outputs), s13#17 (exchange topology must match relay names exactly),
  s04 (BaseAssertion config [Required] nullable props, Configuration=null ctor),
  NoConfiguration->object trap (use typed config record instead).
