# Z101 - multi-protocol-choreography

**Complex system simulated:** Multi-protocol order pipeline where an HTTP POST ingress triggers a
RabbitMQ publish, a relay bridges the message to an output exchange, a consumer reads it, and a
final HTTP GET egress returns the aggregated status — all exercised in one QaaS runner suite.

- Category: multi-protocol (HTTP + RabbitMQ + relay)
- Infra: RabbitMQ + Redis (via infra.json needs)
- Live gates: mocker process (2 servers 8271 + 8272), relay.ps1 bridge (z101-input -> z101-output),
  runner exits 0 with ExitCode=0
- Traps tested: s13#3 DataSourceNames required on Publisher, s13#4 HttpStatus keys, s13#5b lowercase
  routes no leading slash, s13#12 vacuous HttpStatus pass, s13#13 Consumer TimeoutMs required
