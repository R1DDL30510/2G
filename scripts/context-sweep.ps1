param(
    [switch]$WriteReport,
    [switch]$CpuOnly,
    [switch]$Safe,
    [int]$InterRunDelaySec = 5
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$eval = Join-Path $root 'scripts/eval-context.ps1'

# Build a plan. In safe mode, reduce token targets/timeouts to lower system stress.
if ($Safe.IsPresent) {
    $plan = @(
        @{ Model='llama31-8b-c4k';  Tokens=2000; Timeout=180 }
        @{ Model='llama31-8b-c8k';  Tokens=4000; Timeout=240 }
        @{ Model='llama31-8b-c16k'; Tokens=8000; Timeout=360 }
        @{ Model='llama31-8b-c32k'; Tokens=12000; Timeout=420 }
    )
} else {
    $plan = @(
        @{ Model='llama31-8b-c4k';  Tokens=3000; Timeout=240 }
        @{ Model='llama31-8b-c8k';  Tokens=6000; Timeout=300 }
        @{ Model='llama31-8b-c16k'; Tokens=12000; Timeout=420 }
        @{ Model='llama31-8b-c32k'; Tokens=24000; Timeout=600 }
    )
}

$rows = @()
foreach($t in $plan){
    Write-Host ("Testing {0} @ {1} tokens (timeout {2}s){3}" -f $t.Model,$t.Tokens,$t.Timeout, $(if($CpuOnly){' [CPU]'}else{''}))
    $out = & $eval -Model $t.Model -TokensTarget $t.Tokens -Markers 6 -TimeoutSec $t.Timeout -CpuOnly:$CpuOnly 2>$null
    if (-not $out) { $rows += [pscustomobject]@{ Model=$t.Model; Tokens=$t.Tokens; OK=$false; Latency='timeout'; Notes='no output' }; if ($InterRunDelaySec -gt 0){ Start-Sleep -Seconds $InterRunDelaySec }; continue }
    # Expected line format: Model: X  OK: True  Latency(s): 41.2  Asked: S3  Expected: ...  Got: ...
    $m = [regex]::Match($out, 'Model:\s+(?<model>\S+)\s+OK:\s+(?<ok>\S+)\s+Latency\(s\):\s+(?<lat>[^\s]+)')
    if ($m.Success) {
        $rows += [pscustomobject]@{ Model=$m.Groups['model'].Value; Tokens=$t.Tokens; OK=[bool]::Parse($m.Groups['ok'].Value); Latency=$m.Groups['lat'].Value; Notes='' }
    } else {
        $rows += [pscustomobject]@{ Model=$t.Model; Tokens=$t.Tokens; OK=$false; Latency='n/a'; Notes=($out -replace "\r"," ") }
    }
    if ($InterRunDelaySec -gt 0) { Start-Sleep -Seconds $InterRunDelaySec }
}

$rows | Format-Table -AutoSize | Out-String | Write-Output

if ($WriteReport) {
  $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
  $reportPath = Join-Path $root ("docs/CONTEXT_RESULTS_" + $ts + ".md")
  $md = @()
  $md += "# Context Sweep Results ($ts)"
  $md += ""
  $md += "| Model | Tokens | OK | Latency (s) |"
  $md += "|-------|--------|----|-------------|"
  foreach($r in $rows){
    $md += ("| {0} | {1} | {2} | {3} |" -f $r.Model,$r.Tokens,$r.OK,$r.Latency)
  }
  Set-Content -Path $reportPath -Value ($md -join "`n") -Encoding UTF8
  Write-Output ("Wrote report: " + $reportPath)
}
