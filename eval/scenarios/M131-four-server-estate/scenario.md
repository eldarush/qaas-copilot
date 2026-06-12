# M131 - four-server-estate (mocker-yaml + runner-yaml)

**Complex system simulated:** E-commerce microservices estate: auth, catalog, cart, and checkout
services owned by separate teams; no shared integration environment exists.

- Category: mocker-yaml + runner-yaml
- Infra: Redis container (for mocker controller)
- Live gates: dotnet build exit 0, template exit 0, mocker start + curl 4 ports, runner session exit 0
- Traps tested: FB s13#1 ProcessorConfiguration not TransactionData, s13#5b all routes lowercase x4,
  s13#11 Controller.ServerName byte-for-byte match, s13#12 vacuous HttpStatus, s13#16 PORT CONTRACT x4
