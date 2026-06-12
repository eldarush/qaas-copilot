# sync-plugin.ps1 - MAINTAINER ONLY. Re-copy the canonical platform/ Fact Base and skills
# into the distributable plugin (plugins/qaas/) so the two never drift. The plugin's own
# qaas-overview master skill is plugin-only and is preserved (it has no platform/ source).
# Run after editing anything under platform/factbase or platform/skills.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$platform = Join-Path $repo 'platform'
$plugin = Join-Path $repo 'plugins\qaas'

# 1. Fact Base — full mirror
$dstFact = Join-Path $plugin 'factbase'
New-Item -ItemType Directory -Force $dstFact | Out-Null
Get-ChildItem (Join-Path $platform 'factbase') -Filter *.md | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dstFact $_.Name) -Force
}
Write-Host "[sync] factbase: $((Get-ChildItem $dstFact -Filter *.md).Count) slices" -ForegroundColor Green

# 2. Skills — mirror every platform skill; keep plugin-only skills (qaas-overview)
$dstSkills = Join-Path $plugin 'skills'
New-Item -ItemType Directory -Force $dstSkills | Out-Null
$copied = 0
foreach ($sk in Get-ChildItem (Join-Path $platform 'skills') -Directory) {
    $target = Join-Path $dstSkills $sk.Name
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item $sk.FullName $target -Recurse -Force
    $copied++
}
Write-Host "[sync] skills: $copied mirrored from platform (plugin-only skills preserved)" -ForegroundColor Green
Write-Host "[sync] done." -ForegroundColor Cyan
