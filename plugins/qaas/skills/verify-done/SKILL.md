---
name: verify-done
version: 1.0.0
description: Mechanical completion gate — execute every verify[] step from the sprint task and produce a verdict JSON.
when_to_use: Used by the evaluator after every generator run, and by the generator as a self-check before emitting DONE.
inputs:
  - name: task_verify_array
    example: "[{cwd, cmd, expectExitCode, expectOutputContains, timeoutSec}]"
  - name: artifacts_dir
    example: "sprints/S01/artifacts"
outputs:
  - path: "sprints/S01/verdict-T-001.json"
fact_base_slices: [s06, s07, s13]
references: []
contract:
  done_rubric:
    - "every verify step ran fresh with captured output"
    - "verdict JSON well-formed per PROTOCOL §6"
    - "no false greens: vacuous-pass guard, silently-ignored-key guard, zero-outputs guard applied"
  failure_modes:
    - "HttpStatus vacuous pass accepted as green without hermetic guard (FB s13#13)"
    - "Silently-ignored config key not caught by template check (FB s13#12)"
    - "allure passed-status with 0 output items (LAB L7)"
    - "Remembered output used instead of fresh run output"
  escalation: "BLOCKED: <step N failed and cannot be retried>"
---

## When to use

Use at the end of every task to mechanically decide PASS or FAIL. Never flip `passes:true` by reasoning alone.

## Steps

### 1. Execute each verify step (PROTOCOL §3)
Each step in the task's `verify[]` array has:
```json
{
  "cwd": "Runner",                   // optional; relative to artifacts dir; cd here before cmd
  "cmd": "dotnet run -- template test.qaas.yaml",
  "expectExitCode": 0,               // optional
  "expectOutputContains": "200",     // optional; substring match
  "expectOutputNotContains": "error",// optional
  "timeoutSec": 300                  // default 300
}
```
Execute in PowerShell:
```powershell
$result = & {
    if ($step.cwd) { Push-Location (Join-Path $artifactsDir $step.cwd) }
    $output = Invoke-Expression $step.cmd 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($step.cwd) { Pop-Location }
    [pscustomobject]@{ Output=$output; ExitCode=$exitCode }
}
```
All present expectations (expectExitCode, expectOutputContains, expectOutputNotContains) must hold.

### 2. Evidence rule (CONSTITUTION III)
**Fresh run output only.** Never use remembered output from a prior session.
Paste the actual command output into findings. A claim of "exit 0" is not evidence.

### 3. Three mandatory false-green guards (LAB L7)

#### Guard A — Vacuous HttpStatus pass (FB s13#13)
Before accepting an HttpStatus assertion as PASSED:
```powershell
# Check that SessionsData has actual outputs, not zero
$sessions = Get-ChildItem allure-results\SessionsData\*\*.json -ErrorAction SilentlyContinue
foreach ($f in $sessions) {
    $data = Get-Content $f | ConvertFrom-Json
    $outputCount = ($data.Outputs | Measure-Object).Count
    if ($outputCount -eq 0) { Write-Warning "ZERO OUTPUTS in $($f.Name) — possible vacuous pass" }
}
```
FAIL the verify step if any HTTP session has 0 outputs AND HttpStatus is the only guard.
Require `HermeticByExpectedOutputCount` with `ExpectedCount: N` in the YAML (FB s14#8).

#### Guard B — Silently-ignored config key (FB s13#12)
Run `template` and check that every config field in the YAML appears in the template dump:
```powershell
$templateOut = dotnet run -- template test.qaas.yaml 2>&1 | Out-String
if ($templateOut -match "not found in .* object") {
    Write-Warning "Unknown property detected: $($Matches[0])"
    # FAIL this verify step
}
```
If `template` warns about unknown properties, the verify step FAILS.

#### Guard C — allure passed-status with 0 output items (LAB L7)
```powershell
Get-ChildItem allure-results\*-result.json | ForEach-Object {
    $r = Get-Content $_ | ConvertFrom-Json
    if ($r.status -eq "passed") {
        # Check description for OutputNames, then verify those names have data
        $desc = $r.description
        Write-Host "PASSED: $($r.name) — verify outputs exist in SessionsData"
    }
}
```

### 4. Verdict JSON format (PROTOCOL §6)
```json
{
  "verdict": "PASS",
  "scores": {
    "correctness": 5,
    "driftAvoidance": 5,
    "citations": 5,
    "completeness": 5
  },
  "findings": [
    {
      "severity": "blocker|major|minor",
      "file": "Runner/test.qaas.yaml",
      "issue": "description of problem",
      "suggestedFix": "what to change"
    }
  ],
  "learnings": [
    "PATTERN: Route values never start with '/' (FB s13#5)"
  ]
}
```
Rules (PROTOCOL §6):
- `verdict: PASS` requires: all mechanical verify steps passed AND no `blocker` findings AND all rubric scores >= 4.
- `findings[]` severity: `blocker` (prevents PASS), `major` (degrades score), `minor` (note only).
- `learnings[]` ≤ 3 bullets; prepend `PATTERN:` for progress.txt injection.

### 5. Write verdict file
```powershell
$verdict | ConvertTo-Json -Depth 5 | Set-Content "sprints\S01\verdict-T-001.json"
```

### 6. Emit status code
```
DONE              # all steps pass, no blockers
DONE_WITH_CONCERNS: <note>   # passed but minor findings
BLOCKED: step N failed — <reason>   # a step could not be executed or retried
```

## Traps
| Trap | Guard required |
|---|---|
| HttpStatus vacuous pass (FB s13#13) | Guard A: check 0-outputs in SessionsData |
| Silently-ignored key (FB s13#12) | Guard B: run `template`, check for unknown-property warnings |
| allure passed with 0 items (LAB L7) | Guard C: correlate passed result with actual output count |
| Remembered output = not evidence | Always capture fresh command output in this session |

## Citations
- PROTOCOL §3 (verify[] schema), PROTOCOL §6 (verdict JSON), FB s13#12/#13 (false-green traps), LAB L7
