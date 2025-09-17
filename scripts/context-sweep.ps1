
param(
    [switch]$WriteReport,
    [switch]$CpuOnly,
    [switch]$Safe,
    [int]$InterRunDelaySec = 5,
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$eval = Join-Path $repoRoot 'scripts/eval-context.ps1'

function Get-EnvValue {
    param([string]$Key)
    $envPath = Join-Path $repoRoot '.env'
    if (-not (Test-Path $envPath)) {
        return $null
    }
    foreach ($line in Get-Content $envPath) {
        if ($line -match "^\s*$([regex]::Escape($Key))=(.+)$") {
            return $Matches[1]
        }
    }
    return $null
}

if (-not $Profile) {
    $envProfile = Get-EnvValue -Key 'CONTEXT_SWEEP_PROFILE'
    if ($envProfile) {
        $Profile = $envProfile
    }
}

if (-not $Profile) {
    $Profile = 'llama31-long'
}

$profiles = @{
    'llama31-long' = @(
        @{ Model='llama31-8b-c4k'; TokensDefault=2500; TokensSafe=1800; TimeoutDefault=210; TimeoutSafe=160; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 4096 } },
        @{ Model='llama31-8b-c8k'; TokensDefault=5000; TokensSafe=3200; TimeoutDefault=270; TimeoutSafe=210; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 8192 } },
        @{ Model='llama31-8b-c16k'; TokensDefault=9000; TokensSafe=6000; TimeoutDefault=360; TimeoutSafe=300; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 16384 } },
        @{ Model='llama31-8b-c32k'; TokensDefault=16000; TokensSafe=9000; TimeoutDefault=480; TimeoutSafe=360; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 32768 } }
    );
    'qwen3-balanced' = @(
        @{ Model='qwen3:8b'; TokensDefault=3000; TokensSafe=2200; TimeoutDefault=200; TimeoutSafe=160; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 4096 } },
        @{ Model='qwen3:8b'; TokensDefault=6000; TokensSafe=4200; TimeoutDefault=280; TimeoutSafe=220; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 8192 } },
        @{ Model='qwen3:8b'; TokensDefault=9000; TokensSafe=6000; TimeoutDefault=360; TimeoutSafe=300; Options=@{ NumGpu = 1; MainGpu = 0; NumCtx = 12000 } }
    );
    'cpu-baseline' = @(
        @{ Model='llama3.1:8b'; TokensDefault=2000; TokensSafe=1500; TimeoutDefault=360; TimeoutSafe=300; Options=@{} }
    )
}

if (-not $profiles.ContainsKey($Profile)) {
    $valid = ($profiles.Keys | Sort-Object) -join ', '
    throw "Unknown profile '$Profile'. Available profiles: $valid"
}

Write-Host ("Context sweep profile: {0} (safe mode: {1}; cpu only: {2})" -f $Profile, $Safe.IsPresent, $CpuOnly.IsPresent)

$plan = foreach ($entry in $profiles[$Profile]) {
    $tokens = if ($Safe.IsPresent -and $entry.ContainsKey('TokensSafe')) { $entry.TokensSafe } else { $entry.TokensDefault }
    $timeout = if ($Safe.IsPresent -and $entry.ContainsKey('TimeoutSafe')) { $entry.TimeoutSafe } else { $entry.TimeoutDefault }
    $options = if ($entry.ContainsKey('Options') -and $entry.Options) { $entry.Options } else { @{} }

    [pscustomobject]@{
        Model = $entry.Model
        Tokens = $tokens
        Timeout = $timeout
        Options = $options
    }
}

$rows = @()

foreach ($t in $plan) {
    Write-Host ("Testing {0} @ {1} tokens (timeout {2}s){3}" -f $t.Model, $t.Tokens, $t.Timeout, $(if ($CpuOnly) { ' [CPU]' } else { '' }))
    $args = @{
        Model = $t.Model
        TokensTarget = $t.Tokens
        Markers = 6
        TimeoutSec = $t.Timeout
    }

    if ($CpuOnly) {
        $args['CpuOnly'] = $true
    } else {
        if ($t.Options.ContainsKey('NumGpu')) { $args['NumGpu'] = $t.Options.NumGpu }
        if ($t.Options.ContainsKey('MainGpu')) { $args['MainGpu'] = $t.Options.MainGpu }
        if ($t.Options.ContainsKey('NumCtx')) { $args['NumCtx'] = $t.Options.NumCtx }
        if ($t.Options.ContainsKey('NumThread')) { $args['NumThread'] = $t.Options.NumThread }
    }

    $out = & $eval @args 2>$null
    if (-not $out) {
        $rows += [pscustomobject]@{ Model = $t.Model; Tokens = $t.Tokens; OK = $false; Latency = 'timeout'; Notes = 'no output' }
        if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
        continue
    }

    $m = [regex]::Match($out, 'Model:\s+(?<model>\S+)\s+OK:\s+(?<ok>\S+)\s+Latency\(s\):\s+(?<lat>[^\s]+)')
    if ($m.Success) {
        $rows += [pscustomobject]@{
            Model = $m.Groups['model'].Value
            Tokens = $t.Tokens
            OK = [bool]::Parse($m.Groups['ok'].Value)
            Latency = $m.Groups['lat'].Value
            Notes = ''
        }
    } else {
        $rows += [pscustomobject]@{
            Model = $t.Model
            Tokens = $t.Tokens
            OK = $false
            Latency = 'n/a'
            Notes = ($out -replace "", ' ')
        }
    }

    if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
}

$rows | Format-Table -AutoSize | Out-String | Write-Output

if ($WriteReport) {
    $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $reportPath = Join-Path $repoRoot ("docs/CONTEXT_RESULTS_" + $ts + ".md")
    $md = @()
    $md += "# Context Sweep Results ($ts)"
    $md += ''
    $md += '| Model | Tokens | OK | Latency (s) | Profile |'
    $md += '|-------|--------|----|-------------|---------|'
    foreach ($r in $rows) {
        $md += "| {0} | {1} | {2} | {3} | {4} |" -f $r.Model, $r.Tokens, $r.OK, $r.Latency, $Profile
    }
    Set-Content -Path $reportPath -Value ($md -join "`n") -Encoding UTF8
    Write-Output ("Wrote report: " + $reportPath)
}
