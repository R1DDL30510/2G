param(
    [string]$Model,
    [string]$PromptPath,
    [int]$Iterations = 3,
    [switch]$Warmup,
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonCandidates = @(
    Join-Path $scriptRoot 'common/repo-paths.ps1'
    Join-Path (Split-Path -Parent $scriptRoot) 'common/repo-paths.ps1'
)
$repoHelperPath = $commonCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $repoHelperPath) {
    throw 'Unable to locate scripts/common/repo-paths.ps1'
}
. $repoHelperPath

$repoRoot = Get-RepositoryRoot -StartingPath $scriptRoot
$composeFile = Join-Path $repoRoot 'infra\compose\docker-compose.yml'

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Get-OllamaContainerId {
    $id = docker compose -f $composeFile ps -q ollama
    if (-not $id) {
        throw 'Ollama container not found. Start the stack with ./scripts/compose.ps1 up.'
    }
    return $id
}


function Invoke-OllamaJsonRun {
    param(
        [string]$ModelName,
        [string]$Prompt,
        [int]$IterationIndex,
        [string]$OutputDirectory,
        [switch]$PersistArtifacts
    )

    $uri = 'http://localhost:11434/api/generate'
    $payload = @{ model = $ModelName; prompt = $Prompt; stream = $false }
    $body = $payload | ConvertTo-Json -Depth 6

    $stdout = ''
    $stderr = ''
    $lastObj = $null
    $responses = @()
    $exitCode = 0

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $uri -Method POST -ContentType 'application/json' -Body $body -UseBasicParsing -TimeoutSec 600
        $stdout = ($response.Content).Trim()
    }
    catch {
        $stderr = $_.Exception.Message
        $exitCode = -1
    }
    $stopwatch.Stop()

    if ($stdout) {
        try {
            $lastObj = $stdout | ConvertFrom-Json
        }
        catch {
            $stderr = "Failed to parse Ollama response as JSON: $stdout"
            $exitCode = -1
        }
        if ($lastObj -and $lastObj.response) {
            $responses += $lastObj.response
        }
    }

    if ($PersistArtifacts) {
        $jsonPath = Join-Path $OutputDirectory ("iteration-$IterationIndex.jsonl")
        Set-Content -Path $jsonPath -Value $stdout -Encoding UTF8
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
        ExitCode = $exitCode
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
    $Model = Get-RepoEnvValue -RepoRoot $repoRoot -Key 'OLLAMA_BENCH_MODEL'
}
if (-not $Model) {
    throw 'Model name not specified and OLLAMA_BENCH_MODEL missing from .env.'
}

if (-not $PromptPath) {
    $PromptPath = Get-RepoEnvValue -RepoRoot $repoRoot -Key 'OLLAMA_BENCH_PROMPT'
}
if (-not $PromptPath) {
    throw 'Prompt path not specified and OLLAMA_BENCH_PROMPT missing from .env.'
}

$resolvedPromptPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $PromptPath
if (-not (Test-Path $resolvedPromptPath)) {
    throw "Prompt file not found at $resolvedPromptPath"
}

$prompt = Get-Content -Path $resolvedPromptPath -Raw
if ([string]::IsNullOrWhiteSpace($prompt)) {
    throw 'Prompt file is empty; provide a prompt with representative workload.'
}

if (-not $OutputRoot) {
    $OutputRoot = Get-RepoEvidenceRoot -RepoRoot $repoRoot
}
else {
    $OutputRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $OutputRoot
}

$resolvedOutputRoot = $OutputRoot
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

