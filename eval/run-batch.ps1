# run-batch.ps1 - orchestrate and run a batch of evaluation scenarios in parallel.
# It spawns background processes to run .\run-trial.ps1, monitors progress, and outputs a summary.
#
# Usage:
#   .\run-batch.ps1 -ScenarioIds A01,A03,B03,B05,C02,C08,D03,D04,E01,F01 -MaxParallel 10
#   .\run-batch.ps1 -RunAll -MaxParallel 10
[CmdletBinding()]
param(
    [string[]]$ScenarioIds = @(),
    [switch]$RunAll,
    [int]$MaxParallel = 10,
    [string]$GeneratorModel = 'gpt-5-mini',
    [string]$EvaluatorModel = 'claude-sonnet-4.6',
    [int]$MaxIterations = 3,
    [switch]$SkipEvaluator
)

$ErrorActionPreference = 'Stop'
$evalRoot = $PSScriptRoot
$scenariosDir = Join-Path $evalRoot 'scenarios'

# 1. Resolve Scenario IDs
if ($RunAll) {
    $ScenarioIds = Get-ChildItem $scenariosDir -Directory | ForEach-Object {
        if ($_.Name -match '^([A-H]\d{2})-') { $Matches[1] } else { $_.Name }
    }
} elseif ($ScenarioIds.Count -eq 0) {
    # Default representative batch of 10 complex scenarios across all categories (A-G)
    $ScenarioIds = @('A01', 'A03', 'B03', 'B05', 'C02', 'C08', 'D03', 'D04', 'E01', 'F01')
}

Write-Host "==========================================================================" -ForegroundColor Green
Write-Host " QaaS Batch Evaluation Engine: Running $($ScenarioIds.Count) Scenarios ($MaxParallel Parallel)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "Generator model: $GeneratorModel" -ForegroundColor DarkCyan
Write-Host "Evaluator model: $(if($SkipEvaluator){'<skipped>'}else{$EvaluatorModel})" -ForegroundColor DarkCyan
Write-Host ""

$jobs = @()
$completedJobs = @()
$runningCount = 0
$index = 0

while ($index -lt $ScenarioIds.Count -or $jobs.Count -gt 0) {
    # Fill up pipeline up to MaxParallel
    while ($jobs.Count -lt $MaxParallel -and $index -lt $ScenarioIds.Count) {
        $id = $ScenarioIds[$index]
        $index++
        
        # Start background job using Start-Job to run run-trial.ps1
        Write-Host "[batch] Spawning background job for $id..." -ForegroundColor Yellow
        $scriptBlock = {
            param($evalRoot, $id, $gen, $eval, $maxIter, $skip)
            Set-Location $evalRoot
            $args = @{
                ScenarioId = $id
                GeneratorModel = $gen
                EvaluatorModel = $eval
                MaxIterations = $maxIter
            }
            if ($skip) { $args.SkipEvaluator = $true }
            .\run-trial.ps1 @args
        }
        
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $evalRoot, $id, $GeneratorModel, $EvaluatorModel, $MaxIterations, $SkipEvaluator -Name "QaaS-$id"
        $jobs += [pscustomobject]@{
            Id = $id
            Job = $job
            Started = (Get-Date)
        }
    }
    
    # Wait and check progress
    Start-Sleep -Seconds 5
    
    $activeJobs = @()
    foreach ($j in $jobs) {
        if ($j.Job.State -in @('Completed', 'Failed', 'Stopped')) {
            # Retrieve output to clear buffers
            Receive-Job -Job $j.Job | Out-Null
            $completedJobs += $j
            Write-Host "[batch] Job for $($j.Id) completed with state: $($j.Job.State)" -ForegroundColor Green
        } else {
            $activeJobs += $j
        }
    }
    $jobs = $activeJobs
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host " Batch Execution Completed. Aggregating Results..." -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green

# 2. Gather results from trial-result.json files under work/trials
$trialsRoot = Join-Path (Split-Path $evalRoot -Parent) 'work\trials'
$allResultFiles = Get-ChildItem $trialsRoot -Recurse -Filter 'trial-result.json' | Sort-Object LastWriteTime -Descending

# Map ScenarioId to latest result file
$results = @()
foreach ($id in $ScenarioIds) {
    $matchedFile = $allResultFiles | Where-Object { $_.Directory.Name -like "$id-*" -or $_.Directory.Name -eq $id } | Select-Object -First 1
    if ($matchedFile) {
        try {
            $json = Get-Content $matchedFile.FullName -Raw | ConvertFrom-Json
            $results += $json
        } catch {
            Write-Host "[batch] Error reading results for $id from $($matchedFile.FullName)" -ForegroundColor Red
        }
    } else {
        $results += [pscustomobject]@{
            scenario = $id
            pass = $false
            tasks = @()
            trialDir = "N/A"
            notes = "Result file not found"
        }
    }
}

# 3. Print Summary Report
$passedCount = @($results | Where-Object { $_.pass }).Count
$failedCount = $results.Count - $passedCount

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host " EVALUATION BATCH SUMMARY: $passedCount PASSED, $failedCount FAILED" -ForegroundColor $(if($failedCount -eq 0){'Green'}else{'Yellow'})
Write-Host "==========================================================================" -ForegroundColor Green

foreach ($r in $results) {
    $statusColor = if ($r.pass) { 'Green' } else { 'Red' }
    Write-Host "Scenario: $($r.scenario) => $(if($r.pass){'PASS'}else{'FAIL'})" -ForegroundColor $statusColor
    foreach ($t in $r.tasks) {
        Write-Host "  - Task $($t.id): $(if($t.passes){'PASS'}else{'FAIL'}) (Iter: $($t.iterations))" -ForegroundColor $(if($t.passes){'Gray'}else{'Red'})
    }
}

# 4. Generate batch markdown report
$batchReportFile = Join-Path $trialsRoot "batch-report-$((Get-Date -Format 'yyyyMMdd-HHmmss')).md"
$report = @"
# QaaS Batch Evaluation Summary Report

**Date**: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ssZ'))
**Generator Model**: $GeneratorModel
**Evaluator Model**: $EvaluatorModel
**Overall Stats**: $passedCount Passed, $failedCount Failed ($([math]::Round(($passedCount / $results.Count) * 100))% Pass Rate)

## Summary Table

| Scenario | Result | Tasks (Pass/Total) | Iterations | Notes / Trial Path |
| --- | --- | --- | --- | --- |
"@

foreach ($r in $results) {
    $totalTasks = $r.tasks.Count
    $passedTasks = @($r.tasks | Where-Object { $_.passes }).Count
    $totalIters = 0
    foreach ($t in $r.tasks) { $totalIters += $t.iterations }
    
    $report += "`n| $($r.scenario) | $(if($r.pass){'🟢 PASS'}{'🔴 FAIL'}) | $passedTasks / $totalTasks | $totalIters | $($r.trialDir) |"
}

Set-Content $batchReportFile $report -Encoding utf8
Write-Host ""
Write-Host "[batch] Batch summary report written to: $batchReportFile" -ForegroundColor Cyan

# Return exit code based on failures
if ($failedCount -gt 0) {
    exit 1
} else {
    exit 0
}
