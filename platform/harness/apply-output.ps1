# apply-output.ps1 - parse a generator response: write ===FILE: path=== blocks to artifacts/,
# extract the status code (last line), and report. PROTOCOL §1/§2.
# Usage:
#   .\apply-output.ps1 -SprintDir ..\sprints\S01 -ResponseFile response.txt [-TaskId T-001]
# Output (stdout): the status code line. Exit 0 unless parsing failed entirely.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintDir,
    [Parameter(Mandatory)][string]$ResponseFile,
    [string]$TaskId = ''
)
$ErrorActionPreference = 'Stop'

$text = Get-Content $ResponseFile -Raw
$artifactsDir = Join-Path $SprintDir 'artifacts'
New-Item -ItemType Directory -Force $artifactsDir | Out-Null

# Write file blocks. Weak models sometimes emit the SAME path twice (full content,
# then a short self-referential placeholder like "see above"). Last-write-wins would
# destroy good content - instead keep the LONGEST body per path and warn.
$pattern = '(?ms)^===FILE:\s*(?<path>[^=\r\n]+?)\s*===\r?\n(?<body>.*?)\r?\n===END FILE==='
$matches = [regex]::Matches($text, $pattern)
$byPath = [ordered]@{}
$dupes = @()
foreach ($m in $matches) {
    $rel = $m.Groups['path'].Value.Trim() -replace '/', '\'
    if ($rel -match '\.\.') { Write-Warning "Skipping path traversal: $rel"; continue }
    $body = $m.Groups['body'].Value
    if ($byPath.Contains($rel)) {
        $dupes += $rel
        if ($body.Length -le $byPath[$rel].Length) { continue }  # keep longer
    }
    $byPath[$rel] = $body
}
$written = @()
foreach ($rel in $byPath.Keys) {
    $dest = Join-Path $artifactsDir $rel
    New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
    [System.IO.File]::WriteAllText($dest, $byPath[$rel], [System.Text.UTF8Encoding]::new($false))
    $written += $rel
}
if ($dupes.Count) {
    Write-Host "[apply-output] WARNING: duplicate FILE blocks for $($dupes -join ', ') - kept longest body" -ForegroundColor Yellow
}

# Extract status code: scan the last 10 non-empty lines (weak models sometimes put
# the code slightly above trailing commentary). Postel's law: be lenient in.
$lines = @($text -split '\r?\n' | Where-Object { $_.Trim() })
$statusLine = ''
$tail = $lines | Select-Object -Last 10
for ($i = $tail.Count - 1; $i -ge 0; $i--) {
    $t = $tail[$i].Trim()
    if ($t -match '^(?:\*\*|`)?(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT|NEEDS_CLARIFICATION)\b') {
        $statusLine = $t -replace '^[\*`\s]+', '' -replace '[\*`\s]+$', ''
        break
    }
}
$validStatus = [bool]$statusLine

Write-Host "[apply-output] wrote $($written.Count) file(s): $($written -join ', ')" -ForegroundColor Cyan
if (-not $validStatus) {
    if ($written.Count -gt 0) {
        # Files arrived but no status line - infer, flag the concern, keep the loop moving.
        Write-Host "[apply-output] WARNING: no status code in last 10 lines; inferring DONE_WITH_CONCERNS" -ForegroundColor Yellow
        $statusLine = 'DONE_WITH_CONCERNS: generator omitted status line'
    } else {
        Write-Host "[apply-output] WARNING: no files and no valid status code" -ForegroundColor Yellow
        $statusLine = 'INVALID_STATUS'
    }
}
if ($TaskId) {
    $log = Join-Path $SprintDir 'responses'
    New-Item -ItemType Directory -Force $log | Out-Null
    Copy-Item $ResponseFile (Join-Path $log "$TaskId-$(Get-Date -Format yyyyMMdd-HHmmss).txt")
}
Write-Output $statusLine
