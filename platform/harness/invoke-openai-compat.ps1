# invoke-openai-compat.ps1 - call any OpenAI-compatible /v1/chat/completions endpoint.
# This is the AIRGAP adapter: point it at your local MiniMax M2.7 server (vLLM / sglang /
# LM Studio / llama.cpp all expose this API). No internet required.
# Configure via env vars or params:
#   QAAS_LLM_BASE_URL   e.g. http://127.0.0.1:8000/v1      (required)
#   QAAS_LLM_MODEL      e.g. MiniMax-M2.7                  (required)
#   QAAS_LLM_API_KEY    optional (many local servers ignore it)
#   QAAS_LLM_EVAL_MODEL optional different model for -Role evaluator
# Usage (called by loop.ps1):
#   .\invoke-openai-compat.ps1 -ContextFile ctx.txt -ResponseFile out.txt -Role generator
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ContextFile,
    [Parameter(Mandatory)][string]$ResponseFile,
    [string]$Role = 'generator',
    [string]$BaseUrl = $env:QAAS_LLM_BASE_URL,
    [string]$Model = $env:QAAS_LLM_MODEL,
    [string]$ApiKey = $env:QAAS_LLM_API_KEY,
    [int]$MaxTokens = 16000,
    [double]$Temperature = 0.1,
    [int]$TimeoutSec = 1800
)
$ErrorActionPreference = 'Stop'
if (-not $BaseUrl) { throw 'Set QAAS_LLM_BASE_URL (e.g. http://127.0.0.1:8000/v1)' }
if (-not $Model)   { throw 'Set QAAS_LLM_MODEL (e.g. MiniMax-M2.7)' }
if ($Role -eq 'evaluator' -and $env:QAAS_LLM_EVAL_MODEL) { $Model = $env:QAAS_LLM_EVAL_MODEL }

$context = Get-Content $ContextFile -Raw
$body = @{
    model       = $Model
    temperature = $Temperature
    max_tokens  = $MaxTokens
    messages    = @(
        @{ role = 'user'; content = $context }
    )
} | ConvertTo-Json -Depth 6 -Compress

$headers = @{ 'Content-Type' = 'application/json' }
if ($ApiKey) { $headers['Authorization'] = "Bearer $ApiKey" }

$uri = $BaseUrl.TrimEnd('/') + '/chat/completions'
Write-Host "[invoke-openai] POST $uri model=$Model role=$Role" -ForegroundColor DarkCyan

$resp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec $TimeoutSec
$text = $resp.choices[0].message.content
if (-not $text) { throw 'Empty model response' }
# Strip <think>...</think> reasoning blocks some local models emit.
$text = [regex]::Replace($text, '(?ms)<think>.*?</think>\s*', '')
[System.IO.File]::WriteAllText($ResponseFile, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host "[invoke-openai] wrote $([math]::Round($text.Length/1kb))kb response" -ForegroundColor DarkCyan
exit 0
