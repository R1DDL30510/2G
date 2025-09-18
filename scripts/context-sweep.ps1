param(
    [switch]$WriteReport,
    [switch]$CpuOnly,
    [switch]$Safe,
    [switch]$PlanOnly,
    [int]$InterRunDelaySec = 5,
    [string]$Profile,
    [int]$GpuCooldownSec = 15
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

function Copy-Hashtable {
    param([hashtable]$Source)

    $copy = @{}
    if ($Source) {
        foreach ($kv in $Source.GetEnumerator()) {
            $copy[$kv.Key] = $kv.Value
        }
    }

    return $copy
}

function Get-GpuInventory {
    try {
        $raw = & nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($exitCode -ne 0) {
            Write-Verbose ("nvidia-smi exited with code {0}; assuming no GPUs are available." -f $exitCode)
            return @()
        }
    }
    catch {
        Write-Verbose ("Unable to query GPUs via nvidia-smi: " + $_.Exception.Message)
        return @()
    }

    if (-not $raw) {
        return @()
    }

    $list = @()
    foreach ($line in $raw) {
        if (-not $line) { continue }
        $parts = $line -split ','
        if ($parts.Count -lt 2) { continue }

        $index = [int]($parts[0].Trim())
        $name = $parts[1].Trim()
        $memGb = $null

        if ($parts.Count -ge 3) {
            $match = [regex]::Match($parts[2], '(?<value>[0-9]+)\s+MiB')
            if ($match.Success) {
                $memValue = [double]([int]$match.Groups['value'].Value)
                $memGb = [math]::Round($memValue / 1024, 2)
            }
        }

        $list += [pscustomobject]@{
            Index = $index
            Name = $name
            MemoryGiB = $memGb
        }
    }

    return $list
}

if (-not $Profile) {
    $envProfile = Get-EnvValue -Key 'CONTEXT_SWEEP_PROFILE'
    if ($envProfile) {
        $Profile = $envProfile
    }
}

if (-not $Profile) {
    $Profile = 'baseline-cpu'
}

$profiles = @{
    'baseline-cpu' = @(
        @{ Model='baseline'; TokensDefault=4000; TokensSafe=3000; TimeoutDefault=180; TimeoutSafe=150; Options=@{ NumCtx = 8192 } }
    )
}

if (-not $profiles.ContainsKey($Profile)) {
    $valid = ($profiles.Keys | Sort-Object) -join ', '
    throw "Unknown profile '$Profile'. Available profiles: $valid"
}

$useCpuOnly = $CpuOnly.IsPresent
$gpuInventory = @()

if (-not $useCpuOnly) {
    $gpuInventory = Get-GpuInventory
    if ($gpuInventory.Count -eq 0) {
        Write-Warning 'No NVIDIA GPUs detected. Falling back to CPU-only execution.'
        $useCpuOnly = $true
    } else {
        $gpuSummary = $gpuInventory | ForEach-Object {
            if ($_.MemoryGiB) {
                "[{0}] {1} ({2:N1} GiB)" -f $_.Index, $_.Name, $_.MemoryGiB
            } else {
                "[{0}] {1}" -f $_.Index, $_.Name
            }
        }
        Write-Host ("Detected {0} GPU(s): {1}" -f $gpuInventory.Count, ($gpuSummary -join '; '))
    }
}

Write-Host ("Context sweep profile: {0} (safe mode: {1}; cpu only: {2})" -f $Profile, $Safe.IsPresent, $useCpuOnly)
if ($PlanOnly.IsPresent) {
    Write-Warning 'Plan-only mode enabled; skipping Ollama evaluation and recording the test plan only.'
}

$planBase = foreach ($entry in $profiles[$Profile]) {
    $tokens = if ($Safe.IsPresent -and $entry.ContainsKey('TokensSafe')) { $entry.TokensSafe } else { $entry.TokensDefault }
    $timeout = if ($Safe.IsPresent -and $entry.ContainsKey('TimeoutSafe')) { $entry.TimeoutSafe } else { $entry.TimeoutDefault }
    $options = if ($entry.ContainsKey('Options') -and $entry.Options) { Copy-Hashtable $entry.Options } else { @{} }

    [pscustomobject]@{
        Model = $entry.Model
        Tokens = $tokens
        Timeout = $timeout
        Options = $options
    }
}

$plan = @()

if (-not $useCpuOnly -and $gpuInventory.Count -gt 0) {
    foreach ($gpu in $gpuInventory) {
        foreach ($entry in $planBase) {
            $options = Copy-Hashtable $entry.Options
            if (-not $options.ContainsKey('NumGpu')) { $options['NumGpu'] = 1 }
            $options['MainGpu'] = $gpu.Index

            $plan += [pscustomobject]@{
                Model = $entry.Model
                Tokens = $entry.Tokens
                Timeout = $entry.Timeout
                Options = $options
                GpuIndex = $gpu.Index
                GpuName = $gpu.Name
            }
        }
    }
} else {
    foreach ($entry in $planBase) {
        $plan += [pscustomobject]@{
            Model = $entry.Model
            Tokens = $entry.Tokens
            Timeout = $entry.Timeout
            Options = Copy-Hashtable $entry.Options
            GpuIndex = $null
            GpuName = $null
        }
    }
}

$rows = @()
$lastGpuIndex = $null
$hadFailures = $false

foreach ($t in $plan) {
    if (-not $useCpuOnly -and $GpuCooldownSec -gt 0) {
        if ($null -ne $lastGpuIndex -and $t.GpuIndex -ne $lastGpuIndex) {
            Write-Host ("Cooling down for {0}s before switching from GPU {1} to GPU {2}" -f $GpuCooldownSec, $lastGpuIndex, $t.GpuIndex)
            Start-Sleep -Seconds $GpuCooldownSec
        }
    }

    $deviceLabel = if ($useCpuOnly) { 'CPU' } elseif ($null -ne $t.GpuIndex) { "GPU $($t.GpuIndex)" } else { 'GPU' }
    $deviceSuffix = if ($useCpuOnly) { ' [CPU]' } elseif ($t.GpuName) { " [GPU $($t.GpuIndex) - $($t.GpuName)]" } else { " [$deviceLabel]" }

    Write-Host ("Testing {0} @ {1} tokens (timeout {2}s){3}" -f $t.Model, $t.Tokens, $t.Timeout, $deviceSuffix)
    if ($PlanOnly.IsPresent) {
        $rows += [pscustomobject]@{
            Model = $t.Model
            Tokens = $t.Tokens
            OK = 'plan-only'
            Latency = 'n/a'
            Device = $deviceLabel
            Notes = 'plan-only execution (no Ollama call)'
        }
        $lastGpuIndex = $t.GpuIndex
        if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
        continue
    }

    $args = @{
        Model = $t.Model
        TokensTarget = $t.Tokens
        Markers = 6
        TimeoutSec = $t.Timeout
    }

    if ($useCpuOnly) {
        $args['CpuOnly'] = $true
    } else {
        if ($t.Options.ContainsKey('NumGpu')) { $args['NumGpu'] = $t.Options.NumGpu }
        if ($t.Options.ContainsKey('MainGpu')) { $args['MainGpu'] = $t.Options.MainGpu }
        if ($t.Options.ContainsKey('NumCtx')) { $args['NumCtx'] = $t.Options.NumCtx }
        if ($t.Options.ContainsKey('NumThread')) { $args['NumThread'] = $t.Options.NumThread }
    }

    $out = & $eval @args 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $outText = if ($out -is [System.Array]) { $out -join [Environment]::NewLine } else { [string]$out }

    if ($exitCode -ne 0) {
        $rows += [pscustomobject]@{
            Model = $t.Model
            Tokens = $t.Tokens
            OK = $false
            Latency = 'n/a'
            Device = $deviceLabel
            Notes = "exit code $exitCode"
        }
        $hadFailures = $true
        $lastGpuIndex = $t.GpuIndex
        if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
        continue
    }

    if (-not $outText) {
        $rows += [pscustomobject]@{
            Model = $t.Model
            Tokens = $t.Tokens
            OK = $false
            Latency = 'timeout'
            Device = $deviceLabel
            Notes = 'no output'
        }
        $hadFailures = $true
        $lastGpuIndex = $t.GpuIndex
        if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
        continue
    }

    $m = [regex]::Match($outText, 'Model:\s+(?<model>\S+)\s+OK:\s+(?<ok>\S+)\s+Latency\(s\):\s+(?<lat>[^\s]+)')
    if ($m.Success) {
        $ok = [bool]::Parse($m.Groups['ok'].Value)
        $rows += [pscustomobject]@{
            Model = $m.Groups['model'].Value
            Tokens = $t.Tokens
            OK = $ok
            Latency = $m.Groups['lat'].Value
            Device = $deviceLabel
            Notes = ''
        }
        if (-not $ok) { $hadFailures = $true }
    } else {
        $rows += [pscustomobject]@{
            Model = $t.Model
            Tokens = $t.Tokens
            OK = $false
            Latency = 'n/a'
            Device = $deviceLabel
            Notes = ($outText -replace '\s+', ' ').Trim()
        }
        $hadFailures = $true
    }

    $lastGpuIndex = $t.GpuIndex
    if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
}

if ($rows.Count -gt 0) {
    $rows | Select-Object Model, Tokens, OK, Latency, Device, Notes | Format-Table -AutoSize | Out-String | Write-Output
}

if ($WriteReport) {
    $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $reportPath = Join-Path $repoRoot ("docs/CONTEXT_RESULTS_" + $ts + ".md")
    $md = @()
    $md += "# Context Sweep Results ($ts)"
    $md += ''
    $md += '| Model | Tokens | OK | Latency (s) | Device | Profile | Notes |'
    $md += '|-------|--------|----|-------------|--------|---------|-------|'
    foreach ($r in $rows) {
        $noteText = if ($r.Notes) { $r.Notes } else { '' }
        $md += "| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f $r.Model, $r.Tokens, $r.OK, $r.Latency, $r.Device, $Profile, $noteText
    }
    Set-Content -Path $reportPath -Value ($md -join "`n") -Encoding UTF8
    Write-Output ("Wrote report: " + $reportPath)
}
if ($hadFailures) {
    exit 1
}
