# loop.ps1 - the sprint driver (Ralph-style outer loop).
# For each runnable task (passes=false, all deps passed, priority order):
#   assemble generator context -> invoke generator model -> apply output -> verify ->
#   assemble evaluator context -> invoke evaluator model -> parse verdict ->
#   PASS: flip passes=true, log. FAIL: write feedback, iterate (max -MaxIterations).
# Model invocation is pluggable: pass scripts that accept -ContextFile and -ResponseFile.
# Usage:
#   .\loop.ps1 -SprintDir ..\sprints\S01 `
#       -InvokeGenerator .\invoke-openai-compat.ps1 `
#       -InvokeEvaluator .\invoke-openai-compat.ps1 `
#       [-MaxIterations 3] [-SkipEvaluator] [-OneTask] [-TaskId T-001]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintDir,
    [Parameter(Mandatory)][string]$InvokeGenerator,
    [string]$InvokeEvaluator,
    [int]$MaxIterations = 3,
    [switch]$SkipEvaluator,
    [switch]$OneTask,
    [string]$TaskId = '',
    [string]$PlatformRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
$SprintDir = (Resolve-Path $SprintDir).Path
$sprintFile = Join-Path $SprintDir 'sprint.json'
if (-not (Test-Path $sprintFile)) { throw "No sprint.json in $SprintDir" }
if (-not $SkipEvaluator -and -not $InvokeEvaluator) { throw "Provide -InvokeEvaluator or use -SkipEvaluator" }
foreach ($d in 'context','responses','feedback','verify','artifacts') {
    New-Item -ItemType Directory -Force (Join-Path $SprintDir $d) | Out-Null
}

function Read-Sprint { Get-Content $sprintFile -Raw | ConvertFrom-Json }
function Save-Sprint($s) { $s | ConvertTo-Json -Depth 12 | Set-Content $sprintFile -Encoding utf8 }

function Update-State($sprint, [string]$status, [string]$currentTask, [string]$stoppedAt) {
    $done = @($sprint.tasks | Where-Object { $_.passes }).Count
    $state = @"
---
sprint: $($sprint.sprintId)
feature: $($sprint.feature)
status: $status
current_task: $currentTask
tasks_total: $($sprint.tasks.Count)
tasks_done: $done
last_activity: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
stopped_at: "$stoppedAt"
---
## Blockers
$(if ($status -eq 'needs_human') { "- $stoppedAt" } else { '(none)' })
"@
    Set-Content (Join-Path $SprintDir 'STATE.md') $state -Encoding utf8
}

function Add-TaskLog([string]$line) {
    $p = Join-Path $SprintDir 'progress.txt'
    if (-not (Test-Path $p)) { Set-Content $p "## Codebase Patterns`n`n## Task log" -Encoding utf8 }
    Add-Content $p "[$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mmZ'))] $line"
}

function Get-NextTask($sprint) {
    if ($TaskId) { return ($sprint.tasks | Where-Object { $_.id -eq $TaskId -and -not $_.passes }) }
    $passed = @($sprint.tasks | Where-Object { $_.passes } | ForEach-Object { $_.id })
    $sprint.tasks | Where-Object {
        -not $_.passes -and ($_.notes -notmatch 'NEEDS_HUMAN') -and
        (@($_.dependsOn | Where-Object { $_ -notin $passed }).Count -eq 0)
    } | Sort-Object priority | Select-Object -First 1
}

function Invoke-Model([string]$script, [string]$ctxFile, [string]$respFile, [string]$role) {
    Write-Host "[loop] invoking $role model ($([math]::Round((Get-Item $ctxFile).Length/1kb))kb context)..." -ForegroundColor Cyan
    # Model invocations flake transiently (rate limits, timeouts, network blips). A bare throw here
    # unwinds the whole trial (ErrorActionPreference=Stop) and loses all progress + the result file,
    # which is especially costly on the LAST task's evaluator call. Retry with backoff before giving up.
    $maxAttempts = 3
    for ($a = 1; $a -le $maxAttempts; $a++) {
        $code = 0
        try { & $script -ContextFile $ctxFile -ResponseFile $respFile -Role $role; $code = $LASTEXITCODE }
        catch { $code = -1; Write-Host "[loop] $role invocation threw: $($_.Exception.Message)" -ForegroundColor Yellow }
        if ($code -eq 0 -and (Test-Path $respFile)) { return }
        if ($a -lt $maxAttempts) {
            $wait = 5 * $a
            Write-Host "[loop] $role invocation attempt $a/$maxAttempts failed (exit=$code); retrying in ${wait}s..." -ForegroundColor Yellow
            Start-Sleep -Seconds $wait
        }
    }
    throw "$role model invocation failed after $maxAttempts attempts"
}

function Get-VerdictJson([string]$respFile) {
    $text = Get-Content $respFile -Raw
    $blocks = [regex]::Matches($text, '(?ms)```json\s*\r?\n(.*?)\r?\n```')
    for ($i = $blocks.Count - 1; $i -ge 0; $i--) {
        try {
            $v = $blocks[$i].Groups[1].Value | ConvertFrom-Json
            if ($v.verdict) { return $v }
        } catch { }
    }
    # Fallback: any {...} blob containing "verdict" (models sometimes skip the fence)
    $blobs = [regex]::Matches($text, '(?ms)\{.*?"verdict".*?\n\}')
    for ($i = $blobs.Count - 1; $i -ge 0; $i--) {
        try {
            $v = $blobs[$i].Value | ConvertFrom-Json
            if ($v.verdict) { return $v }
        } catch { }
    }
    # Last resort: malformed JSON (e.g. unescaped quotes in findings) - regex the
    # verdict + scores directly so a clearly-stated verdict is never lost.
    $m = [regex]::Match($text, '"verdict"\s*:\s*"(PASS|FAIL)"')
    if ($m.Success) {
        $scores = @{}
        foreach ($s in [regex]::Matches($text, '"(correctness|driftAvoidance|citations|completeness)"\s*:\s*(\d+)')) {
            $scores[$s.Groups[1].Value] = [int]$s.Groups[2].Value
        }
        Write-Host "[loop] NOTE: verdict JSON malformed - recovered verdict=$($m.Groups[1].Value) via regex" -ForegroundColor Yellow
        return [pscustomobject]@{
            verdict   = $m.Groups[1].Value
            scores    = [pscustomobject]$scores
            findings  = @()
            learnings = @()
            recovered = $true
        }
    }
    return $null
}

$assemble = Join-Path $PSScriptRoot 'assemble-context.ps1'
$apply    = Join-Path $PSScriptRoot 'apply-output.ps1'
$verifyPs = Join-Path $PSScriptRoot 'verify.ps1'

while ($true) {
    $sprint = Read-Sprint
    $task = Get-NextTask $sprint
    if (-not $task) {
        $open = @($sprint.tasks | Where-Object { -not $_.passes })
        if ($open.Count -eq 0) {
            Update-State $sprint 'done' '-' 'all tasks passed'
            Write-Host "[loop] SPRINT COMPLETE - all $($sprint.tasks.Count) tasks passed." -ForegroundColor Green
        } else {
            Update-State $sprint 'needs_human' '-' "$($open.Count) task(s) blocked/needs-human: $($open.id -join ', ')"
            Write-Host "[loop] HALT - no runnable tasks; open: $($open.id -join ', ')" -ForegroundColor Yellow
        }
        break
    }

    $tid = $task.id
    Write-Host "`n[loop] ===== TASK $tid : $($task.title) (iteration $([int]$task.iterations + 1)/$MaxIterations) =====" -ForegroundColor Magenta
    Update-State $sprint 'executing' $tid "generating $tid"

    if ([int]$task.iterations -ge $MaxIterations) {
        $task.notes = "NEEDS_HUMAN: exceeded $MaxIterations iterations"
        Save-Sprint $sprint
        Add-TaskLog "$tid NEEDS_HUMAN - exceeded $MaxIterations iterations"
        Update-State $sprint 'needs_human' $tid "$tid exceeded max iterations"
        if ($OneTask -or $TaskId) { break } else { continue }
    }

    # --- GENERATE (with one NEEDS_CONTEXT retry) ---
    $status = ''
    foreach ($attempt in 1..2) {
        $ctxFile  = Join-Path $SprintDir "context\$tid-gen-iter$($task.iterations).txt"
        $respFile = Join-Path $SprintDir "responses\$tid-gen-iter$($task.iterations)-a$attempt.txt"
        & $assemble -SprintDir $SprintDir -TaskId $tid -Role generator -OutFile $ctxFile -PlatformRoot $PlatformRoot | Out-Null
        Invoke-Model $InvokeGenerator $ctxFile $respFile 'generator'
        $status = (& $apply -SprintDir $SprintDir -ResponseFile $respFile -TaskId $tid | Select-Object -Last 1)
        Write-Host "[loop] generator status: $status" -ForegroundColor Cyan
        if ($status -match '^NEEDS_CONTEXT:\s*(\S+)' -and $attempt -eq 1) {
            $slice = $Matches[1].Trim(' .,')
            Write-Host "[loop] adding requested slice '$slice' and retrying once" -ForegroundColor Yellow
            $sprint = Read-Sprint; $task = $sprint.tasks | Where-Object { $_.id -eq $tid }
            if ($task.factBaseSlices -notcontains $slice) { $task.factBaseSlices = @($task.factBaseSlices) + $slice }
            Save-Sprint $sprint
            continue
        }
        # Channel-misroute rescue: a NEEDS_CLARIFICATION that names an FB slice (e.g. "FB s11")
        # is really a NEEDS_CONTEXT - the fact lives in a document the harness can inject. In
        # production the model would run /qaas:fact sNN itself; here the harness IS that
        # retrieval layer. Only rescue when clarification is NOT the task's designed outcome.
        if ($status -match '^NEEDS_CLARIFICATION' -and $status -match '\bs(\d{2})\b' -and
            $attempt -eq 1 -and $task.expectsClarification -ne $true) {
            $slice = 's' + $Matches[1]
            Write-Host "[loop] clarification names FB slice '$slice' - treating as NEEDS_CONTEXT, injecting and retrying once" -ForegroundColor Yellow
            $sprint = Read-Sprint; $task = $sprint.tasks | Where-Object { $_.id -eq $tid }
            if ($task.factBaseSlices -notcontains $slice) { $task.factBaseSlices = @($task.factBaseSlices) + $slice }
            Save-Sprint $sprint
            continue
        }
        break
    }

    # INVALID_STATUS = empty/garbled model output (a transient flake), NOT a deliberate signal.
    # Consume the iteration, leave a corrective nudge, and retry the task on the next loop pass
    # instead of escalating to a human. The iterations >= MaxIterations guard above bounds it.
    if ($status -match '^INVALID_STATUS') {
        $sprint = Read-Sprint; $task = $sprint.tasks | Where-Object { $_.id -eq $tid }
        $task.iterations = [int]$task.iterations + 1
        Save-Sprint $sprint
        $nudge = "## Harness note - your previous response was unusable`n" +
                 "It had no recognizable ``===FILE: <path>===`` blocks and no status line, so nothing " +
                 "could be applied. Re-read ctx.txt and emit the COMPLETE file(s) as ``===FILE: <relative/path>===`` " +
                 "blocks (full contents, no placeholders), then a final status line: DONE | DONE_WITH_CONCERNS: <note> | " +
                 "BLOCKED: <reason> | NEEDS_CONTEXT: <slice> | NEEDS_CLARIFICATION: <q>."
        Set-Content (Join-Path $SprintDir "feedback\$tid-iter$($task.iterations).md") $nudge -Encoding utf8
        Add-TaskLog "$tid retry - INVALID_STATUS (empty/unusable response), iterating"
        Update-State $sprint 'executing' $tid "$tid retry after empty response"
        Write-Host "[loop] generator returned empty/unusable output - retrying (iteration consumed)" -ForegroundColor Yellow
        continue
    }
    # Some tasks are DESIGNED to elicit a clarification rather than a guess: when a goal is
    # genuinely under-specified, the correct behavior is to ask, not to hallucinate. Such a task
    # sets "expectsClarification": true and treats a NEEDS_CLARIFICATION (with the questions
    # artifact) as the deliverable - so it falls through to verify+evaluate instead of halting.
    $clarificationIsSuccess = ($status -match '^NEEDS_CLARIFICATION') -and ($task.expectsClarification -eq $true)
    # One-shot workspace rescue: weak generators sometimes ask whether a prior task's artifact
    # exists, or where a schema key lives, when the answer is ALREADY in their context (the
    # CURRENT WORKSPACE FILES section shows every file on disk; FB slices show the schema). In
    # production an orchestrator/user would reply "look at your context". The harness gives that
    # reply exactly once per task; a second clarification still halts to a human.
    if (($status -match '^NEEDS_CLARIFICATION') -and -not $clarificationIsSuccess -and
        ([int]$task.iterations -lt ($MaxIterations - 1)) -and
        ($task.notes -notmatch 'WS_RESCUE_USED')) {
        $sprint = Read-Sprint; $task = $sprint.tasks | Where-Object { $_.id -eq $tid }
        $task.iterations = [int]$task.iterations + 1
        $task.notes = "WS_RESCUE_USED; " + $task.notes
        Save-Sprint $sprint
        $nudge = "## Harness note - your clarification is answerable from your own context`n" +
                 "You asked: $status`n`n" +
                 "Before asking, re-check these in ctx.txt:`n" +
                 "1. CURRENT WORKSPACE FILES - every file already on disk (including artifacts from prior tasks) is shown there verbatim. If a prior task's file appears there, it EXISTS - use its exact contents.`n" +
                 "2. The FACT BASE slices in context - field/key schemas live there. If a needed fact lives in a slice you don't have, emit NEEDS_CONTEXT: <sNN> (e.g. NEEDS_CONTEXT: s02) and the harness will inject it.`n" +
                 "Now execute the task: emit the COMPLETE file(s) as ===FILE: <path>=== blocks and end with a status line. Only emit NEEDS_CLARIFICATION again if the fact is genuinely absent from BOTH the workspace files and every available FB slice - in that case name precisely what is missing."
        Set-Content (Join-Path $SprintDir "feedback\$tid-iter$($task.iterations).md") $nudge -Encoding utf8
        Add-TaskLog "$tid retry - workspace rescue for premature clarification"
        Update-State $sprint 'executing' $tid "$tid workspace-rescue retry"
        Write-Host "[loop] ${tid}: NEEDS_CLARIFICATION looks self-answerable - one-shot workspace rescue, retrying" -ForegroundColor Yellow
        continue
    }
    if (($status -match '^(BLOCKED|NEEDS_CLARIFICATION|NEEDS_CONTEXT)') -and -not $clarificationIsSuccess) {
        $sprint = Read-Sprint; $task = $sprint.tasks | Where-Object { $_.id -eq $tid }
        $task.notes = "NEEDS_HUMAN: generator said $status"
        $task.iterations = [int]$task.iterations + 1
        Save-Sprint $sprint
        Add-TaskLog "$tid HALT - $status"
        Update-State $sprint 'needs_human' $tid "${tid}: $status"
        if ($OneTask -or $TaskId) { break } else { continue }
    }
    if ($clarificationIsSuccess) {
        Write-Host "[loop] ${tid}: NEEDS_CLARIFICATION is the EXPECTED outcome (expectsClarification) - verifying the clarification artifact + grading the questions" -ForegroundColor Cyan
    }

    # --- VERIFY (mechanical) ---
    Update-State $sprint 'verifying' $tid "verifying $tid"
    & $verifyPs -SprintDir $SprintDir -TaskId $tid
    $verifyPass = ($LASTEXITCODE -eq 0)

    # --- EVALUATE (strong model) ---
    $verdict = $null
    if (-not $SkipEvaluator) {
        $ectx  = Join-Path $SprintDir "context\$tid-eval-iter$($task.iterations).txt"
        $eresp = Join-Path $SprintDir "responses\$tid-eval-iter$($task.iterations).txt"
        & $assemble -SprintDir $SprintDir -TaskId $tid -Role evaluator -OutFile $ectx -PlatformRoot $PlatformRoot | Out-Null
        Invoke-Model $InvokeEvaluator $ectx $eresp 'evaluator'
        $verdict = Get-VerdictJson $eresp
        if (-not $verdict) { Write-Host "[loop] WARNING: evaluator emitted no verdict JSON - treating as FAIL" -ForegroundColor Yellow }
    }

    $evalPass = $SkipEvaluator -or ($verdict -and $verdict.verdict -eq 'PASS')
    $sprint = Read-Sprint; $task = $sprint.tasks | Where-Object { $_.id -eq $tid }
    $task.iterations = [int]$task.iterations + 1

    if ($verifyPass -and $evalPass) {
        $task.passes = $true
        $task.notes = "PASS iter=$($task.iterations) status=$status"
        Save-Sprint $sprint
        $learn = if ($verdict -and $verdict.learnings) { ' - learned: ' + ($verdict.learnings -join '; ') } else { '' }
        Add-TaskLog "$tid PASS iter=$($task.iterations)$learn"
        Write-Host "[loop] TASK $tid PASSED" -ForegroundColor Green
    } else {
        # Build feedback for the next generator iteration.
        $fb = [System.Collections.Generic.List[string]]::new()
        if (-not $verifyPass) {
            $vr = Get-Content (Join-Path $SprintDir "verify\$tid-latest.json") -Raw | ConvertFrom-Json
            $fb.Add('## Mechanical verify failures (fix these first)')
            foreach ($s in ($vr.steps | Where-Object { -not $_.pass })) {
                $fb.Add("- step $($s.step) ``$($s.cmd)`` exit=$($s.exitCode)")
                $s.checks | Where-Object { $_ -like 'FAIL*' } | ForEach-Object { $fb.Add("  - $_") }
                $tail = ($s.outputTail -split '\r?\n' | Select-Object -Last 25) -join "`n"
                $fb.Add("  - output tail:`n``````text`n$tail`n``````")
            }
        }
        if ($verdict -and $verdict.verdict -ne 'PASS') {
            $fb.Add('## Evaluator findings')
            foreach ($f in $verdict.findings) {
                $fb.Add("- [$($f.severity)] $($f.file): $($f.issue)`n  - suggested fix: $($f.suggestedFix)")
            }
        }
        Set-Content (Join-Path $SprintDir "feedback\$tid-iter$($task.iterations).md") ($fb -join "`n") -Encoding utf8
        $task.notes = "FAIL iter=$($task.iterations) verify=$verifyPass eval=$evalPass"
        Save-Sprint $sprint
        Add-TaskLog "$tid FAIL iter=$($task.iterations) verify=$verifyPass eval=$evalPass - feedback written"
        Write-Host "[loop] TASK $tid FAILED - feedback written, will iterate" -ForegroundColor Red
    }

    if ($OneTask -or $TaskId) { break }
}

$sprint = Read-Sprint
$done = @($sprint.tasks | Where-Object { $_.passes }).Count
Write-Host "`n[loop] exit: $done/$($sprint.tasks.Count) tasks passed." -ForegroundColor Cyan
exit $(if ($done -eq $sprint.tasks.Count) { 0 } else { 1 })
