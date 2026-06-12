# new-sprint.ps1 - instantiate a sprint directory from templates.
# Usage:
#   .\new-sprint.ps1 -SprintsRoot ..\..\sprints -SprintId S01 [-Feature "HTTP smoke test"]
# Then: edit sprint.json (or have the planner agent fill it), and run loop.ps1.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintsRoot,
    [Parameter(Mandatory)][string]$SprintId,
    [string]$Feature = '',
    [string]$PlatformRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $SprintsRoot $SprintId
if (Test-Path (Join-Path $dir 'sprint.json')) { throw "Sprint $SprintId already exists at $dir" }
foreach ($d in '', 'artifacts', 'context', 'responses', 'feedback', 'verify') {
    New-Item -ItemType Directory -Force (Join-Path $dir $d) | Out-Null
}
$tpl = Join-Path $PlatformRoot 'templates'

$sprint = Get-Content (Join-Path $tpl 'sprint.json.template') -Raw | ConvertFrom-Json
$sprint.sprintId = $SprintId
$sprint.feature = $Feature
$sprint | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $dir 'sprint.json') -Encoding utf8

(Get-Content (Join-Path $tpl 'STATE.md.template') -Raw) `
    -replace '\{\{SPRINT\}\}', $SprintId -replace '\{\{FEATURE\}\}', $Feature |
    Set-Content (Join-Path $dir 'STATE.md') -Encoding utf8
Copy-Item (Join-Path $tpl 'progress.txt.template') (Join-Path $dir 'progress.txt')

Write-Host "[new-sprint] created $dir - edit sprint.json (or run the planner) then loop.ps1" -ForegroundColor Green
Write-Output $dir
