param(
    [string]$Model,
    [string]$PromptPath,
    [int]$Iterations = 3,
    [switch]$Warmup,
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Get-EnvValue {
    param([string]$Key)
    $envFile = Join-Path $repoRoot '.env'
    if (-not (Test-Path $envFile)) {
        return $null
    }
    foreach ($line in Get-Content $envFile) {
        if ($line -match "^\s*$([regex]::Escape($Key))=(.+)$") {
            return $Matches[1]
        }
    }
    return $null
}

function Resolve-PathFromRepo {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $repoRoot $Path
}

function Invoke-OllamaJsonRun {
    param(
        [string]$ModelName,
        [string]$Prompt,
        [int]$IterationIndex,
        [string]$OutputDirectory,
        [switch]$PersistArtifacts
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'ollama'
    $psi.Arguments = "run $ModelName --json"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        $process.Start() | Out-Null
    }
    catch {
        throw "Failed to start ollama process: $($_.Exception.Message)"
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process.StandardInput.Write($Prompt)
    $process.StandardInput.Close()

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $stopwatch.Stop()

    $jsonLines = @()
    foreach ($line in $stdout -split "`n") {
        $trimmed = $line.Trim()
        if ($trimmed) { $jsonLines += $trimmed }
    }

    $responses = @()
    $lastObj = $null
    foreach ($line in $jsonLines) {
        try {
            $obj = $line | ConvertFrom-Json
        }
        catch {
            continue
        }
        if ($obj.response) { $responses += $obj.response }
        $lastObj = $obj
    }

    if ($PersistArtifacts) {
        $jsonPath = Join-Path $OutputDirectory ("iteration-$IterationIndex.jsonl")
        Set-Content -Path $jsonPath -Value ($jsonLines -join "`n") -Encoding UTF8
        if ($stderr) {
            $errPath = Join-Path $OutputDirectory ("iteration-$IterationIndex.stderr.txt")
            Set-Content -Path $errPath -Value $stderr -Encoding UTF8
        }
    }

    $wallMs = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
    $evalCount = if ($lastObj -and $lastObj.eval_count) { [int]$lastObj.eval_count } else { 0 }
    $evalDurationNs = if ($lastObj -and $lastObj.eval_duration) { [double]$lastObj.eval_duration } else { 0 }
    $promptEvalCount = if ($lastObj -and $lastObj.prompt_eval_count) { [int]$lastObj.prompt_eval_count } else { 0 }
    $promptEvalDurationNs = if ($lastObj -and $lastObj.prompt_eval_duration) { [double]$lastObj.prompt_eval_duration } else { 0 }
    $totalDurationNs = if ($lastObj -and $lastObj.total_duration) { [double]$lastObj.total_duration } else { 0 }

    $evalSeconds = if ($evalDurationNs -gt 0) { $evalDurationNs / 1e9 } else { 0 }
    $tokensPerSecond = if ($evalSeconds -gt 0) { [math]::Round($evalCount / $evalSeconds, 2) } else { 0 }

    return [pscustomobject]@{
        Iteration = $IterationIndex
        ExitCode = $process.ExitCode
        WallMs = $wallMs
        ResponseLength = ($responses -join '').Length
        EvalCount = $evalCount
        EvalDurationNs = $evalDurationNs
        PromptEvalCount = $promptEvalCount
        PromptEvalDurationNs = $promptEvalDurationNs
        TotalDurationNs = $totalDurationNs
        TokensPerSecond = $tokensPerSecond
        StdErr = $stderr
    }
}

if (-not $Model) {
    $Model = Get-EnvValue -Key 'OLLAMA_BENCH_MODEL'
}
if (-not $Model) {
    throw 'Model name not specified and OLLAMA_BENCH_MODEL missing from .env.'
}

if (-not $PromptPath) {
    $PromptPath = Get-EnvValue -Key 'OLLAMA_BENCH_PROMPT'
}
if (-not $PromptPath) {
    throw 'Prompt path not specified and OLLAMA_BENCH_PROMPT missing from .env.'
}

$resolvedPromptPath = Resolve-PathFromRepo -Path $PromptPath
if (-not (Test-Path $resolvedPromptPath)) {
    throw "Prompt file not found at $resolvedPromptPath"
}

$prompt = Get-Content -Path $resolvedPromptPath -Raw
if ([string]::IsNullOrWhiteSpace($prompt)) {
    throw 'Prompt file is empty; provide a prompt with representative workload.'
}

if (-not $OutputRoot) {
    $OutputRoot = Get-EnvValue -Key 'EVIDENCE_ROOT'
}
if (-not $OutputRoot) {
    $OutputRoot = 'docs/evidence'
}

$resolvedOutputRoot = Resolve-PathFromRepo -Path $OutputRoot
Ensure-Directory -Path $resolvedOutputRoot
$benchRoot = Join-Path $resolvedOutputRoot 'benchmarks'
Ensure-Directory -Path $benchRoot

$sanitizedModel = ($Model -replace "[^A-Za-z0-9]+", '-').Trim('-')
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $benchRoot ("bench-" + $sanitizedModel + '-' + $timestamp)
Ensure-Directory -Path $runDir

Write-Output "Running Ollama benchmark for model '$Model' using prompt '$resolvedPromptPath' ($Iterations iteration(s))."

if ($Warmup) {
    Write-Output 'Warm-up iteration...'
    try {
        Invoke-OllamaJsonRun -ModelName $Model -Prompt $prompt -IterationIndex 0 -OutputDirectory $runDir | Out-Null
    }
    catch {
        Write-Warning "Warm-up iteration failed: $($_.Exception.Message)"
    }
}

$results = @()
for ($i = 1; $i -le $Iterations; $i++) {
    Write-Output ("Iteration $i of $Iterations")
    try {
        $result = Invoke-OllamaJsonRun -ModelName $Model -Prompt $prompt -IterationIndex $i -OutputDirectory $runDir -PersistArtifacts
        $results += $result
    }
    catch {
        Write-Warning "Iteration $i failed: $($_.Exception.Message)"
        $results += [pscustomobject]@{
            Iteration = $i
            ExitCode = -1
            WallMs = 0
            ResponseLength = 0
            EvalCount = 0
            EvalDurationNs = 0
            PromptEvalCount = 0
            PromptEvalDurationNs = 0
            TotalDurationNs = 0
            TokensPerSecond = 0
            StdErr = $_.Exception.Message
        }
    }
}

if (-not $results.Count) {
    throw 'No benchmark iterations completed.'
}

$wallDurations = $results | ForEach-Object { $_.WallMs }
$tokenRates = $results | ForEach-Object { $_.TokensPerSecond }
$avgWall = [math]::Round(($wallDurations | Measure-Object -Average).Average, 2)
$minWall = [math]::Round(($wallDurations | Measure-Object -Minimum).Minimum, 2)
$maxWall = [math]::Round(($wallDurations | Measure-Object -Maximum).Maximum, 2)
$avgTokens = if ($tokenRates) { [math]::Round(($tokenRates | Measure-Object -Average).Average, 2) } else { 0 }

$report = @('# Ollama benchmark report', '', "*Generated by scripts/clean/bench_ollama.ps1 on $([DateTime]::Now.ToString('u'))*", '')
$report += "- Model: $Model"
$report += "- Prompt: $resolvedPromptPath"
$report += "- Iterations: $Iterations"
$report += "- Average wall time (ms): $avgWall"
$report += "- Min/Max wall time (ms): $minWall / $maxWall"
$report += "- Average tokens/sec (from eval_duration): $avgTokens"
$report += ''
$report += '| Iteration | Exit code | Wall (ms) | Tokens/sec | Eval tokens | Response chars |'
$report += '| --- | --- | --- | --- | --- | --- |'
foreach ($entry in $results) {
    $report += "| {0} | {1} | {2} | {3} | {4} | {5} |" -f $entry.Iteration, $entry.ExitCode, $entry.WallMs, $entry.TokensPerSecond, $entry.EvalCount, $entry.ResponseLength
}

$reportPath = Join-Path $runDir 'report.md'
Set-Content -Path $reportPath -Value ($report -join "`n") -Encoding UTF8

$metadata = [pscustomobject]@{
    model = $Model
    prompt = $resolvedPromptPath
    iterations = $Iterations
    warmup = $Warmup.IsPresent
    average_wall_ms = $avgWall
    min_wall_ms = $minWall
    max_wall_ms = $maxWall
    average_tokens_per_sec = $avgTokens
    results = $results
}

$metadataPath = Join-Path $runDir 'summary.json'
$metadata | ConvertTo-Json -Depth 4 | Set-Content -Path $metadataPath -Encoding UTF8

Write-Output "Benchmark artifacts saved to $runDir"
