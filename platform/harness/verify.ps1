# verify.ps1 - run a task's mechanical verify[] steps; emit structured JSON results.
# PROTOCOL §3 semantics: cwd/cmd/expectExitCode/expectOutputContains/expectOutputNotContains/timeoutSec.
# Usage:
#   .\verify.ps1 -SprintDir ..\sprints\S01 -TaskId T-001
# Exit code: 0 if ALL steps pass, 1 otherwise. Writes sprints\<S>\verify\<task>-latest.json.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintDir,
    [Parameter(Mandatory)][string]$TaskId,
    [int]$MaxOutputChars = 8000
)
$ErrorActionPreference = 'Stop'

$sprint = Get-Content (Join-Path $SprintDir 'sprint.json') -Raw | ConvertFrom-Json
$task = $sprint.tasks | Where-Object { $_.id -eq $TaskId }
if (-not $task) { throw "Task $TaskId not found" }
$artifactsDir = Join-Path (Resolve-Path $SprintDir) 'artifacts'

$results = @()
$allPass = $true
$stepNum = 0
foreach ($step in $task.verify) {
    $stepNum++
    $cwd = if ($step.cwd) { Join-Path $artifactsDir $step.cwd } else { $artifactsDir }
    $timeout = if ($step.timeoutSec) { [int]$step.timeoutSec } else { 300 }

    $stepResult = [ordered]@{
        step = $stepNum; cmd = $step.cmd; cwd = $step.cwd
        exitCode = $null; outputTail = ''; pass = $false; checks = @()
    }

    if (-not (Test-Path $cwd)) {
        $stepResult.checks += "FAIL cwd missing: $cwd"
        $stepResult.pass = $false
        $allPass = $false
        $results += [pscustomobject]$stepResult
        continue
    }

    # Run via a child powershell so $LASTEXITCODE and timeout are clean.
    # Output captured via process-level redirection: shell-level `2>&1 | Out-File`
    # would only bind to the LAST statement of multi-statement cmds.
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "' + ($step.cmd -replace '"','\"') + '; exit $LASTEXITCODE"'
        $psi.WorkingDirectory = $cwd
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($timeout * 1000)) {
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {} }
            $stepResult.checks += "FAIL timeout after ${timeout}s"
            $stepResult.exitCode = -1
            $allPass = $false
            $results += [pscustomobject]$stepResult
            continue
        }
        $stepResult.exitCode = $proc.ExitCode
        $output = ($outTask.Result + "`n" + $errTask.Result)
        if ($null -eq $output) { $output = '' }
        $stepResult.outputTail = if ($output.Length -gt $MaxOutputChars) { $output.Substring($output.Length - $MaxOutputChars) } else { $output }
    } catch {
        $stepResult.checks += "FAIL harness error: $($_.Exception.Message)"
        $allPass = $false
        $results += [pscustomobject]$stepResult
        continue
    }

    $pass = $true
    if ($null -ne $step.expectExitCode -and '' -ne "$($step.expectExitCode)") {
        if ($stepResult.exitCode -eq [int]$step.expectExitCode) { $stepResult.checks += "PASS exitCode == $($step.expectExitCode)" }
        else { $stepResult.checks += "FAIL exitCode $($stepResult.exitCode) != expected $($step.expectExitCode)"; $pass = $false }
    }
    if ($step.expectOutputContains) {
        if ($stepResult.outputTail -like "*$($step.expectOutputContains)*") { $stepResult.checks += "PASS output contains '$($step.expectOutputContains)'" }
        else { $stepResult.checks += "FAIL output missing '$($step.expectOutputContains)'"; $pass = $false }
    }
    if ($step.expectOutputNotContains) {
        if ($stepResult.outputTail -notlike "*$($step.expectOutputNotContains)*") { $stepResult.checks += "PASS output does not contain '$($step.expectOutputNotContains)'" }
        else { $stepResult.checks += "FAIL output CONTAINS forbidden '$($step.expectOutputNotContains)'"; $pass = $false }
    }
    $stepResult.pass = $pass
    if (-not $pass) { $allPass = $false }
    $results += [pscustomobject]$stepResult
}

$summary = [pscustomobject][ordered]@{
    taskId = $TaskId
    timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    allPass = $allPass
    steps = $results
}

$verifyDir = Join-Path $SprintDir 'verify'
New-Item -ItemType Directory -Force $verifyDir | Out-Null
$json = $summary | ConvertTo-Json -Depth 8
Set-Content (Join-Path $verifyDir "$TaskId-latest.json") $json -Encoding utf8
Add-Content (Join-Path $verifyDir "$TaskId-history.jsonl") ($summary | ConvertTo-Json -Depth 8 -Compress)

foreach ($r in $results) {
    $color = if ($r.pass) { 'Green' } else { 'Red' }
    Write-Host "[verify] step $($r.step) $(if($r.pass){'PASS'}else{'FAIL'}) exit=$($r.exitCode) :: $($r.cmd)" -ForegroundColor $color
    $r.checks | ForEach-Object { Write-Host "         $_" }
}
Write-Host "[verify] $TaskId overall: $(if($allPass){'PASS'}else{'FAIL'})" -ForegroundColor $(if($allPass){'Green'}else{'Red'})
exit $(if ($allPass) { 0 } else { 1 })
