# C05 — generator-sequential-ids (hooks)

**Complex system simulated:** an order ingestion test whose request payloads are produced by a
custom data generator (deterministic sequential ids) rather than a static file, exercised end-to-end
against a live mocker.

- Category: hooks (custom runner `IGenerator`)
- Infra: None (the mocker runs as a local dotnet process; no docker/broker)
- Live gates: `dotnet build` exit 0 (runner + mocker), `template` exit 0 (both YAMLs),
  end-to-end `run` exit 0 (3 generated POSTs → live mocker on :8112 → all HTTP 200, hermetic count satisfied)
- Capability proven: authoring a custom `BaseGenerator<TConfig>` (runner-side hook) AND wiring it into a
  runnable session that actually consumes its output over HTTP — a custom generator cannot be proven
  without a consumer, so this pairs it with a mocker target.
- Traps tested: generator-only Transaction with no protocol block → `Missing supported type in transaction`
  (FB s13), vacuous `HttpStatus` without a hermetic count guard (CONSTITUTION art. 7),
  `SessionData` vs `Data<T>` namespace split (FB s04, s14), leading-slash route (FB s13#5).
