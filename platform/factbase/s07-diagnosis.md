## 7. TASK: Artifacts & diagnosis

### allure-results/ layout ([LAB] L2, 02, 05)
```
allure-results/
├── *-result.json              # one per assertion: uuid=name, status passed|failed|broken,
│                              #   statusDetails.message/trace, description = YAML of assertion config
├── SessionsData/<ts>/<session>.json   # Inputs[]/Outputs[]; Data[].Timestamp/Body(base64)/MetaData(incl Http.StatusCode)
├── SessionLogs/<ts>/<session>.log
├── Templates/<ts>/template.yaml
├── AssertionsAttachments/     # custom AssertionAttachments
└── Coverages/
```
- Case runs sanitize names (`/ \` → `_`) into subfolders. SessionsData naming:
  `SessionsData/{Session}.json` | `.../{Execution}/{Session}.json` | `.../{Case}_{Session}.json`.
- Allure suites: ParentSuite=ExecutionId, Suite=CaseName; Behaviours Epic=SessionNames,
  Feature=assertion type; Package=C# project name. Flaky = passed-but-untrustworthy (a non-assertion
  action failed). (02)
- Serve: `allure serve` (needs Allure CLI) or `-s`.

### Diagnosis triage (docs debugTestFailure.md)
1. `template` the config (placeholders/schema OK?). 2. Did publishers fire? (else probe/pre-step).
3. Did consumers receive? (channel naming / SUT not consuming). 4. Did assertion run? (config
validation → `AssertionTrace`). 5. Split real vs spurious with `act`+`assert`.
| act vs assert | Meaning |
|---|---|
| act fails, assert would pass | infra problem (broker/SUT/mocker) |
| act ok, assert fails | assertion or its config wrong |
| both ok, run fails | order-of-operations bug |

### Error-signature table (symptom → cause → fix) — [LAB] unless noted
| Symptom | Cause | Fix |
|---|---|---|
| `FTL ... I<X> hook instance <N> not found in any of the provided assemblies` then exit -532462766 | hook family/assembly not referenced | add the QaaS.Common.* package or the project asm [LAB] |
| `FTL Runner execution configuration is invalid` + `Sessions:0:Transactions:0: ...` | schema validation; missing required field | fix YAML per path; `Transactions` need DataSourceNames/Patterns [LAB] |
| `Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object` | used `TransactionData` in mocker stub | use `ProcessorConfiguration` [LAB] |
| assertion `broken`: "Value cannot be null. (Parameter 'source')" | the named Output is entirely missing | fix Route/stub so output exists; check OutputNames match [LAB L3#6] |
| HTTP 404 from mocker | `Route:/x` → `//x` double slash → DefaultNotFound | `Route: x` (no leading slash) [LAB L3#5] |
| DelayByChunks `failed`: "No output items were found in the output Consumer..." | consumer received nothing (SUT/relay down, timeout too short) | start SUT; raise TimeoutMs [LAB L1] |
| Hermetic% = 0, failed | no outputs vs inputs | same as above |
| "config file not found" on `dotnet run` | yaml not copied to output | `<CopyToOutputDirectory>PreserveNewest` (docs) |
| container start: "Framework 'Microsoft.AspNetCore.App' ... No frameworks were found." | mocker on `dotnet/runtime` image | use `dotnet/aspnet:10.0` base [LAB L5] |
| publishers fire, consumers timeout | channel/exchange name mismatch | match mocker's logged channel name (docs) |
| `RabbitMq.Host:127.0.0.1` in container | resolves to container itself | `host.docker.internal` / docker network (docs) |
| flaky with `ExpectedPercentage:100` | at-least-once delivery | use `>=95` or dedupe consumer (docs) |
| MockerCommands time out, no error | Redis unreachable / Controller.ServerName unset | configure Controller + matching ServerName (r07) |
| `CouldNotFindConfigurationException: YAML configuration file was not found. Resolved local path: <cwd>\x.yaml` | config path resolves against CWD, not project dir | `cd` into the project folder before `dotnet run -- run x.yaml` [LAB L6] |
| HttpStatus PASSES but no traffic happened (exit 0) | **vacuous pass**: 0 outputs → "All configured outputs arrived with status 200" | ALWAYS pair HttpStatus with HermeticByExpectedOutputCount/`...Percentage` guard [LAB L7] |
| assertion fails w/ confusing msg, e.g. "Sum of outputs X count is 1, expected" | unknown config key SILENTLY IGNORED (e.g. `ExpectedOutputCount` vs real `ExpectedCount`) | copy field names EXACTLY from the hook's yamlView catalog page [LAB L7] |

### Reporter flags (docs debugTestFailure.md — **doc-only, not LAB-verified**, see §13)
Doc shows a `Reporters: [{Reporter: AllureReporter, ReporterConfiguration:{SaveSessionData,
SaveAttachments, DisplayTrace}}]` block storing `request-<i>.bin`/`response-<i>.bin`/
`assertion-trace.txt`. LAB observed save flags on the **assertion** entry instead (§2.9). Prefer the
per-assertion `Save*`/`DisplayTrace` flags; treat a top-level `Reporters:` block as unverified.

---

