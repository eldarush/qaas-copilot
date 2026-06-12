# relay.ps1 - simulated System-Under-Test for RabbitMQ scenarios.
# Taps an input exchange via the RabbitMQ management API and republishes every message
# to an output exchange (PowerShell port of the QaaS DummyApp CI relay).
param(
    [string]$MgmtBase = "http://127.0.0.1:15672/api",
    [string]$InputExchange = "dummy-app-tests-input",
    [string]$OutputExchange = "dummy-app-tests-output",
    [string]$RoutingKey = "/",
    [int]$TimeoutSec = 120
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
    catch { if ((Get-Date) -gt $deadline) { throw "RabbitMQ mgmt API never ready" }; Start-Sleep 2 }
}

$exDef = '{"type":"direct","auto_delete":false,"durable":false,"internal":false,"arguments":{}}'
Invoke-Mgmt PUT "/exchanges/%2F/$InputExchange" $exDef | Out-Null
Invoke-Mgmt PUT "/exchanges/%2F/$OutputExchange" $exDef | Out-Null
Invoke-Mgmt PUT "/queues/%2F/relay-tap" '{"auto_delete":true,"durable":false,"arguments":{}}' | Out-Null
Invoke-Mgmt POST "/bindings/%2F/e/$InputExchange/q/relay-tap" ('{"routing_key":"' + $RoutingKey + '","arguments":{}}') | Out-Null
Write-Host "RELAY: topology ready ($InputExchange -> $OutputExchange), polling..."

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$relayed = 0
while ((Get-Date) -lt $deadline) {
    $msgs = Invoke-Mgmt POST "/queues/%2F/relay-tap/get" '{"count":10,"ackmode":"ack_requeue_false","encoding":"auto","truncate":50000}'
    if ($msgs -and $msgs.Count -gt 0) {
        foreach ($m in $msgs) {
            $publishBody = @{ properties = @{ content_type = "application/json" }; routing_key = $RoutingKey; payload = $m.payload; payload_encoding = "string" } | ConvertTo-Json -Compress
            Invoke-Mgmt POST "/exchanges/%2F/$OutputExchange/publish" $publishBody | Out-Null
            $relayed++
            Write-Host "RELAY: relayed message #$relayed"
        }
    } else { Start-Sleep -Milliseconds 500 }
}
Write-Host "RELAY: done, relayed=$relayed"
