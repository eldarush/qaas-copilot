# assemble-context.ps1 - build the exact generator (or evaluator) prompt for one task.
# Enforces the PROTOCOL §7 assembly order and the 120k-char budget. Fails loudly if over.
# Usage:
#   .\assemble-context.ps1 -SprintDir ..\sprints\S01 -TaskId T-001 [-Role generator|evaluator]
#                          [-OutFile ctx.txt] [-MaxChars 120000]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintDir,
    [Parameter(Mandatory)][string]$TaskId,
    [ValidateSet('generator','evaluator')][string]$Role = 'generator',
    [string]$OutFile,
    [int]$MaxChars = 120000,
    [string]$PlatformRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'

$sprintFile = Join-Path $SprintDir 'sprint.json'
$sprint = Get-Content $sprintFile -Raw | ConvertFrom-Json
$task = $sprint.tasks | Where-Object { $_.id -eq $TaskId }
if (-not $task) { throw "Task $TaskId not found in $sprintFile" }

$parts = [System.Collections.Generic.List[string]]::new()

# 1. persona
$personaFile = Join-Path $PlatformRoot "agents\$Role.md"
$parts.Add("===== PERSONA =====`n" + (Get-Content $personaFile -Raw))

# 2. constitution
$parts.Add("===== CONSTITUTION =====`n" + (Get-Content (Join-Path $PlatformRoot 'CONSTITUTION.md') -Raw))

# 3. codebase patterns (top section of progress.txt only)
$progressFile = Join-Path $SprintDir 'progress.txt'
if (Test-Path $progressFile) {
    $progress = Get-Content $progressFile -Raw
    $patterns = ($progress -split '## Task log')[0].Trim()
    if ($patterns) { $parts.Add("===== PATTERNS =====`n$patterns") }
}

# 4. state
$stateFile = Join-Path $SprintDir 'STATE.md'
if (Test-Path $stateFile) { $parts.Add("===== STATE =====`n" + (Get-Content $stateFile -Raw)) }

# 5. the task (full) + sprint goal
$taskJson = $task | ConvertTo-Json -Depth 10
$parts.Add("===== SPRINT GOAL =====`nFeature: $($sprint.feature)`nGoal: $($sprint.goalOneSentence)`nNon-goals: $($sprint.nonGoals -join '; ')")
$taskList = ($sprint.tasks | ForEach-Object { "  $($_.id): $($_.title)" }) -join "`n"
$parts.Add("===== SPRINT TASKS (look-ahead - scaffold/plan for the WHOLE sprint, not just this task) =====`n$taskList")
if ($sprint.portContract) {
    $parts.Add("===== PORT CONTRACT (MANDATORY - overrides the 8080 default in any Fact Base example) =====`n$($sprint.portContract)")
}
$parts.Add("===== YOUR TASK ($TaskId) =====`n$taskJson")

# 5b. the skill playbook for this task (generator only) - mirrors what the Claude Code plugin
# auto-invokes by description, so the trial faithfully tests the SKILL, not just the Fact Base.
if ($Role -eq 'generator' -and $task.skill) {
    $skillFile = Join-Path $PlatformRoot "skills\$($task.skill)\SKILL.md"
    if (Test-Path $skillFile) {
        $parts.Add("===== SKILL PLAYBOOK: $($task.skill) (follow its steps + done-rubric) =====`n" + (Get-Content $skillFile -Raw))
    }
}

# 6+7. fact base slices + doc pages
$slices = if ($task.factBaseSlices) { $task.factBaseSlices } else { $sprint.factBaseSlices }
$docPages = if ($task.docPages) { $task.docPages } else { @() }
$injectArgs = @{ Slices = $slices; PlatformRoot = $PlatformRoot }
if ($docPages.Count -gt 0) { $injectArgs.DocPages = $docPages }
$parts.Add((& (Join-Path $PSScriptRoot 'inject-docs.ps1') @injectArgs | Out-String))

# 7b. CURRENT WORKSPACE FILES (generator only) - the REAL files already on disk.
# An edit/diagnose task MUST see the actual file it will change (and its small siblings) so it
# makes a surgical fix and preserves every cross-file contract (routes, ports, stub/session names)
# VERBATIM, instead of reconstructing from memory. Without this the model either correctly refuses
# (NEEDS_CLARIFICATION: file not in context) or hallucinates a rewrite that breaks sibling contracts.
if ($Role -eq 'generator') {
    $artifactsDir = Join-Path $SprintDir 'artifacts'
    if (Test-Path $artifactsDir) {
        $editSet = @($task.files.edit) | Where-Object { $_ } | ForEach-Object { ($_ -replace '\\', '/').ToLower() }
        $textExt = @('.yaml', '.yml', '.json', '.cs', '.csproj', '.md', '.txt', '.props', '.targets', '.sh', '.ps1')
        # exclude build/output/tooling dirs - never show generated artifacts (bin/obj/project.assets.json,
        # *.g.cs, session-data, allure/test results) which are large and not part of the authored source.
        $excludeDir = @('\bin\', '\obj\', '\.git\', '\session-data\', '\allure-results\', '\allure-report\', '\testresults\', '\.vs\', '\node_modules\')
        $relOf = { param($full) $full.Substring($artifactsDir.Length).TrimStart('\', '/').Replace('\', '/') }
        $existing = Get-ChildItem $artifactsDir -Recurse -File | Where-Object {
            if (-not ($textExt -contains $_.Extension.ToLower() -or $_.Name -ieq 'Dockerfile')) { return $false }
            $p = $_.FullName.ToLower()
            foreach ($d in $excludeDir) { if ($p.Contains($d)) { return $false } }
            $true
        }
        # edit targets first (most important), then siblings alphabetically
        $existing = $existing | Sort-Object @{ Expression = { -not ($editSet -contains ((& $relOf $_.FullName).ToLower())) } }, FullName
        if ($existing) {
            $budgetPerFile = 12000
            $totalCap = 50000
            $running = 0
            $blocks = [System.Collections.Generic.List[string]]::new()
            foreach ($f in $existing) {
                $rel = & $relOf $f.FullName
                $isEdit = $editSet -contains $rel.ToLower()
                $tag = if ($isEdit) { '   <-- EDIT THIS FILE (minimal surgical change only; re-emit it complete)' } else { '   (sibling/context - do NOT rewrite unless your task lists it; its identifiers are contracts)' }
                $body = Get-Content $f.FullName -Raw
                if ($null -eq $body) { $body = '' }
                if ($body.Length -gt $budgetPerFile) { $body = $body.Substring(0, $budgetPerFile) + "`n<<...truncated for budget...>>" }
                if (-not $isEdit -and ($running + $body.Length) -gt $totalCap) { continue }
                $running += $body.Length
                $blocks.Add("===FILE: $rel===$tag`n$body`n===END FILE===")
            }
            $hdr = "===== CURRENT WORKSPACE FILES (the REAL files already on disk - edit THESE) =====`n" +
                   "These are the ACTUAL current contents in the workspace. For an edit/diagnose task: reproduce the failure mentally against these exact files, change ONLY what your task says to change, and PRESERVE every other identifier, route, port, stub name, session name, and field EXACTLY as shown - they are contracts shared with the sibling files below. Re-emit each changed file in full with ===FILE: path=== markers. If the real fact you need is genuinely absent here AND in the Fact Base, emit NEEDS_CLARIFICATION.`n" +
                   "CITATION RULE: when a task asks for file:line citations, count lines from line 1 of EACH FILE as shown between its ===FILE: path=== and ===END FILE=== markers - NEVER from this combined context document. Line 1 = the first line after the ===FILE: marker.`n`n"
            $parts.Add($hdr + ($blocks -join "`n`n"))
        }
    }
}

# 8. evaluator feedback from prior iteration (generator role only)
if ($Role -eq 'generator') {
    $iter = [int]$task.iterations
    if ($iter -gt 0) {
        $fb = Join-Path $SprintDir "feedback\$TaskId-iter$iter.md"
        if (Test-Path $fb) {
            $reviseNote = @'


----- HOW TO REVISE (do not regress) -----
Your previous attempt was close. Re-emit the COMPLETE file(s) for this task, KEEPING everything that already worked and changing ONLY what the findings above call out. Do not drop fields, rename files, or rewrite passing sections. If the output is JSON, the whole file must still parse as valid JSON: never paste raw double-quote characters inside a string value (use single quotes, or backslash-escape the quotes). Fix the named findings and nothing else.
'@
            $parts.Add("===== EVALUATOR FEEDBACK (iteration $iter - FIX THESE) =====`n" + (Get-Content $fb -Raw) + $reviseNote)
        }
    }
    $parts.Add("===== INSTRUCTION =====`nExecute task $TaskId now. Follow the persona phases. Emit complete files with ===FILE: path=== markers. End with a status code on the last line.")
} else {
    # evaluator also gets the generated artifacts + verify results
    $artifactsDir = Join-Path $SprintDir 'artifacts'
    # Real file tree first: the evaluator must judge existence claims against the ACTUAL
    # workspace, not just the pack-declared paths (generators may legitimately organize
    # data files differently, e.g. subfolder-per-DataSource).
    if (Test-Path $artifactsDir) {
        $excludeDirEval = @('\bin\', '\obj\', '\.git\', '\session-data\', '\allure-results\', '\allure-report\', '\testresults\', '\.vs\', '\node_modules\')
        $tree = Get-ChildItem $artifactsDir -Recurse -File | Where-Object {
            $p = $_.FullName.ToLower(); -not ($excludeDirEval | Where-Object { $p.Contains($_) })
        } | ForEach-Object { $_.FullName.Substring($artifactsDir.Length).TrimStart('\', '/').Replace('\', '/') } | Sort-Object
        if ($tree) {
            $parts.Add("===== ACTUAL WORKSPACE FILE TREE (harness-listed, trusted - judge existence against THIS, not assumptions) =====`n" + ($tree -join "`n"))
        }
    }
    $fileList = @($task.files.create) + @($task.files.edit) | Where-Object { $_ }
    foreach ($f in $fileList) {
        $p = Join-Path $artifactsDir $f
        if (Test-Path $p) {
            $parts.Add("===== GENERATED ARTIFACT: $f =====`n" + (Get-Content $p -Raw))
        } else {
            $parts.Add("===== GENERATED ARTIFACT: $f =====`n<<not at the declared path - CHECK THE FILE TREE above; an equivalent file elsewhere may satisfy the intent (grade location vs task contract, but do NOT claim a file that IS in the tree does not exist)>>")
        }
    }
    $verifyResults = Join-Path $SprintDir "verify\$TaskId-latest.json"
    if (Test-Path $verifyResults) {
        $parts.Add("===== MECHANICAL VERIFY RESULTS (harness-run, trusted) =====`n" + (Get-Content $verifyResults -Raw))
    }
    $parts.Add("===== INSTRUCTION =====`nEvaluate task $TaskId now. Assume bugs exist. End with the verdict JSON fenced block.")
}

$context = ($parts -join "`n`n")
$len = $context.Length
if ($len -gt $MaxChars) {
    throw "Context budget exceeded: $len chars > $MaxChars. Narrow factBaseSlices/docPages for $TaskId (never trim CONSTITUTION or task)."
}

Write-Host "[assemble-context] $Role/$TaskId : $len chars ($([math]::Round($len/$MaxChars*100,1))% of budget)" -ForegroundColor Cyan
if ($OutFile) { Set-Content $OutFile $context -Encoding utf8; Write-Output $OutFile }
else { Write-Output $context }
