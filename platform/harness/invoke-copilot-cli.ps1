# invoke-copilot-cli.ps1 - TRIAL adapter: run a prompt through the GitHub Copilot CLI
# with a chosen model, simulating the airgapped weak model. The model gets ONLY the
# assembled context file (sandbox cwd, view+create tools only - no shell, no web).
# Env overrides:
#   QAAS_TRIAL_MODEL       generator model (default gpt-5-mini)
#   QAAS_TRIAL_EVAL_MODEL  evaluator model (default claude-sonnet-4.6)
# Usage (called by loop.ps1):
#   .\invoke-copilot-cli.ps1 -ContextFile ctx.txt -ResponseFile out.txt -Role generator
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ContextFile,
    [Parameter(Mandatory)][string]$ResponseFile,
    [string]$Role = 'generator',
    [string]$Model = '',
    [int]$TimeoutSec = $(if ($env:QAAS_TRIAL_TIMEOUT_SEC) { [int]$env:QAAS_TRIAL_TIMEOUT_SEC } else { 600 })
)
$ErrorActionPreference = 'Stop'
if (-not $Model) {
    $Model = if ($Role -eq 'evaluator') {
        if ($env:QAAS_TRIAL_EVAL_MODEL) { $env:QAAS_TRIAL_EVAL_MODEL } else { 'claude-sonnet-4.6' }
    } else {
        if ($env:QAAS_TRIAL_MODEL) { $env:QAAS_TRIAL_MODEL } else { 'gpt-5-mini' }
    }
}

$sandbox = Join-Path $env:TEMP ("qaas-trial-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $sandbox | Out-Null
try {
    Copy-Item $ContextFile (Join-Path $sandbox 'ctx.txt')
    $prompt = 'Read the file ctx.txt in the current working directory. It contains your persona, rules, and one task. ' +
              'Produce your COMPLETE response (all phases, all ===FILE: ...=== blocks or verdict JSON, and the final status line) ' +
              'as plain text written to a new file named response.txt in the current working directory. ' +
              'Do NOT create any other files. Do NOT run commands. Your entire answer goes inside response.txt.'

    $argStr = "-p `"$prompt`" -s --model $Model --no-custom-instructions --no-ask-user --log-level none " +
              "--available-tools view --available-tools create --available-tools edit --allow-all-tools --allow-all-paths"
    $respInSandbox = Join-Path $sandbox 'response.txt'
    # Resilience: a weak/local model (e.g. MiniMax) occasionally returns an empty or truncated
    # answer - no response.txt written and empty stdout. Retry the whole invocation a few times
    # before giving up so a transient flake does not burn a task iteration.
    $maxAttempts = 3
    $minBytes = 40
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Remove-Item $respInSandbox -Force -ErrorAction SilentlyContinue
        Write-Host "[invoke-copilot] model=$Model role=$Role sandbox=$sandbox (attempt $attempt/$maxAttempts)" -ForegroundColor DarkCyan
        # -WindowStyle Hidden (NOT -NoNewWindow): under Start-Job there is no parent console,
        # and a console-less copilot CLI hangs at startup; a hidden own-console always works.
        $proc = Start-Process -FilePath 'copilot' -WorkingDirectory $sandbox -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $sandbox 'stdout.log') -RedirectStandardError (Join-Path $sandbox 'stderr.log') `
            -ArgumentList $argStr
        if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
            $proc.Kill($true)
            throw "copilot CLI timed out after ${TimeoutSec}s"
        }
        if (-not (Test-Path $respInSandbox)) {
            # Fallback: some models answer inline instead of writing the file.
            $stdout = Get-Content (Join-Path $sandbox 'stdout.log') -Raw -ErrorAction SilentlyContinue
            if ($stdout -and $stdout.Trim().Length -gt 50) {
                Write-Host '[invoke-copilot] response.txt missing - falling back to stdout capture' -ForegroundColor Yellow
                Set-Content $respInSandbox $stdout -Encoding utf8
            }
        }
        if ((Test-Path $respInSandbox) -and (Get-Item $respInSandbox).Length -ge $minBytes) { break }
        $more = if ($attempt -lt $maxAttempts) { 'retrying' } else { 'giving up' }
        Write-Host "[invoke-copilot] empty/too-small response on attempt $attempt (exit=$($proc.ExitCode)) - $more" -ForegroundColor Yellow
        if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds 4 }
    }
    if (-not (Test-Path $respInSandbox) -or (Get-Item $respInSandbox).Length -lt $minBytes) {
        throw "model produced no usable response after $maxAttempts attempts"
    }
    Copy-Item $respInSandbox $ResponseFile -Force
    Write-Host "[invoke-copilot] wrote $([math]::Round((Get-Item $ResponseFile).Length/1kb))kb response" -ForegroundColor DarkCyan
} finally {
    Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
}
exit 0
