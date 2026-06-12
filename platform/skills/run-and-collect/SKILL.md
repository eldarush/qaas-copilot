---
name: run-and-collect
version: 1.0.0
description: Execute QaaS CLI verbs (run/act/assert/execute/template) and collect allure-results artifacts.
when_to_use: When a task needs to run tests, replay assertions offline, dump config, or read result artifacts.
inputs:
  - name: verb
    example: "run | act | assert | execute | template"
  - name: config_file
    example: "test.qaas.yaml"
  - name: flags
    example: "-n SessionName -e"
outputs:
  - path: "allure-results/*-result.json"
  - path: "allure-results/SessionsData/<ts>/<session>.json"
fact_base_slices: [s06, s07, s13]
references:
  - references/flags-reference.md
contract:
  done_rubric:
    - "dotnet run -- <verb> <cfg> => expected exit code captured"
    - "allure-results/*-result.json listed; status field inspected"
  failure_modes:
    - "CWD not project dir → CouldNotFindConfigurationException (FB s13, LAB L6)"
    - "HttpStatus vacuous pass with 0 outputs → false green (FB s13#13, LAB L7)"
    - "act writes SessionData; assert replays with infra DOWN (LAB L3)"
  escalation: "NEEDS_CLARIFICATION: <field> | BLOCKED: <reason>"
---

## When to use

Use when you must invoke QaaS CLI, capture exit codes, split act/assert, or inspect allure artifacts.

## Steps

### 1. Run from the correct directory
**CWD must be the project folder** (where the .csproj is). Config paths resolve against CWD.
Symptom when wrong: `CouldNotFindConfigurationException: YAML configuration file was not found.
Resolved local path: <cwd>\x.yaml` (FB s13, LAB L6).
```powershell
cd Mocker    # or Runner project dir
dotnet run -- run test.qaas.yaml
```

### 2. Verb reference (FB s06)

| Verb | Purpose | Exit on assertions? |
|---|---|---|
| `run` | sessions + assertions end-to-end | yes |
| `act` | run sessions only, persist SessionData, no assertions | no |
| `assert` | replay assertions on stored SessionData (no protocol calls) | yes |
| `execute` | run a YAML list of commands sequentially | yes |
| `template` | print fully-resolved config; schema oracle | no |

Default config: `test.qaas.yaml` (`execute` default: `executable.yaml`) (FB s06).

### 3. Key flags (FB s06)
```
-n / --cases-names <name>        filter by case name
-i / --session-names <name>      filter sessions
-a / --assertion-names <name>    filter assertions
-c / --cases <folder>            run one execution per case file
-w / --with-files <file>         merge overwrite YAML file (in order)
-f / --with-folders <folder>     merge all YAMLs in folder
-r / --overwrite-arguments Key:To:Field=Value   inline override
-p / --push-references KW Ref.yaml  push reference (KW must NOT end .yml/.yaml)
-e / --empty-results-directory   clear allure-results before run
-s / --serve-results [dir]       serve allure (needs allure CLI in PATH)
-l / --logger-level Verbose|Debug|Information|Warning|Error|Fatal
-g / --logger-configuration-file <path>
--no-process-exit                do not call Environment.Exit (for test hosts)
```
Full flag list: references/flags-reference.md.

### 4. Exit codes (FB s06, LAB L1/L2)
| Code | Meaning |
|---|---|
| `0` | help/version, successful act/template, or all assertions passed |
| `1` | CLI parse error, invalid config (`FTL Runner execution configuration is invalid`), or ≥1 failed assertion |
| `>1` | execute: sum of child exit codes across multiple failing runs |
| `-532462766` | DI crash after missing hook FTL |

### 4b. Live e2e gate — mocker + runner in ONE command (FB s13#15, #16; LAB L6)
When the runner calls a mocker, the run must (1) start the mocker in the **background**, (2) wait for its
port, (3) run the runner, (4) capture `$LASTEXITCODE`, (5) stop the mocker — **all in ONE `cmd`**. Two
separate steps do not share the background process (FB s13#15).

**PORT CONTRACT (FB s13#16): ONE port literal.** The probe port, the mocker `Servers.Http.Port`, and the
runner Transaction `Http.Port` are the **same number**. Pick it once, reuse it verbatim in all three.
A probe on a port the mocker never binds loops the full wait, prints `MOCKER NEVER READY`, exits 9, and
the runner never runs. Never invent a second port for the probe. Do not write the port as a `#` comment
inside the cmd (that trips FB s13#14).

```powershell
# from the Runner project dir; mocker project is ..\Mocker; PORT = 8080 everywhere
$m = Start-Process dotnet -ArgumentList 'run','-c','Release','--','run','hello.mocker.yaml' -WorkingDirectory '..\Mocker' -PassThru
$ok = $false
foreach ($i in 1..40) { try { (New-Object Net.Sockets.TcpClient('127.0.0.1',8080)).Close(); $ok=$true; break } catch { Start-Sleep 2 } }
if (-not $ok) { Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue; Write-Output 'MOCKER NEVER READY'; exit 9 }
dotnet run -c Release -- run hello.qaas.yaml
$code = $LASTEXITCODE
Stop-Process -Id $m.Id -Force -ErrorAction SilentlyContinue
exit $code
```
Success: the runner prints its own `ExitCode=0` summary line and the whole cmd exits 0. The `8080` in the
probe MUST equal the mocker YAML `Servers.Http.Port` and the runner YAML `Http.Port`.

### 5. act / assert offline split (FB s06, LAB L3)
```powershell
# Step 1 — capture traffic once (mocker must be UP)
dotnet run -- act test.qaas.yaml
# Writes: allure-results/SessionsData/<ts>/<session>.json

# Step 2 — iterate assertions without infra (mocker can be stopped)
dotnet run -- assert test.qaas.yaml
# Reads SessionData from Storages.FileSystem.Path; no network calls
```
LAB-verified: `assert` replays GREEN with mocker fully stopped (LAB L3).

### 6. allure-results layout (FB s07, LAB L2)
```
allure-results/
├── *-result.json              # one per assertion
│   # uuid=assertion-name, status: passed|failed|broken
│   # statusDetails.message / .trace
│   # description = YAML of assertion config
├── SessionsData/<ts>/<session>.json
│   # Inputs[] / Outputs[]; Data[].Timestamp / .Body(base64) / .MetaData (incl. Http.StatusCode)
├── SessionLogs/<ts>/<session>.log
├── Templates/<ts>/template.yaml
└── AssertionsAttachments/
```
Read result JSON:
```powershell
Get-ChildItem allure-results\*-result.json | ForEach-Object {
    $r = Get-Content $_ | ConvertFrom-Json
    [pscustomobject]@{ Name=$r.name; Status=$r.status; Message=$r.statusDetails.message }
}
```

### 7. template verb — schema oracle (FB s06, LAB L2)
```powershell
dotnet run -- template test.qaas.yaml
# Prints fully-resolved config with defaults merged
# Unknown properties produce: "Property X in path Y - not found in Z object"
# Use this to validate YAML before running
```

## Traps
| Trap | Fix |
|---|---|
| Wrong CWD → config not found (FB s13, LAB L6) | `cd` into project folder first |
| Probe port != mocker bind port → `MOCKER NEVER READY` exit 9 (FB s13#16) | ONE port literal: probe == mocker `Servers.Http.Port` == runner `Http.Port` |
| Live run split across two verify steps → mocker already gone (FB s13#15) | Start mocker + probe + run + stop in ONE cmd (§4b) |
| HttpStatus passes with 0 outputs (FB s13#13, LAB L7) | Always pair with hermetic guard |
| Silently-ignored config key (FB s13#12, LAB L7) | Copy keys from catalog yamlView exactly |
| `act` uses Storages.FileSystem.Path for session data | Ensure Storages block is in YAML |

## Citations
- FB s06 (verbs, flags, exit codes), FB s07 (allure layout), FB s13 (CWD trap, vacuous pass)
