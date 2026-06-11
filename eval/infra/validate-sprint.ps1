# validate-sprint.ps1 - structural validator for generated sprint.json (planning scenarios).
# Checks PROTOCOL §3 rules mechanically. Exit 0 = valid, 1 = violations (printed).
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$violations = @()
if (-not (Test-Path $Path)) { Write-Output "VIOLATION: file not found: $Path"; exit 1 }
try { $s = Get-Content $Path -Raw | ConvertFrom-Json }
catch { Write-Output "VIOLATION: invalid JSON: $($_.Exception.Message)"; exit 1 }

foreach ($f in 'sprintId', 'feature', 'goalOneSentence', 'tasks') {
    if (-not $s.$f) { $violations += "missing field: $f" }
}
if ($s.goalOneSentence) {
    $sentences = ([regex]::Matches($s.goalOneSentence.Trim(), '[.!?](\s|$)')).Count
    if ($sentences -gt 1) { $violations += "goalOneSentence has $sentences sentences" }
}
$ids = @{}
foreach ($t in $s.tasks) {
    $tid = $t.id
    if (-not $tid) { $violations += "task without id"; continue }
    $ids[$tid] = $t
    foreach ($f in 'title', 'skill', 'description') {
        if (-not $t.$f) { $violations += "${tid}: missing $f" }
    }
    if ($null -eq $t.priority) { $violations += "${tid}: missing priority" }
    if ($t.description -and $t.description.Length -lt 150) { $violations += "${tid}: description too short to be self-contained ($($t.description.Length) chars)" }
    if (-not $t.verify -or @($t.verify).Count -eq 0) { $violations += "${tid}: no verify[] steps" }
    else {
        foreach ($v in $t.verify) {
            if (-not $v.cmd) { $violations += "${tid}: verify step missing cmd" }
            $hasExpectation = ($null -ne $v.expectExitCode) -or $v.expectOutputContains -or $v.expectOutputNotContains
            if (-not $hasExpectation) { $violations += "${tid}: verify step has no mechanical expectation" }
        }
    }
    if (-not $t.acceptanceCriteria -or @($t.acceptanceCriteria).Count -eq 0) { $violations += "${tid}: no acceptanceCriteria" }
    if ($t.passes -ne $false) { $violations += "${tid}: passes must start false" }
    if ($t.description -match '\bsee T-\d+|\bas in T-\d+') { $violations += "${tid}: description references another task (not self-contained)" }
}
foreach ($t in $s.tasks) {
    foreach ($dep in @($t.dependsOn)) {
        if (-not $ids.ContainsKey($dep)) { $violations += "$($t.id): depends on unknown $dep" }
        elseif ([int]$ids[$dep].priority -gt [int]$t.priority) { $violations += "$($t.id): priority inversion vs $dep" }
    }
}

if ($violations.Count -eq 0) {
    Write-Output "SPRINT_VALID: $(@($s.tasks).Count) tasks OK"
    exit 0
} else {
    $violations | ForEach-Object { Write-Output "VIOLATION: $_" }
    exit 1
}
