param(
    [string]$Model = 'llama31-8b-c8k',
    [int]$TokensTarget = 6000,
    [int]$Markers = 6,
    [int]$TimeoutSec = 300,
    [switch]$CpuOnly,
    [Nullable[int]]$NumGpu,
    [Nullable[int]]$MainGpu,
    [Nullable[int]]$NumCtx,
    [Nullable[int]]$NumThread
)

$ErrorActionPreference = 'Stop'
$script:lastCallError = $null

function Call-Ollama([string]$model,[string]$prompt){
    $script:lastCallError = $null
    $options = @{}
    if ($CpuOnly.IsPresent) { $options['num_gpu'] = 0 }
    elseif ($NumGpu) { $options['num_gpu'] = [int]$NumGpu }
    if ($MainGpu) { $options['main_gpu'] = [int]$MainGpu }
    if ($NumCtx) { $options['num_ctx'] = [int]$NumCtx }
    if ($NumThread) { $options['num_thread'] = [int]$NumThread }

    $payload = @{ model = $model; prompt = $prompt; stream = $false }
    if ($options.Count -gt 0) { $payload['options'] = $options }

    $body = $payload | ConvertTo-Json -Depth 6
    try {
        $resp = Invoke-WebRequest -Uri 'http://localhost:11434/api/generate' -Method POST -ContentType 'application/json' -Body $body -UseBasicParsing -TimeoutSec $TimeoutSec
        return ($resp.Content | ConvertFrom-Json)
    }
    catch {
        $script:lastCallError = $_.Exception.Message
        Write-Verbose ("Request failed: " + $_.Exception.Message)
        return $null
    }
}

# Build a long prompt with markers that test recall across the context
$sb = [System.Text.StringBuilder]::new()
$rand = New-Object System.Random
$keys = @()
for($i=1; $i -le $Markers; $i++){
    $key = -join ((48..122 | ForEach-Object {[char]$_}) | Where-Object {$_ -match '[A-Za-z0-9]'} | Get-Random -Count 12)
    $keys += @{ i=$i; key=$key }
}
$sb.AppendLine("You will be given N labeled sections [S1..S$Markers]. Each section contains a secret KEY: <XXXX>. Later you will be asked for one key by label. Reply only with the exact key string (no extra text).") | Out-Null
for($i=1; $i -le $Markers; $i++){
    $noise = ('Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 50)
    $sb.AppendLine("[S$i] KEY: <$($keys[$i-1].key)>  $noise") | Out-Null
}
$askIndex = Get-Random -Minimum 1 -Maximum ($Markers+1)
$question = "Question: What is the KEY in [S$askIndex]? Answer with only the key."
$filler = (' ' * [Math]::Max(0, $TokensTarget - $sb.Length))
$prompt = $sb.ToString() + $filler + "`n$question"

$start = Get-Date
$out = Call-Ollama -model $Model -prompt $prompt
$elapsed = ((Get-Date) - $start).TotalSeconds

if (-not $out) {
    $errorDetail = if ($script:lastCallError) { $script:lastCallError } else { 'request failed' }
    return "ERROR evaluating $Model at $TokensTarget tokens (asked S$askIndex): $errorDetail"
}

$answer = $out.response.Trim()
$expected = ($keys | Where-Object { $_.i -eq $askIndex }).key
$ok = ($answer -eq $expected)

Write-Output ("Model: {0}  OK: {1}  Latency(s): {2:N1}  Asked: S{3}  Expected: {4}  Got: {5}" -f $Model,$ok,$elapsed,$askIndex,$expected,$answer)
