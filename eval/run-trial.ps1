# run-trial.ps1 - run one eval scenario end-to-end with a weak generator + strong evaluator.
# Flow: locate scenario pack -> fresh trial dir -> preflight infra -> seed artifacts ->
#       loop.ps1 (trial invokers) -> record result JSON.
# Usage:
#   .\run-trial.ps1 -ScenarioId A01 [-GeneratorModel gpt-5-mini] [-EvaluatorModel claude-sonnet-4.6]
#                   [-MaxIterations 3] [-SkipEvaluator] [-TrialsRoot ..\work\trials]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScenarioId,
    [string]$GeneratorModel = $(if ($env:QAAS_TRIAL_MODEL) { $env:QAAS_TRIAL_MODEL } else { 'gpt-5-mini' }),
    [string]$EvaluatorModel = $(if ($env:QAAS_TRIAL_EVAL_MODEL) { $env:QAAS_TRIAL_EVAL_MODEL } else { 'claude-sonnet-4.6' }),
    [int]$MaxIterations = 3,
    [switch]$SkipEvaluator,
    [string]$TrialsRoot = ''
)
$ErrorActionPreference = 'Stop'
$evalRoot = $PSScriptRoot
if (-not $TrialsRoot) {
    $TrialsRoot = Join-Path (Split-Path $evalRoot -Parent) 'work\trials'
}
$platformRoot = Join-Path (Split-Path $evalRoot -Parent) 'platform'
$harness = Join-Path $platformRoot 'harness'

# 1. Locate scenario pack
$pack = Get-ChildItem (Join-Path $evalRoot 'scenarios') -Directory | Where-Object { $_.Name -like "$ScenarioId-*" -or $_.Name -eq $ScenarioId } | Select-Object -First 1
if (-not $pack) { throw "Scenario pack $ScenarioId not found under eval\scenarios" }
if (-not (Test-Path (Join-Path $pack.FullName 'sprint.json'))) { throw "Scenario $($pack.Name) has no sprint.json" }

# 2. Fresh trial dir
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$trialDir = Join-Path $TrialsRoot "$($pack.Name)-$stamp"
foreach ($d in '', 'artifacts', 'context', 'responses', 'feedback', 'verify') {
    New-Item -ItemType Directory -Force (Join-Path $trialDir $d) | Out-Null
}
Copy-Item (Join-Path $pack.FullName 'sprint.json') (Join-Path $trialDir 'sprint.json')
Copy-Item (Join-Path $platformRoot 'templates\progress.txt.template') (Join-Path $trialDir 'progress.txt')

# 3. Seed artifacts (broken configs for diagnose scenarios, prebuilt projects, etc.)
$seed = Join-Path $pack.FullName 'seed'
if (Test-Path $seed) {
    Copy-Item "$seed\*" (Join-Path $trialDir 'artifacts') -Recurse -Force
    Write-Host "[run-trial] seeded artifacts from $seed"
}

# 4. Preflight infra
$infraFile = Join-Path $pack.FullName 'infra.json'
if (Test-Path $infraFile) {
    $infra = Get-Content $infraFile -Raw | ConvertFrom-Json
    if ($infra.needs) { & (Join-Path $evalRoot 'infra\preflight.ps1') -Needs $infra.needs }
}

# 5. Run the loop with trial invokers
$env:QAAS_TRIAL_MODEL = $GeneratorModel
$env:QAAS_TRIAL_EVAL_MODEL = $EvaluatorModel
Write-Host "[run-trial] $($pack.Name): generator=$GeneratorModel evaluator=$(if($SkipEvaluator){'<skipped>'}else{$EvaluatorModel})" -ForegroundColor Magenta
$loopArgs = @{
    SprintDir = $trialDir
    InvokeGenerator = (Join-Path $harness 'invoke-copilot-cli.ps1')
    MaxIterations = $MaxIterations
    PlatformRoot = $platformRoot
}
if ($SkipEvaluator) { $loopArgs.SkipEvaluator = $true } else { $loopArgs.InvokeEvaluator = (Join-Path $harness 'invoke-copilot-cli.ps1') }
# Never let a loop throw (e.g. an unrecoverable model invocation) abort the trial without a result
# file - record whatever per-task progress loop.ps1 persisted to sprint.json so trials are always
# auditable and the batch matrix never has silent holes.
$loopExit = 1
try {
    & (Join-Path $harness 'loop.ps1') @loopArgs
    $loopExit = $LASTEXITCODE
} catch {
    Write-Host "[run-trial] loop aborted: $($_.Exception.Message)" -ForegroundColor Red
    $loopExit = 1
}

# 6. Record result
$sprint = Get-Content (Join-Path $trialDir 'sprint.json') -Raw | ConvertFrom-Json
$result = [pscustomobject][ordered]@{
    scenario = $pack.Name
    trialDir = $trialDir
    generator = $GeneratorModel
    evaluator = $(if ($SkipEvaluator) { $null } else { $EvaluatorModel })
    timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    pass = ($loopExit -eq 0)
    tasks = @($sprint.tasks | ForEach-Object {
        [pscustomobject]@{ id = $_.id; passes = $_.passes; iterations = $_.iterations; notes = $_.notes }
    })
}
$result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $trialDir 'trial-result.json') -Encoding utf8
Write-Host "`n[run-trial] $($pack.Name) => $(if($result.pass){'PASS'}else{'FAIL'}) ($trialDir)" -ForegroundColor $(if($result.pass){'Green'}else{'Red'})
$result | ConvertTo-Json -Depth 6
exit $loopExit
