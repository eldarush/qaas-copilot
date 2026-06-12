# B05 â€” sequence-processor-flaky (mocker-yaml)

**Complex system simulated:** Flaky upstream: SequenceProcessor 200,200,500 cycle.
Validates the mocker server configuration, routing, and stub swappability of QaaS mockers.

- Category: mocker-yaml
- Infra: None
- Live gates: dotnet build exit 0, template exit 0, curl verify exit 0
- Traps tested: FB s13 citations
