---
name: author-mocker-yaml
version: 1.0.0
description: Write a valid QaaS mocker YAML (Servers/Stubs/Controller) that serves stubbed HTTP responses.
when_to_use: When a task needs a mock HTTP server with configurable stub responses for a runner test.
inputs:
  - name: endpoint_path
    example: "/hello"
  - name: method
    example: "Get"
  - name: desired_status
    example: 200
  - name: desired_body
    example: "hello"
outputs:
  - path: "Mocker/<name>.mocker.yaml"
fact_base_slices: [s03, s12, s13, s14]
references:
  - references/processors-summary.md
contract:
  done_rubric:
    - "dotnet run --project Mocker -- template <cfg>.mocker.yaml => exit 0, no unknown-property warnings"
    - "curl.exe http://127.0.0.1:<port><path> => expected status + body"
  failure_modes:
    - "TransactionData instead of ProcessorConfiguration (FB s13#1)"
    - "Route has leading slash → //path → 404 (FB s13#5)"
    - "Mixed-case route → mocker lowercases Path but matches case-sensitively → 404 (FB s13#5b); use all-lowercase routes"
    - "IsLocalhost:true in container → binds 127.0.0.1 only, unreachable from host (FB s03)"
    - "Missing QaaS.Common.Processors reference → FTL + exit -532462766 (FB s13#8)"
    - "Controller.ServerName mismatch with Runner MockerCommands.ServerName (FB s03)"
  escalation: "NEEDS_CLARIFICATION: <field> | BLOCKED: <reason>"
---

## When to use

Use when you must produce a `.mocker.yaml` that boots a QaaS.Mocker HTTP server with at least one stub.

## Steps

### 1. Servers block
```yaml
Servers:
  - Http:
      Port: 8080           # unique across all servers; duplicates = fail-fast (FB s03)
      # IsLocalhost: false  # omit or false → binds 0.0.0.0; true → 127.0.0.1 only (BAD in Docker)
      Endpoints:
        - Path: /hello      # Path on Mocker side HAS the leading slash (FB s03). ALL-LOWERCASE — mocker lowercases this but matches the request case-sensitively (FB s13#5b)
          Actions:
            - Name: HelloOk
              Method: Get   # Get|Post|Put|Delete|Head|Options|Patch|Trace|Connect (FB s03)
              TransactionStubName: HelloStub
```
- `Path` on Endpoints uses a leading slash; `Route` in runner YAML does NOT (FB s13#5).
- **Routes must be all-lowercase** on BOTH the mocker `Path:` and the runner `Route:` — the mocker lowercases the configured `Path` then matches the request path case-sensitively, so `Path: /myRoute` + `Route: myRoute` → 404 (FB s13#5b).
- Each endpoint Action links to a Stub via `TransactionStubName`.

### 2. Stubs block
```yaml
Stubs:
  - Name: HelloStub
    Processor: StaticResponseProcessor   # simple class name (FB s03)
    ProcessorConfiguration:              # NEVER TransactionData (FB s13#1)
      Body: hello
      StatusCode: 200
      ContentType: "text/plain; charset=utf-8"
```
- `ProcessorConfiguration` is the only correct key. Using `TransactionData` produces:
  `Property TransactionData in path Stubs:0 - not found in TransactionStubConfig object` (FB s13#1).
- 9 built-in processors ship in `QaaS.Common.Processors` — see references/processors-summary.md.
- Runtime always adds 2 default stubs (not-found + internal-error):
  `Built 4 transaction stub(s) including default not-found and internal-error stubs` (FB s03, LAB L5).

### 3. DataSources block (optional, needed by DataSourceResponseProcessor)
```yaml
DataSources:
  - Name: MyData
    Generator: FromFileSystem
    GeneratorConfiguration:
      DataArrangeOrder: AsciiAsc
      FileSystem: { Path: TestData }
```
Reference in stub: `DataSourceNames: [MyData]` inside the Stubs entry (FB s03).

### 4. Controller block (optional — Redis control plane)
```yaml
Controller:
  ServerName: HelloMocker          # byte-match with Runner MockerCommands[].ServerName (FB s03, LAB L6)
  Redis:
    Host: "127.0.0.1:6379"         # single "host:port" string (FB s14#7, LAB L6)
```
Boot log when configured: `Initialized Redis controller for server 'HelloMocker' with instance id '...'`
and `Started control handler 'CommandHandler' ... 'runner-to-mocker:command:hellomocker:<id>'` (FB s13#11, LAB L6).
When omitted: `Controller startup skipped because 'Controller.ServerName' is not configured` (LAB L5).

### 5. Verbatim golden (LAB-green, FB s14#2)
```yaml
Servers:
  - Http:
      Port: 8080
      Endpoints:
        - Path: /hello
          Actions:
            - Name: HelloOk
              Method: Get
              TransactionStubName: HelloStub

Stubs:
  - Name: HelloStub
    Processor: StaticResponseProcessor
    ProcessorConfiguration:
      Body: hello
      StatusCode: 200
      ContentType: "text/plain; charset=utf-8"
```
Start: `dotnet run --project Mocker -- run hello.mocker.yaml`. Requires `QaaS.Common.Processors` in csproj.

### 6. Controller staged-swap golden (FB s14#7, LAB L6)
```yaml
Controller:
  ServerName: HelloMocker
  Redis: {Host: "127.0.0.1:6379"}
```
Runner side adds `MockerCommands[].ServerName: HelloMocker` and `Redis: {Host: "127.0.0.1:6379"}`.

### 7. Verify
```powershell
dotnet run --project Mocker -- template hello.mocker.yaml   # exit 0, no unknown-property warnings
dotnet run --project Mocker -- run hello.mocker.yaml        # wait for "HTTP Server started"
curl.exe http://127.0.0.1:8080/hello                        # body: hello, status: 200
```
Expected startup log: `HTTP Server started. Listening on http://0.0.0.0:8080` (LAB L3).

## Traps
| # | Trap | Fix |
|---|---|---|
| s13#1 | `TransactionData:` key | Use `ProcessorConfiguration:` |
| s13#5 | Runner `Route:/hello` → `//hello` → 404 | Runner Route has NO leading slash; Mocker Path /hello is correct |
| s13#7 | Dockerfile `runtime:10.0` → "Microsoft.AspNetCore.App not found" | Use `aspnet:10.0` |
| s13#8 | Missing `QaaS.Common.Processors` → FTL + exit -532462766 | Add PackageReference |
| s13#11 | Docs claim `Controller channel ready: HelloMocker` | Real logs differ — see step 4 |
| LAB L6 | `IsLocalhost:true` in Docker container | Omit or set false → binds 0.0.0.0 |

## Citations
- FB s03 (Mocker YAML blocks), FB s12 (9 processors), FB s13 (drift traps), FB s14#2/#7 (golden examples)
