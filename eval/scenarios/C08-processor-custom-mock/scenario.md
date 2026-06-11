# C08 — processor-custom-mock (hooks)

**Complex system simulated:** a custom mocker `TransactionProcessor` that produces bespoke HTTP
response logic, wired into a mocker stub and proven by a live request.

- Category: hooks (custom mocker processor)
- Infra: None (the mocker runs as a local dotnet process; no docker/broker)
- Live gates: `dotnet build` exit 0 (mocker), `template` exit 0, live mocker returns `STATUS=200` + `CUSTOM-OK` at `/status` on port 8111
- Capability proven: authoring + wiring a custom `BaseTransactionProcessor<T>` (the mocker-side hook),
  including the correct base-class namespace (`QaaS.Framework.SDK.Hooks.Processor`) and response
  types (`QaaS.Framework.SDK.Session.MetaDataObjects`), in a project that references `QaaS.Mocker`.
- Traps tested: processor namespace/project (FB s04, s14#5), leading-slash/route-case (FB s13#5/#5b),
  missing processor package (FB s13#8).
