# B01 — static-health-hello (mocker-yaml)

**Complex system simulated:** A platform team's standard *service mock* contract: every mock must
expose `/health` (liveness) and a business route (`/hello`). This is the canonical first mocker
every QaaS user builds.

**Weak-model job:** scaffold the mocker project and author `*.mocker.yaml` with two endpoints —
`StaticResponseProcessor` on `/health` (static 200 / `OK`) and `StaticResponseProcessor` on
`/hello` (200 / `hello`). Live gate boots the mocker on port **8091** and curls both routes.

- Category: mocker-yaml
- Infra: none (local process, port 8091)
- Live gates: build exit 0, template exit 0, boot + `curl /health` = 200 + `curl /hello` body match
- Traps tested: FB s13#1 (ProcessorConfiguration), s13#5 (mocker Path keeps slash), s14.2 shape
