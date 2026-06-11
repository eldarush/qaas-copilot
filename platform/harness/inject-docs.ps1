# inject-docs.ps1 - resolve Fact Base slice ids and docs-mirror paths to text.
# Usage:
#   .\inject-docs.ps1 -Slices s02,s13 [-DocPages qaas/quickStart/writeTestYaml.md] [-PlatformRoot ..]
# Output: concatenated content to stdout, with header separators.
[CmdletBinding()]
param(
    [string[]]$Slices = @(),
    [string[]]$DocPages = @(),
    [string]$PlatformRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$DocsMirror = $env:QAAS_DOCS_MIRROR
)
$ErrorActionPreference = 'Stop'

$factbase = Join-Path $PlatformRoot 'factbase'
if (-not (Test-Path $factbase)) { throw "factbase not found at $factbase" }

foreach ($slice in $Slices) {
    $file = Get-ChildItem $factbase -Filter "$slice-*.md" | Select-Object -First 1
    if (-not $file) { $file = Get-ChildItem $factbase -Filter "$slice*.md" | Select-Object -First 1 }
    if (-not $file) { throw "Fact Base slice '$slice' not found in $factbase" }
    "`n===== FACT BASE $($slice.ToUpper()) ($($file.Name)) ====="
    Get-Content $file.FullName -Raw
}

if ($DocPages.Count -gt 0) {
    if (-not $DocsMirror) { throw "DocPages requested but -DocsMirror / QAAS_DOCS_MIRROR not set" }
    foreach ($page in $DocPages) {
        $path = Join-Path $DocsMirror ($page -replace '/', '\')
        if (-not (Test-Path $path)) { throw "Doc page not found: $path" }
        "`n===== DOC PAGE docs/$page ====="
        Get-Content $path -Raw
    }
}
