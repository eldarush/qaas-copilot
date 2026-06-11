---
name: author-runner-yaml
version: 1.0.0
description: Write a complete, drift-correct QaaS Runner YAML covering all sections from MetaData through Assertions.
when_to_use: Any task that requires creating or editing a *.qaas.yaml runner configuration file.
inputs:
  - session_types: which protocols/actions (HTTP, RabbitMQ, Publisher, Consumer, Transaction, etc.)
  - data_sources: input data location (TestData folder, CSV, S3, etc.)
  - assertions_needed: which assertions to apply
outputs:
  - <name>.qaas.yaml
  - TestData/ payload files (if FromFileSystem generator used)
fact_base_slices: [s02, s09, s10, s13, s14]
references:
  - references/sessions.md
  - references/golden-examples.md
contract:
  done_rubric:
    - 'dotnet run -- template <cfg> exits 0'
    - 'dotnet run -- template <cfg> output contains no "not found in ... object" warnings'
    - 'dotnet run -- run <cfg> exit code matches scenario expectation (0 all pass; 1 >=1 fail)'
    - 'Every HTTP/queue session has a hermetic-count guard alongside any content/status assertion'
  failure_modes:
    - 'Storages wrong shape: Name:/StorageConfiguration: (FB s13#2)'
    - 'Transactions missing DataSourceNames -> validation error exit 1 (FB s13#3)'
    - 'HttpStatus config StatusCode/OutputNames wrong keys -> vacuous pass (FB s13#4, s13#12, s13#13)'
    - 'Route: /hello leading slash -> //hello -> 404 (FB s13#5); also use ALL-LOWERCASE routes -> mixed-case -> 404 (FB s13#5b)'
    - 'Unknown AssertionConfiguration keys silently ignored (FB s13#12)'
    - 'Missing hook package refs -> FTL exit -532462766 (FB s13#8)'
  escalation: 'NEEDS_CLARIFICATION: unknown session protocol | NEEDS_CONTEXT: s10 if generator unknown'
---

## When to use

Call this skill to produce a `*.qaas.yaml` file. Use `choose-action-type`, `pick-generator`,
and `pick-assertion` skills first if the session type or assertion is unclear.

## Steps

### 1. MetaData (FB s02 §2.1)

```yaml
MetaData:
  Team: <team-name>   # REQUIRED
  System: <system>    # REQUIRED
  # ExtraLabels: {env: qa}  # optional
```

### 2. Variables and anchors (FB s02 §2.2–2.3)

```yaml
variables:           # lowercase section
  mocker: {host: "http://127.0.0.1", port: 8080}

anchors:
  httpBase: &httpBase
    BaseAddress: ${variables:mocker:host}
    Port: ${variables:mocker:port}
    Method: Get
```

Syntax: `${variables:key:subkey??default}`. Anchors do NOT work across overwrite files (FB s02).

### 3. Storages (FB s02 §2.4) — EXACT shape

```yaml
Storages:
  - FileSystem:
      Path: ./session-data    # relative to runner CWD at act-time
```

⚠️ The `Name:` + `StorageConfiguration:` form is **doc-drift** — do not use (FB s13#2).

### 4. DataSources / Generators (FB s02 §2.5, FB s10)

```yaml
DataSources:
  - Name: HelloData              # referenced by DataSourceNames in sessions
    Generator: FromFileSystem    # simple class name (FB s00)
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc   # RECOMMENDED ordering
      FileSystem: { Path: TestData }
```

Use `pick-generator` skill to choose among the 11 generators (FB s10).
Add `QaaS.Common.Generators` PackageReference for any built-in generator (FB s13#8).

### 5. Sessions (FB s02 §2.6)

Session fields: `Name`(req), `Stage`, `RunUntilStage`, `TimeoutMs`, `SaveData`.
Actions: `Publishers`, `Consumers`, `Transactions`, `Collectors`, `Probes`, `MockerCommands`.
Default stage order: Consumers=0, Publishers=1, Transactions=2, Probes=3, MockerCommands=4.
Full field lists → **references/sessions.md**.

**RabbitMQ topology (FB s11 §11.1, s13#17):** a Publisher/Consumer does NOT create missing
exchanges/queues. If they don't pre-exist you get `NOT_FOUND - no exchange '<name>' in vhost '/'`
→ `ExitCode=1`. Declare topology first with a `CreateRabbitMqExchanges` (and/or
`CreateRabbitMqQueues`) **Probe at `Stage: 0`** (config shape in FB s11 §11.1), unless the SUT/seed
already creates it. **Any probe REQUIRES `<PackageReference Include="QaaS.Common.Probes" Version="1.5.1" />`
in the Runner `.csproj` (FB s13#8)** — it is commented out by default; add it (or scaffold with it as
look-ahead) or the run crashes at hook resolution with Autofac `exit -532462766`, not a YAML error.

**Transactions REQUIRE `DataSourceNames` or `DataSourcePatterns` (FB s13#3):**
```yaml
Transactions:
  - Name: CallHello
    TimeoutMs: 5000              # REQUIRED
    DataSourceNames: [HelloData] # REQUIRED (FB s13#3)
    Http:
      BaseAddress: http://127.0.0.1
      Port: 8080
      Route: hello               # NO leading slash (FB s13#5) + all-lowercase (FB s13#5b)
      Method: Get

### 6. Assertions (FB s02 §2.9, FB s09)

```yaml
Assertions:
  - Name: <reporting-name>
    Assertion: <hook-simple-name>  # e.g. HttpStatus
    SessionNames: [<session-name>] # REQUIRED — data providers
    AssertionConfiguration: { ... } # copy keys EXACTLY from FB s09 (FB s13#12)
```

Use `pick-assertion` skill for exact config keys. Add `QaaS.Common.Assertions` ref (FB s13#8).

**HERMETIC GUARD (CONSTITUTION VII, FB s13#13):** Pair any HttpStatus/content assertion with
`HermeticByExpectedOutputCount {OutputNames:[X], ExpectedCount:N}` — not `ExpectedOutputCount`
(FB s13#12). HttpStatus passes vacuously with 0 outputs (false green, LAB L7).

### 7. Golden example — hello.qaas.yaml (FB s14.1 verbatim, LAB-green)

```yaml
MetaData:
  Team: Smoke
  System: HelloWorld

Storages:
  - FileSystem:
      Path: ./session-data

DataSources:
  - Name: HelloData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData }

Sessions:
  - Name: HelloSession
    Transactions:
      - Name: CallHello
        TimeoutMs: 5000
        DataSourceNames: [HelloData]      # REQUIRED for transactions
        Http:
          BaseAddress: http://127.0.0.1
          Port: 8080
          Route: hello                    # NO leading slash
          Method: Get

Assertions:
  - Name: ReturnedOk
    Assertion: HttpStatus
    SessionNames: [HelloSession]
    AssertionConfiguration:
      StatusCode: 200                     # NOT ExpectedStatus
      OutputNames: [CallHello]            # list; matches transaction Name
```

Run: `dotnet run -- run hello.qaas.yaml` → exit 0.
Requires `QaaS.Common.Generators` + `QaaS.Common.Assertions` in csproj (FB s13#8).

See **references/golden-examples.md** for FB s14.3 (RabbitMQ) and FB s14.8
(variables/anchors/overwrite/cases).

### 8. Verify

```powershell
cd <ProjectDir>
dotnet run -- template <cfg>.qaas.yaml   # exit 0; no "not found in" warnings
dotnet run -- run <cfg>.qaas.yaml        # exit matches scenario (0=all pass, 1=>=1 fail)
```

## Citations

- FB s02 (all YAML sections, field names, defaults)
- FB s09 (assertion catalog — exact config keys)
- FB s10 (generator catalog — exact config keys)
- FB s13 (all drift traps — #1 through #13)
- FB s14.1 (golden hello.qaas.yaml), FB s14.3 (RabbitMQ), FB s14.8 (variables/cases)
- CONSTITUTION VII (hermetic guard rule)

## Traps

| # | Trap | Fix |
|---|---|---|
| s13#2 | Storages `Name:`+`StorageConfiguration:` form | Use `- FileSystem: {Path: ...}` |
| s13#3 | Transactions without `DataSourceNames` | Always add `DataSourceNames` or `DataSourcePatterns` |
| s13#4 | HttpStatus `ExpectedStatus:`+`OutputName:` | Use `StatusCode:` + `OutputNames:` (list) |
| s13#5 | `Route: /hello` | Use `Route: hello` (no leading slash) |
| s13#5b | `Route: myRoute` (mixed-case) | Use lowercase `Route: myroute` + mocker `Path: /myroute` — mocker matches case-sensitively |
| s13#12 | Typo in `AssertionConfiguration` key | Copy verbatim from FB s09 catalog |
| s13#13 | HttpStatus passes vacuously with 0 outputs | Always add hermetic count guard |
| s13#8 | Built-in hook family not in csproj | Add `QaaS.Common.Generators/Assertions` explicitly |
| s13#17 | Rabbit Publisher/Consumer `NOT_FOUND - no exchange` | Declare topology first via `CreateRabbitMqExchanges`/`CreateRabbitMqQueues` Probe at `Stage: 0` (FB s11 §11.1) |
