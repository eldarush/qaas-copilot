# A01 — http-payment-status (runner-yaml)

**Complex system simulated:** A payment service provider's *payment-status* API. Merchants poll
`GET /payments/status` and the platform must verify the upstream PSP responds 200 with a body,
hermetically (every request produces exactly one response — no silent drops).

**Weak-model job:** scaffold runner+mocker projects, author the runner YAML (datasource,
transaction, assertions w/ vacuous-pass guard) and the mocker YAML (static stub), then produce a
run report. The harness live-gates everything with real `dotnet build` / `template` / end-to-end runs.

- Category: runner-yaml
- Infra: none beyond dotnet + nuget feed (mocker runs as a local process on port **8090**)
- Live gates: build exit 0 ×2, template exit 0 + no unknown-property warnings, e2e run exit 0 + `ExitCode=0`
- Traps tested: FB s13#1 (ProcessorConfiguration), #3 (DataSourceNames), #5 (Route slash),
  #12 (ExpectedCount), #13 (vacuous pass guard)
