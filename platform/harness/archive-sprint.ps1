# archive-sprint.ps1 - close a sprint: zip transcripts, keep artifacts + learnings.
# Usage:
#   .\archive-sprint.ps1 -SprintDir ..\..\sprints\S01
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintDir
)
$ErrorActionPreference = 'Stop'
$SprintDir = (Resolve-Path $SprintDir).Path
$name = Split-Path $SprintDir -Leaf
$zip = Join-Path $SprintDir "transcripts-$name.zip"

$toZip = @('context', 'responses') | ForEach-Object { Join-Path $SprintDir $_ } | Where-Object { Test-Path $_ }
if ($toZip) {
    Compress-Archive -Path $toZip -DestinationPath $zip -Force
    $toZip | Remove-Item -Recurse -Force
    Write-Host "[archive-sprint] zipped transcripts -> $zip" -ForegroundColor Green
}

# Surface learnings for the insighter / next sprint.
$progress = Join-Path $SprintDir 'progress.txt'
if (Test-Path $progress) {
    Write-Host "`n--- Task log (feed to insighter agent) ---"
    (Get-Content $progress -Raw) -split '## Task log' | Select-Object -Last 1 | Write-Host
}
Write-Host "[archive-sprint] kept: artifacts/, feedback/, verify/, sprint.json, STATE.md, progress.txt" -ForegroundColor Green
