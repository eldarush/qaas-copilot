# transform-relay.ps1 - P131 SUT: schema-evolution relay for RabbitMQ scenarios.
# Consumes from InputExchange, applies V1->V2 schema normalization, publishes to OutputExchange.
# V1: {"schemaVersion":1,"name":"X"} -> {"fullName":"X","migrated":true}
# V2: {"schemaVersion":2,"fullName":"X"} -> {"fullName":"X","migrated":false}
param(
    [string]$MgmtBase = "http://127.0.0.1:15672/api",
    [string]$InputExchange = "p131-input",
    [string]$OutputExchange = "p131-output",
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
Invoke-Mgmt PUT "/queues/%2F/p131-relay-tap" '{"auto_delete":true,"durable":false,"arguments":{}}' | Out-Null
Invoke-Mgmt POST "/bindings/%2F/e/$InputExchange/q/p131-relay-tap" ('{"routing_key":"' + $RoutingKey + '","arguments":{}}') | Out-Null
Write-Host "TRANSFORM-RELAY: topology ready ($InputExchange -> $OutputExchange), polling..."

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$relayed = 0
while ((Get-Date) -lt $deadline) {
    $msgs = Invoke-Mgmt POST "/queues/%2F/p131-relay-tap/get" '{"count":10,"ackmode":"ack_requeue_false","encoding":"auto","truncate":50000}'
    if ($msgs -and $msgs.Count -gt 0) {
        foreach ($m in $msgs) {
            try {
                $record = $m.payload | ConvertFrom-Json
                if ($record.schemaVersion -eq 1) {
                    $transformed = @{ fullName = $record.name; migrated = $true }
                } else {
                    $transformed = @{ fullName = $record.fullName; migrated = $false }
                }
                $payload = $transformed | ConvertTo-Json -Compress
                $publishBody = @{ properties = @{ content_type = "application/json" }; routing_key = $RoutingKey; payload = $payload; payload_encoding = "string" } | ConvertTo-Json -Compress
                Invoke-Mgmt POST "/exchanges/%2F/$OutputExchange/publish" $publishBody | Out-Null
                $relayed++
                Write-Host "TRANSFORM-RELAY: transformed message #$relayed (v=$($record.schemaVersion))"
            } catch {
                Write-Host "TRANSFORM-RELAY: failed to process message: $($_.Exception.Message)"
            }
        }
    } else { Start-Sleep -Milliseconds 500 }
}
Write-Host "TRANSFORM-RELAY: done, relayed=$relayed"
