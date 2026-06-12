# http-server.ps1 - minimal HTTP SUT for R131 scenario.
# Listens on 127.0.0.1:Port, responds 200 OK to every request, exits after TimeoutSec.
param(
    [int]$Port = 8211,
    [int]$TimeoutSec = 300
)
$ErrorActionPreference = "Stop"
$prefix = "http://127.0.0.1:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "HTTP-SERVER: listening on $prefix"

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$pending = $null
while ((Get-Date) -lt $deadline -and $listener.IsListening) {
    if ($null -eq $pending) { $pending = $listener.BeginGetContext($null, $null) }
    if (-not $pending.AsyncWaitHandle.WaitOne(1000)) { continue }
    $context = $listener.EndGetContext($pending)
    $pending = $null
    $response = $context.Response
    $response.StatusCode = 200
    $content = '{"status":"ok"}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    $response.ContentType = "application/json"
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.OutputStream.Close()
    Write-Host "HTTP-SERVER: served request to $($context.Request.Url)"
}
$listener.Stop()
Write-Host "HTTP-SERVER: stopped"
