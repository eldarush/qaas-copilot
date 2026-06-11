---
name: diagnose-failure
version: 1.0.0
description: Triage a QaaS test failure using exit code, allure result JSONs, and the error-signature table.
when_to_use: When a test run exits non-zero or produces failed/broken assertions, to find the exact cause and fix.
inputs:
  - name: exit_code
    example: "1 | -532462766"
  - name: allure_results_path
    example: "allure-results/"
outputs:
  - path: "(no artifact — produces a fix action or explanation)"
fact_base_slices: [s06, s07, s13]
references:
  - references/error-signatures.md
contract:
  done_rubric:
    - "diagnosis names the exact error-signature row + the fix"
    - "re-run after fix => exit 0 (or explanation that SUT is at fault)"
  failure_modes:
    - "HttpStatus vacuous pass accepted as green (FB s13#13)"
    - "Silently-ignored key not caught (FB s13#12)"
    - "CWD trap not checked first (FB s13, LAB L6)"
  escalation: "NEEDS_CLARIFICATION: <field> | BLOCKED: SUT issue outside QaaS control"
---

## When to use

Use when `dotnet run` exits non-zero, or allure shows failed/broken, or a run exits 0 but you suspect a false green.

## PRINCIPLE — minimal surgical fix (READ FIRST)

When repairing an existing file, make the **smallest possible edit**:
- Change **only** the specific broken key/line the error-signature identifies. Nothing else.
- **PRESERVE EVERY IDENTIFIER VERBATIM.** Routes/paths, ports, stub names, action names, data-source
  names are **CONTRACTS shared with the OTHER files** (e.g. the mocker `Path:` MUST equal the runner
  `Route:`). If you rename `Path: /testroute` to `/test`, or rename `Stub1` to `TestStub`, the runner
  still calls the OLD name → **404 / no match → the run fails** even though your YAML "looks cleaner".
  Copy these tokens **character-for-character** from the file you were given. Do NOT "tidy" or rename.
  Cross-check: the route/name you keep MUST match what the sibling runner/mocker YAML in your context uses.
- **Never rewrite the file from memory.** The existing file already has the correct structure for
  everything that isn't the bug — preserve it **verbatim** (servers, endpoints, ports, names, order,
  indentation). Reconstructing from memory is the #1 way diagnose tasks introduce NEW errors
  (e.g. dropping `Servers:…Endpoints`, swapping `Processor:`/`ProcessorConfiguration:`, inventing a
  stub-level `Route:`, or renaming the route so it no longer matches the runner).
- A correct mocker stub keeps this exact shape — touch only the one trapped key:
  ```yaml
  Stubs:
    - Name: Stub1
      Processor: StaticResponseProcessor        # the processor TYPE (a string) — required
      ProcessorConfiguration:                    # the config block (was TransactionData → s13#1)
        Body: hello
        StatusCode: 200
        ContentType: text/plain
  ```
  HTTP routing is NOT a stub field — it lives under `Servers: - Http: Endpoints: - Path:/x Actions:`
  with `TransactionStubName`. (Mocker endpoint `Path` KEEPS its leading slash; only the *runner*
  transaction `Route` drops it — s13#5.) Do not add `Route:` to a stub.
- After editing, diff in your head: exactly one logical change vs the original. If you changed more,
  you over-reached — revert the extra changes.

## Steps

### 1. Read exit code
| Code | Meaning | Next step |
|---|---|---|
| `1` | config invalid OR ≥1 assertion failed | check for FTL line → go to step 2 |
| `-532462766` | DI crash (missing hook) | find FTL → step 4 row 1 |
| `0` but suspicious | possible vacuous pass | check step 7 |

### 2. Check for config validation error
```powershell
dotnet run -- run test.qaas.yaml 2>&1 | Select-String "FTL"
```
If `FTL Runner execution configuration is invalid` + `Sessions:0:Transactions:0: ...` → schema error.
Fix YAML per path. Transactions require `DataSourceNames` or `DataSourcePatterns` (FB s13#3).

### 3. Run template to validate schema
```powershell
dotnet run -- template test.qaas.yaml
```
Unknown property warnings: `Property X in path Y - not found in Z object` → fix key name.
Template is the authoritative schema oracle (FB s06, LAB L2).

### 4. List failed/broken result JSONs
```powershell
Get-ChildItem allure-results\*-result.json | ForEach-Object {
    $r = Get-Content $_ | ConvertFrom-Json
    if ($r.status -ne "passed") {
        [pscustomobject]@{
            Name    = $r.name
            Status  = $r.status
            Message = $r.statusDetails.message
            Trace   = $r.statusDetails.trace
        }
    }
} | Format-List
```
Map `statusDetails.message` against the error-signature table in references/error-signatures.md.

### 5. Full error-signature table (FB s07, LAB)

| Symptom | Cause | Fix |
|---|---|---|
| `FTL ... I<X> hook instance <N> not found` then exit -532462766 | Hook assembly not referenced | Add `QaaS.Common.*` package or project asm ref (FB s13#8) |
| `FTL Runner execution configuration is invalid` + `Sessions:0:…` | Schema validation failure; missing required field | Fix YAML per path; Transactions need DataSourceNames (LAB L2) |
| `Property TransactionData in path Stubs:0 - not found in TransactionStubConfig` | Used `TransactionData` in mocker stub | Use `ProcessorConfiguration` (FB s13#1) |
| assertion `broken`: "Value cannot be null. (Parameter 'source')" | Named Output entirely missing | Fix Route/stub so output exists; check OutputNames match action Name (LAB L3#6) |
| HTTP 404 from mocker | Runner `Route:/x` → `//x` double-slash → DefaultNotFound | `Route: x` — no leading slash (FB s13#5) |
| `failed`: "No output items were found in the output Consumer…" | Consumer received nothing | Start SUT/relay; raise TimeoutMs (LAB L1) |
| Hermetic% = 0 | No outputs vs inputs | Same as above |
| "config file not found" on `dotnet run` | YAML not copied to output dir | Add `<CopyToOutputDirectory>PreserveNewest` |
| Container start: "Framework 'Microsoft.AspNetCore.App' … not found" | Mocker on `dotnet/runtime` image | Use `dotnet/aspnet:10.0` (FB s13#7, LAB L5) |
| MockerCommands time out, no error | Redis unreachable or Controller.ServerName unset | Configure Controller + matching ServerName (FB s03) |
| `CouldNotFindConfigurationException: …Resolved local path: <cwd>\x.yaml` | CWD is wrong (solution root vs project dir) | `cd` into project folder first (FB s13, LAB L6) |
| HttpStatus PASSES, exit 0, but no traffic (0 outputs) | Vacuous pass: 0 outputs still satisfies "all 200" | Add HermeticByExpectedOutputCount guard (FB s13#13, LAB L7) |
| Assertion fails with confusing "expected X count Y" | Unknown config key silently ignored | Copy field names exactly from catalog yamlView (FB s13#12, LAB L7) |
| `aspnet container crash` | ENTRYPOINT references wrong DLL name | Match DLL name to csproj `<AssemblyName>` |
| Controller Redis silent fail | Redis not running or wrong host:port | Verify Redis is up; Host = `"host:port"` single string (FB s14#7) |

### 6. act / assert split for root-cause isolation (FB s06, FB s07, LAB L3)
```
act fails  → assert would pass:  infra problem (broker/SUT/mocker)
act ok     → assert fails:       assertion config wrong
both ok    → run fails:          order-of-operations bug
```
```powershell
dotnet run -- act test.qaas.yaml    # exit code?
dotnet run -- assert test.qaas.yaml # exit code? (mocker can be stopped)
```

### 7. False-green guard (FB s13#13, LAB L7)
If exit 0 but you suspect no traffic:
```powershell
# Check SessionsData for actual outputs
Get-Content "allure-results\SessionsData\*\*.json" | ConvertFrom-Json |
    Select-Object -ExpandProperty Outputs | Measure-Object
```
Zero outputs = vacuous pass. Fix: add `HermeticByExpectedOutputCount` assertion with `ExpectedCount: N`
and `OutputNames: [<ActionName>]` (FB s14#8). Field is `ExpectedCount` not `ExpectedOutputCount` (FB s13#12).

### 8. Re-run cheapest repro
When SessionData exists from a prior `act`:
```powershell
dotnet run -- assert test.qaas.yaml   # fast; no infra needed
```

## Traps
| # | Trap |
|---|---|
| s13#13 | HttpStatus vacuous pass → always add hermetic guard |
| s13#12 | Silently-ignored key → run `template` and check field dump |
| s13#5 | Double-slash 404 → remove leading slash from runner Route |
| s13#1 | TransactionData → ProcessorConfiguration |
| LAB L6 | CWD trap → cd into project folder |

## Citations
- FB s07 (triage + allure layout), FB s06 (exit codes), FB s13 (all trap rows), LAB L1–L7
