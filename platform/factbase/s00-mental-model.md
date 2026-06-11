## 0. Mental model

- **QaaS** = .NET 10 ecosystem for integration/E2E testing of backends. Tests defined in YAML
  (or C# "Configuration as Code"), extended via C# hooks, validated by Assertions, reported to
  Allure. (docs/qaas/index.md, docs/qaas/architecture.md)
- **QaaS.Runner** — execution engine: loads config, runs Sessions (Publishers/Consumers/
  Transactions/Collectors/Probes/MockerCommands), evaluates Assertions, writes `allure-results/`.
- **QaaS.Mocker** — configurable HTTP/gRPC/Socket mock servers (Stubs+Processors), optional
  Redis Controller for runtime control from Runner.
- **Hooks** (4 custom C# base classes): Generator, Assertion, Probe (runner) + TransactionProcessor
  (mocker). Discovered by **assembly scanning**, referenced in YAML by **simple class name**. [LAB]
- **Evidence model** (docs/qaas/quickStart/actionSelectionPlaybook.md): every action writes named
  `Inputs`/`Outputs` into SessionData; assertions read those by name. **One action name = one proof
  point; assertion `OutputName(s)`/`InputName(s)` must match the action `Name` exactly.**

---

