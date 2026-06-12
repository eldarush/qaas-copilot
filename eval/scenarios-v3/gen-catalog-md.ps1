$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$rows = Get-Content catalog.json -Raw | ConvertFrom-Json
$md = @()
$md += '# Scenario Catalog v3 - 500 Advanced Scenarios'
$md += ''
$md += "Generated from batches/ on $(Get-Date -Format yyyy-MM-dd). Tiers: T3 hard / T4 expert / T5 almost-impossible."
$md += ''
$md += '| Category | Count | T3 | T4 | T5 | Focus |'
$md += '|---|---|---|---|---|---|'
$focus = @{ R='Advanced runner YAML (no mocker)'; M='Advanced mocker estates'; H='Custom C# hooks'; Q='Messaging/broker topology'; P='Parsing/ETL transformation contracts'; D='Docker/offline/CI'; X='Failure forensics (multi-bug)'; N='Planning/interrogation'; A='Analysis (SUT/Helm/tests)'; Z='Impossible integration (all-T5)' }
foreach ($g in ($rows | Group-Object category | Sort-Object Name)) {
  $t3 = @($g.Group | Where-Object tier -eq 'T3').Count
  $t4 = @($g.Group | Where-Object tier -eq 'T4').Count
  $t5 = @($g.Group | Where-Object tier -eq 'T5').Count
  $md += "| $($g.Name) | $($g.Count) | $t3 | $t4 | $t5 | $($focus[$g.Name]) |"
}
$md += ''
$md += "Total: $($rows.Count) scenarios. Full text in batches/batch-<cat>.md; machine-readable index in catalog.json."
$md += ''
foreach ($g in ($rows | Group-Object category | Sort-Object Name)) {
  $md += "## Category $($g.Name) - $($focus[$g.Name])"
  $md += ''
  $md += '| ID | Tier | Title |'
  $md += '|---|---|---|'
  foreach ($r in $g.Group) { $md += "| $($r.id) | $($r.tier) | $($r.title -replace '\|','/') |" }
  $md += ''
}
$md -join "`n" | Set-Content CATALOG.md -Encoding UTF8
"CATALOG.md written: $((Get-Item CATALOG.md).Length) bytes"
