# C02 — assertion-body-length (hooks)

**Complex system simulated:** A telemetry ingestion pipeline. Devices publish *batches* (JSON
arrays) of exactly 5 readings to RabbitMQ; a relay service forwards them; the QA platform must
verify every consumed batch still contains exactly 5 items — a rule no built-in assertion covers,
so the team writes **custom hooks**.

**Weak-model job:** author three custom C# hooks (IGenerator producing JSON arrays,
IAssertion validating array length with attachment evidence, IProbe printing stage time), the
csproj that hosts them, and the runner YAML wiring them by class name. Live-gated against a real
RabbitMQ broker with the relay running.

- Category: hooks
- Infra: rabbit (+ relay started inside the live-gate verify step; relay.ps1 is seeded into artifacts/)
- Live gates: build exit 0, template exit 0, e2e run exit 0 with relay
- Traps tested: FB s13#8 (hook discovery via project refs), s04 (BaseAssertion/BaseGenerator API),
  config records nullable+[Required]
