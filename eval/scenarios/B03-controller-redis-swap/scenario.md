# B03 â€” controller-redis-swap (mocker-yaml)

**Complex system simulated:** Controller-enabled mocker: ServerName+Redis, swappable stubs.
Validates the mocker server configuration, routing, and stub swappability of QaaS mockers.

- Category: mocker-yaml
- Infra: Redis container
- Live gates: dotnet build exit 0, template exit 0, curl verify exit 0
- Traps tested: FB s13 citations
