# topology.ps1 - creates the three-level DLQ cascade topology for Q134.
# Creates 3 exchanges, 3 queues (with x-message-ttl + x-dead-letter-exchange), and 3 bindings.
# Exchange prefix: q134-  Queue prefix: q134-
# Run once before the QaaS runner; exits 0 on success, 1 on failure.
param(
    [string]$MgmtBase = "http://127.0.0.1:15672/api"
)
$ErrorActionPreference = "Stop"
$pair = "admin:admin"
$headers = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair)) }

function Invoke-Mgmt([string]$Method, [string]$Path, [string]$Body) {
    $params = @{ Method = $Method; Uri = "$MgmtBase$Path"; Headers = $headers; ContentType = "application/json" }
    if ($Body) { $params.Body = $Body }
    Invoke-RestMethod @params
}

$deadline = (Get-Date).AddSeconds(60)
while ($true) {
    try { Invoke-Mgmt GET "/overview" | Out-Null; break }
    catch { if ((Get-Date) -gt $deadline) { Write-Host "TOPOLOGY: RabbitMQ mgmt API never ready"; exit 1 }; Start-Sleep 2 }
}
Write-Host "TOPOLOGY: broker ready, creating topology..."

$exDef = '{"type":"direct","auto_delete":false,"durable":true,"internal":false,"arguments":{}}'
Invoke-Mgmt PUT "/exchanges/%2F/q134-src-ex" $exDef | Out-Null
Invoke-Mgmt PUT "/exchanges/%2F/q134-dlx1-ex" $exDef | Out-Null
Invoke-Mgmt PUT "/exchanges/%2F/q134-dlx2-ex" $exDef | Out-Null
Write-Host "TOPOLOGY: exchanges created"

$srcQDef  = '{"auto_delete":false,"durable":true,"arguments":{"x-message-ttl":500,"x-dead-letter-exchange":"q134-dlx1-ex"}}'
$dlq1Def  = '{"auto_delete":false,"durable":true,"arguments":{"x-message-ttl":500,"x-dead-letter-exchange":"q134-dlx2-ex"}}'
$dlq2Def  = '{"auto_delete":false,"durable":true,"arguments":{}}'
Invoke-Mgmt PUT "/queues/%2F/q134-source-q" $srcQDef  | Out-Null
Invoke-Mgmt PUT "/queues/%2F/q134-dlq1-q"  $dlq1Def  | Out-Null
Invoke-Mgmt PUT "/queues/%2F/q134-dlq2-q"  $dlq2Def  | Out-Null
Write-Host "TOPOLOGY: queues created"

$bndDef = '{"routing_key":"source","arguments":{}}'
Invoke-Mgmt POST "/bindings/%2F/e/q134-src-ex/q/q134-source-q"  $bndDef | Out-Null
Invoke-Mgmt POST "/bindings/%2F/e/q134-dlx1-ex/q/q134-dlq1-q"  $bndDef | Out-Null
Invoke-Mgmt POST "/bindings/%2F/e/q134-dlx2-ex/q/q134-dlq2-q"  $bndDef | Out-Null
Write-Host "TOPOLOGY: bindings created"

Write-Host "TOPOLOGY: done - q134-source-q(TTL=500ms->dlx1) -> q134-dlq1-q(TTL=500ms->dlx2) -> q134-dlq2-q"
exit 0

