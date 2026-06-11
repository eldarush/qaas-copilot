---
name: plan-test-sprint
version: 1.0.0
description: Decompose a user testing goal into a validated sprint.json with priority-ordered, mechanically-verifiable tasks.
when_to_use: User describes a system to test (e.g. "test service X consuming from RabbitMQ exchange A and calling REST API B"); produce sprint.json for the harness loop.
inputs:
  - user_goal: one-sentence description of what must be tested
  - protocols: list of protocols involved (HTTP, RabbitMQ, Kafka, etc.)
outputs:
  - sprint.json
fact_base_slices: [s00, s01, s02, s06, s09, s10, s13, s14]
references: []
contract:
  done_rubric:
    - 'Every task has verify[] with >=1 entry containing expectExitCode or expectOutputContains'
    - 'Priority N task depends only on tasks with priority < N'
    - 'goalOneSentence is exactly one sentence'
    - 'Canonical dep order obeyed: scaffold(1) -> yaml(2) -> run/verify(3)'
  failure_modes:
    - 'Task description is a file reference, not self-contained text (PROTOCOL §3)'
    - 'verify[] entries missing expectExitCode AND expectOutputContains — harness cannot gate'
    - 'Priority inversion: T-003 at priority 2 depends on T-004 at priority 3'
    - 'goalOneSentence is multiple sentences'
    - 'failureModes do not cite FB s13 rows'
  escalation: 'NEEDS_CLARIFICATION: protocol list unknown | BLOCKED: goal spans >5 files per task'
---

## When to use

Call this skill when a user provides a testing goal and you must produce a `sprint.json` for
`loop.ps1`. This skill **only plans** — no code/YAML is written here.
Emit `NEEDS_CLARIFICATION: goal is ambiguous` if the goal cannot be stated in one sentence.

## Steps

### 1. State the goal in one sentence

Record as `goalOneSentence`. If multi-part, pick the primary outcome; put rest in `nonGoals`.
Extract: (a) system-under-test, (b) protocol(s), (c) observable outcomes.

### 2. Map protocols → session types (FB s02)

| Protocol / intent | Session type | Skill |
|---|---|---|
| HTTP call to SUT or mocker | Transaction (Http) | author-runner-yaml |
| Produce to message broker | Publisher | author-runner-yaml |
| Consume from broker/table | Consumer | author-runner-yaml |
| Verify HTTP response status | Assertion: HttpStatus + hermetic guard | author-runner-yaml |
| Setup/teardown infra (queues, buckets) | Probe | author-runner-yaml |
| Change mocker stub at runtime | MockerCommands | author-runner-yaml |
| Mock HTTP/gRPC server needed | Mocker YAML | author-mocker-yaml |

### 3. Canonical dependency order (PROTOCOL §3, AGGREGATE §3)

Assign priorities strictly in this order — never invert:
1. **Scaffold** — runner csproj + mocker csproj
2. **Author custom hooks** (only if needed — see 3b) — `.cs` classes the YAML will reference
3. **Author YAML** — runner YAML + mocker YAML
4. **Run/Verify** — end-to-end `dotnet run -- run`

Same-priority tasks may run in parallel (identical priority number, distinct id).

### 3b. Custom hooks need an authoring task (orphan check)

Only these names are **built-in** (no class to write — just reference them):
- Generators (s10), Assertions (s09), Processors (s12: `StaticResponseProcessor`,
  `StatusCodeTransactionProcessor`, `RequestEchoProcessor`, `PassThroughProcessor`,
  `JsonEnvelopeProcessor`, `TextTransformProcessor`, `ConditionalResponseProcessor`,
  `DataSourceResponseProcessor`, `ProblemDetailsProcessor`), Probes (s11).

If your YAML references **any other** hook name (e.g. `HealthProcessor`, `MyAssertion`), it is a
**custom hook** — you MUST add an `author-custom-hook` task at priority 2 that creates the `.cs`
class, before the YAML task that references it. A YAML that names a hook with no class to back it
**DI-crashes at run with exit `-532462766`** (FB s13#8). When a built-in already does the job (a
health check is just a static 200 → `StaticResponseProcessor`), prefer the built-in and write NO
custom class. Never reference a hook name that no task creates and that isn't in the catalogs above.

### 4. Author each task object (PROTOCOL §3)

Every task MUST have:
- `id`, `title` (gerund, ≤8 words), `priority`, `dependsOn`, `skill`, `files.create/edit`
- `description`: **fully self-contained** — generator sees nothing else. Include: what fields to
  set, trap avoidance with FB s13#N citations, exact config key names.
- `files.create`/`files.edit`: list **only the files THAT task produces** (e.g. the scaffold task
  creates the csprojs; the YAML task creates the `.qaas.yaml`/`.mocker.yaml`; the run task creates
  nothing). NEVER set every task's `files.create` to the planning output (`planned/sprint.json`).
- `acceptanceCriteria`: each bullet provable by a command
- `factBaseSlices`: only slices the generator needs for this task
- `verify[]`: each entry needs `cmd` + (`expectExitCode` OR `expectOutputContains` OR
  `expectOutputNotContains`). `cwd` relative to artifacts dir. Default `timeoutSec`: 300.
- `failureModes`: cite `FB s13#N` for every relevant drift trap
- `rubric`: 1–5 graded criteria (non-quantifiable; for evaluator)
- `passes: false`, `iterations: 0`, `notes: ""`

### 4b. Verify-command safety (weak-model traps the evaluator WILL catch)

These produce a **vacuous pass** (exit 0 that proves nothing) — the evaluator rejects them:
- **Never start a `cmd` with `#`.** PowerShell runs verify via `-Command`; a leading `#` comments
  out the entire single-line string → instant exit 0. Put intent in `description`, not as a `#` line.
- **A live run needs the mocker process up.** If the SUT talks to a mocker, the run-task `verify`
  must start the mocker in the background, wait for its port, run the runner, capture
  `$LASTEXITCODE`, then stop the mocker — all in **ONE** `cmd` string (see T-003 below). Two separate
  verify entries do NOT share a background process, so the runner connects to nothing.
- **PORT CONTRACT — ONE port literal (FB s13#16).** The TCP probe port, the mocker `Servers.Http.Port`,
  and the runner Transaction `Http.Port` are the **same single number**. Pick it once (8080 in the
  example), reuse it verbatim in all three places. Never invent a second port for the probe — probing a
  port the mocker never binds loops the full wait then exits 9 `MOCKER NEVER READY`, and the runner
  never runs. Do NOT add a `#` comment to record the port inside the `cmd` (that trips FB s13#14); state
  the port contract in the task `description`/`rubric` instead.
- **JSON validity:** descriptions and cmds live inside a JSON string. Do **not** paste raw double
  quotes (`"`) inside them — use single quotes (`'symbol':'X'`) or escape as `\"`. An unescaped `"`
  breaks the whole sprint.json (`validate-sprint.ps1` reports an invalid-JSON parse error).

### 5. Validate before emitting

- [ ] `goalOneSentence` is exactly one sentence
- [ ] Every task has ≥1 `verify[]` entry with a mechanical expectation
- [ ] No task at priority N depends on task at priority ≥ N
- [ ] Every `description` is self-contained (no "see T-001")
- [ ] `failureModes` cite FB s13 rows where applicable
- [ ] No `verify` `cmd` starts with `#`; live-run verify manages the mocker in ONE cmd
- [ ] PORT CONTRACT: probe port == mocker `Servers.Http.Port` == runner `Http.Port` (one literal, FB s13#16)
- [ ] Each task's `files.create` lists ITS files (not `planned/sprint.json`)
- [ ] No raw `"` inside any description/cmd string — the whole sprint.json must parse as JSON

### 6. Compact worked example — HTTP smoke test sprint.json

```json
{
  "sprintId": "S01",
  "feature": "HTTP smoke test",
  "goalOneSentence": "Verify GET /hello returns HTTP 200 via a StaticResponseProcessor mocker stub.",
  "nonGoals": ["auth", "gRPC", "load test"],
  "factBaseSlices": ["s01","s02","s09","s13","s14"],
  "tasks": [
    {
      "id": "T-001", "title": "Scaffold runner and mocker projects",
      "priority": 1, "dependsOn": [], "skill": "scaffold-runner-project",
      "files": {"create": ["Runner/Runner.csproj","Mocker/Mocker.csproj"], "edit": []},
      "description": "dotnet new qaas-runner -n Runner; dotnet new qaas-mocker -n Mocker from local template path (not nuget.org). Runner.csproj: net10.0, QaaS.Runner 4.5.1, QaaS.Common.Generators + QaaS.Common.Assertions PackageReferences, CopyToOutputDirectory PreserveNewest for *.qaas.yaml. Mocker.csproj: QaaS.Common.Processors. NuGet.config: <clear/> + single <add> Artifactory URL. TRAP: missing pkg refs -> FTL exit -532462766 (FB s13#8).",
      "acceptanceCriteria": [
        "dotnet build -c Release exits 0 in Runner",
        "dotnet build -c Release exits 0 in Mocker"
      ],
      "factBaseSlices": ["s01","s13"],
      "verify": [
        {"cwd": "Runner", "cmd": "dotnet build -c Release", "expectExitCode": 0},
        {"cwd": "Mocker", "cmd": "dotnet build -c Release", "expectExitCode": 0}
      ],
      "rubric": ["CopyToOutputDirectory present; no placeholder versions"],
      "failureModes": ["Missing QaaS.Common.* refs (FB s13#8)", "CopyToOutputDirectory absent (FB s01)"],
      "passes": false, "iterations": 0, "notes": ""
    },
    {
      "id": "T-002", "title": "Author runner and mocker YAML",
      "priority": 2, "dependsOn": ["T-001"], "skill": "author-runner-yaml",
      "files": {"create": ["Runner/hello.qaas.yaml","Runner/TestData/req.json","Mocker/hello.mocker.yaml"], "edit": []},
      "description": "Runner hello.qaas.yaml (FB s14.1 verbatim shape): MetaData(Team,System req), Storages(- FileSystem: {Path: ./session-data}), DataSources(Name:HelloData, Generator:FromFileSystem, GeneratorConfiguration:{DataArrangeOrder:AsciiAsc, FileSystem:{Path:TestData}}), Sessions(Transaction Name:CallHello, TimeoutMs:5000, DataSourceNames:[HelloData] REQUIRED, Http:{BaseAddress:http://127.0.0.1, Port:8080, Route:hello NO leading slash, Method:Get}), Assertions: HttpStatus(StatusCode:200, OutputNames:[CallHello]) + HermeticByExpectedOutputCount(OutputNames:[CallHello], ExpectedCount:1 NOT ExpectedOutputCount). Mocker hello.mocker.yaml (FB s14.2): StaticResponseProcessor, ProcessorConfiguration:{StatusCode:200, Body:hello}. TRAPS: Route:/hello->404 (FB s13#5); DataSourceNames missing->validation error (FB s13#3); HttpStatus vacuous pass (FB s13#13); TransactionData key (FB s13#1); ExpectedOutputCount silently ignored (FB s13#12).",
      "acceptanceCriteria": [
        "dotnet run -- template hello.qaas.yaml exits 0 with no 'not found in' warnings",
        "dotnet run -- template hello.mocker.yaml exits 0",
        "HermeticByExpectedOutputCount assertion present"
      ],
      "factBaseSlices": ["s02","s03","s09","s12","s13","s14"],
      "verify": [
        {"cwd": "Runner", "cmd": "dotnet run -- template hello.qaas.yaml", "expectExitCode": 0},
        {"cwd": "Runner", "cmd": "dotnet run -- template hello.qaas.yaml", "expectOutputNotContains": "not found in"},
        {"cwd": "Mocker", "cmd": "dotnet run -- template hello.mocker.yaml", "expectExitCode": 0}
      ],
      "rubric": ["HttpStatus + hermetic guard present", "DataSourceNames on every Transaction"],
      "failureModes": [
        "Route: /hello leading slash (FB s13#5)", "DataSourceNames missing on Transaction (FB s13#3)",
        "TransactionData instead of ProcessorConfiguration (FB s13#1)",
        "HttpStatus vacuous pass without hermetic guard (FB s13#13)",
        "ExpectedOutputCount instead of ExpectedCount (FB s13#12)"
      ],
      "passes": false, "iterations": 0, "notes": ""
    },
    {
      "id": "T-003", "title": "Run end-to-end and verify green",
      "priority": 3, "dependsOn": ["T-002"], "skill": "run-and-collect",
      "files": {"create": [], "edit": []},
      "description": "Start the mocker in the BACKGROUND from the Mocker project, wait for its port, run the runner from the Runner project, capture the runner exit code, then stop the mocker. Expect exit 0 and 'ExitCode=0'. PORT CONTRACT: the TcpClient probe port, the mocker Servers Http Port, and the runner Transaction Http Port are ONE single value (here 8080) — probing a port the mocker never binds loops 40x then exits 9 'MOCKER NEVER READY' and the runner never runs (FB s13#16). TRAP: run from project dir not solution dir (LAB L6); a live run needs the mocker process up first (a bare 'dotnet run -- run' with no mocker connects to nothing and fails or passes vacuously).",
      "acceptanceCriteria": ["consolidated verify exits 0", "output contains 'ExitCode=0'"],
      "factBaseSlices": ["s06","s13"],
      "verify": [
        {"cwd": "Runner", "cmd": "$m = Start-Process dotnet -ArgumentList 'run','-c','Release','--','run','hello.mocker.yaml' -WorkingDirectory '..\\Mocker' -PassThru; $ok=$false; foreach($i in 1..40){ try { (New-Object Net.Sockets.TcpClient('127.0.0.1',8080)).Close(); $ok=$true; break } catch { Start-Sleep 2 } }; if(-not $ok){ Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue; Write-Output 'MOCKER NEVER READY'; exit 9 }; dotnet run -c Release -- run hello.qaas.yaml; $code=$LASTEXITCODE; Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue; exit $code", "expectExitCode": 0, "expectOutputContains": "ExitCode=0", "timeoutSec": 120}
      ],
      "rubric": ["ONE verify step manages mocker lifecycle + runner + exit code", "PORT CONTRACT: probe port == mocker Port == runner Port (one literal)"],
      "failureModes": ["Probe port != mocker bind port -> MOCKER NEVER READY exit 9, runner never runs (FB s13#16)", "Two separate verify steps don't share the background mocker (vacuous pass FB s13#15)", "verify cmd starting with '#' is silently commented out by PowerShell -Command (vacuous 0, FB s13#14)", "Run from solution dir not project dir (LAB L6)"],
      "passes": false, "iterations": 0, "notes": ""
    }
  ]
}
```

## Citations

- PROTOCOL §3 (sprint.json schema, verify[] rules, priority constraint)
- FB s00 (mental model), FB s02 (session types), FB s06 (CLI exit codes)
- FB s13 (drift traps — cite row numbers in failureModes)
- FB s14.1–s14.2 (golden examples as verify baselines)

## Traps

- **Priority inversion** — harness deadlocks if a task depends on one with higher priority number
- **description references another task** — generator context is isolated; must be self-contained (PROTOCOL §3)
- **verify[] prose only** — must have `cmd` + mechanical expectation; prose belongs in `rubric`
- **goal is two sentences** — rewrite with semicolon or demote second part to `nonGoals`
