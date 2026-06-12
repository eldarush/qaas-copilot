# preflight.ps1 - make sure the infra a scenario needs is up. Idempotent.
# Usage: .\preflight.ps1 -Needs rabbit,redis
param([string[]]$Needs = @())
$ErrorActionPreference = 'Stop'

function Ensure-Container([string]$name, [string]$runArgs) {
    $state = docker inspect -f '{{.State.Running}}' $name 2>$null
    if ($state -eq 'true') { Write-Host "[preflight] $name already running"; return }
    if ($LASTEXITCODE -eq 0) { docker start $name | Out-Null; Write-Host "[preflight] started existing $name"; return }
    Invoke-Expression "docker run -d --name $name $runArgs" | Out-Null
    Write-Host "[preflight] created $name"
}

foreach ($need in $Needs) {
    switch ($need) {
        'rabbit' {
            Ensure-Container 'qaas-lab-rabbit' '-p 5672:5672 -p 15672:15672 -e RABBITMQ_DEFAULT_USER=admin -e RABBITMQ_DEFAULT_PASS=admin rabbitmq:3-management'
            # wait for mgmt API
            $h = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('admin:admin')) }
            $deadline = (Get-Date).AddSeconds(90)
            while ($true) {
                try { Invoke-RestMethod -Uri 'http://127.0.0.1:15672/api/overview' -Headers $h | Out-Null; break }
                catch { if ((Get-Date) -gt $deadline) { throw '[preflight] rabbit mgmt API never ready' }; Start-Sleep 2 }
            }
            Write-Host '[preflight] rabbit ready'
        }
        'redis' {
            Ensure-Container 'qaas-lab-redis' '-p 6379:6379 redis:7-alpine'
            Write-Host '[preflight] redis ready'
        }
        default { throw "[preflight] unknown infra need: $need" }
    }
}
Write-Host '[preflight] all needs satisfied'
