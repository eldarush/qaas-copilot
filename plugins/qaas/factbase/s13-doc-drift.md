## 13. DOC-DRIFT TABLE — critical traps (LAB-verified) [LAB L3/L5]
The mirrored quickstart `helloWorldHttp.md` and some config pages are **outdated vs the real
4.5.1/2.4.1 packages**. The `template` verb is the authoritative schema oracle. When in doubt, run
`dotnet run -- template <config>` and trust its output.

| # | Topic | Docs say (WRONG) | Reality (USE THIS) |
|---|---|---|---|
| 1 | Mocker stub config key | `TransactionData:` | **`ProcessorConfiguration:`** (else `Property TransactionData ... not found in TransactionStubConfig`) |
| 2 | Runner Storages shape | `- Name:.. StorageConfiguration:{Type:Local,Path:..}` / `StorageType:FileSystem` | **`- FileSystem: {Path: ./session-data}`** (opt Configuration/JsonStorageFormat/S3) |
| 3 | Transactions data | implies optional | **DataSourceNames or DataSourcePatterns REQUIRED** |
| 4 | HttpStatus assertion | `ExpectedStatus:` + `OutputName:` | **`StatusCode:` + `OutputNames:` (list)** |
| 5 | HTTP Route | `Route: /hello` | **`Route: hello`** (leading `/` → `//hello` → 404) |
| 5b | HTTP Route **case** | docs show mixed-case routes e.g. `Route: testRoute` | **routes must be ALL-LOWERCASE end-to-end.** The mocker lowercases the endpoint `Path` (`FixedPath = Path.ToLowerInvariant()`) then builds a **case-sensitive** regex `^/testroute$` (no `IgnoreCase`). The runner sends `Route:` verbatim, so `Route: testRoute` → `GET /testRoute` → no match → **404** → `HttpStatus` fails. Use lowercase on BOTH the mocker `Path:` and runner `Route:`. [SOURCE-verified D02] |
| 6 | Missing output | — | assertion status **broken**, "Value cannot be null. (Parameter 'source')" |
| 7 | Mocker Dockerfile base | scaffold ships `mcr.microsoft.com/dotnet/runtime:10.0` | **`mcr.microsoft.com/dotnet/aspnet:10.0`** (mocker hosts HTTP; runtime image fails at start) |
| 8 | Built-in hooks "just work" | implied | built-in families need explicit package refs: Generators→`QaaS.Common.Generators`, Assertions→`QaaS.Common.Assertions`, Processors(mocker)→`QaaS.Common.Processors`; missing→FTL + exit -532462766 |
| 9 | Versions (INDEPENDENT per package) | "2.0.0" everywhere / implies a uniform version | real, LAB-verified, mutually-compatible set on .NET 10.0.203: **Runner `4.5.1`, Mocker `2.4.1`, Common.Assertions `3.5.1`, Common.Generators `3.5.1`, Common.Probes `1.5.1`, Common.Processors `1.5.1`**. They do NOT share a version — putting Runner's `4.5.1` on a `QaaS.Common.*` ref gives `error NU1102: Unable to find package ... (>= 4.5.1)`. Add a `QaaS.Common.*` ref only when that family's built-in hooks are used. |
| 10 | `Reporters:` block | debugTestFailure.md shows top-level AllureReporter block | not LAB-verified; use per-assertion `Save*`/`DisplayTrace` flags |
| 11 | Controller boot log | docs claim `Controller channel ready: HelloMocker` | real logs: `Initialized Redis controller for server 'X' with instance id '...'` + `Started control handler 'CommandHandler' ... 'runner-to-mocker:command:x:<instanceid>'` [LAB L6] |
| 12 | AssertionConfiguration typos | — | unknown keys are **silently ignored** (no validation inside hook configs); only catalog yamlView pages / `template` dump are trustworthy [LAB L7] |
| 13 | HttpStatus with zero outputs | — | **passes vacuously** ("All configured outputs arrived with status 200"); transactions that can't connect log `Output Source X Contains 0 Outputs` but DON'T fail the run; always add a hermetic-count guard [LAB L7] |
| 14 | Verify `cmd` starting with `#` | — | verify steps execute via PowerShell `-Command "<cmd>"`; a leading `#` **comments out the whole single-line string** → instant exit 0 (vacuous pass). Never begin a verify cmd with `#`; keep intent in `description`. |
| 15 | Live-run split across two verify entries | — | two separate `verify[]` entries do **not** share a background process; if step 1 starts the mocker and step 2 runs the runner, the mocker is already gone → runner connects to nothing. Start mocker (background) + wait-for-port + run runner + capture `$LASTEXITCODE` + stop mocker, all in **ONE** cmd. |
| 16 | Inconsistent port across probe/mocker/runner (PORT CONTRACT) | — | the live-gate TCP probe port, the mocker `Servers.Http.Port`, and the runner Transaction `Http.Port` must be **one single literal**. A probe on a port the mocker never binds loops the full wait then prints `MOCKER NEVER READY` and `exit 9`; the runner never executes and `ExitCode=0` is absent. Pick the port once and reuse it verbatim in all three places; never invent a second port for the probe. (Do not write the port as a `#` comment inside the cmd — that trips #14.) |
| 17 | RabbitMQ exchange/queue must pre-exist | docs show Publisher/Consumer YAML with no topology-setup step | a Publi
sher/Consumer **does not create missing topology**. If the exchange/queue is absent, connect fails with `NOT_FOUND - no 
exchange '<name>' in vhost '/'` (AMQP classId=40) or `queue.bind` fails (classId=50) → Outputs=0, `ExitCode=1`. Add a `C
reateRabbitMqExchanges` (and/or `CreateRabbitMqQueues`) **setup probe at Stage 0** so the test owns its topology; see FB
s11 §11.1 for the docs-verified config shape. (Alternatively the SUT/seed must declare the topology before the runner c
onnects.) |
| 18 | Dockerfile inline comments on instruction lines | docs/skill show comments on their OWN line | Docker does **NOT** allow a trailing comment on an instruction line. `FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build  # note` → `dockerfile parse error ... FROM requires either one or three arguments` (the `# note` is parsed as extra FROM arguments). Comments MUST sit on their own line starting with `#`; never append one after FROM/COPY/RUN/ENTRYPOINT. [trial E02 iter1] |
| 19 | Compose publishes an internal dependency's port | a naive compose maps `redis: ports ["6379:6379"]` | **Publish ONLY the service you curl from the host (the mocker).** Mapping an internal dependency (Redis/RabbitMQ) to a fixed host port collides with any container already bound to it on the host: `docker compose up` aborts with `Bind for 0.0.0.0:6379 failed: port is already allocated` → the mocker container never starts → the curl gate fails. Inside a compose network, services reach each other by **service name** (`redis:6379`), so internal deps need NO host port mapping. [trial E03] |

---

