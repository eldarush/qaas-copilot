$batches = Get-ChildItem .\batches\batch-*.md
$rows = @()
foreach ($b in $batches) {
  $cat = $b.BaseName -replace 'batch-',''
  $content = Get-Content $b.FullName -Raw
  $scenarios = [regex]::Matches($content, '(?ms)^### ([A-Z]-1\d\d): (.+?)$(.*?)(?=^### [A-Z]-1\d\d:|\z)')
  foreach ($m in $scenarios) {
    $id = $m.Groups[1].Value; $title = $m.Groups[2].Value.Trim(); $body = $m.Groups[3].Value
    $tier = if ($body -match '(?m)^\**Tier:?\**\s*:?\s*(T\d)') { $Matches[1] } else { '?' }
    $mock = if ($body -match '(?m)MOCK_REQUIRED:?\**\s*:?\s*(yes|no|n/a)') { $Matches[1] } else { '?' }
    $slices = if ($body -match '(?m)^\**FB slices:?\**\s*:?\s*(.+)$') { ($Matches[1] -replace '[^s0-9, ]','').Trim() } else { '' }
    $rows += [pscustomobject]@{ id=$id; category=$cat; tier=$tier; title=$title; mock=$mock; fbSlices=$slices }
  }
}
$rows | ConvertTo-Json -Depth 3 | Set-Content catalog.json -Encoding UTF8
"TOTAL: $($rows.Count)"
$rows | Group-Object category | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
"TIERS: " + (($rows | Group-Object tier | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ')
"MOCK: " + (($rows | Group-Object mock | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ')
$dupes = $rows | Group-Object id | Where-Object Count -gt 1
if ($dupes) { "DUPES: $($dupes.Name -join ',')" } else { "NO DUPLICATE IDS" }
