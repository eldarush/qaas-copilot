# Q134 - dlq-cascade (runner-yaml / messaging)

**System simulated:** Three-level RabbitMQ dead-letter-exchange cascade where a published
message traverses two TTL expiry hops before landing in a final consumer queue; the original
body is asserted unchanged at the end of the chain.

- **Category:** runner-yaml (RabbitMQ Consumer/Publisher)
- **Infra:** RabbitMQ broker (Docker); topology pre-created by seed/topology.ps1
- **Live gates:** dotnet build exit 0, template exit 0, e2e run exit 0
- **Traps tested:**
  - FB s13 #12 (trap 11 in queue args): x-dead-letter-exchange and x-message-ttl keys must
    be spelled character-exact in RabbitMQ queue arguments; a typo is silently ignored,
    causing the cascade to never fire (messages stay in the source queue indefinitely).
  - FB s13 #13 (vacuous pass): If InitialTimeoutMs on the DLQ2 Consumer is shorter than the
    total cascade time (TTL1+TTL2+routing), zero outputs arrive and HermeticByExpectedOutputCount
    passes vacuously. Set InitialTimeoutMs to at least 3000ms when TTL per hop is 500ms.
  - FB s13 #3: DataSourceNames is required on the Publisher Transaction; omitting it causes
    the publisher to emit zero messages silently.
  - Consumer requires TimeoutMs in addition to InitialTimeoutMs; omitting TimeoutMs causes
    a validation error at runner startup.
