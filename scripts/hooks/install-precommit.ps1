param(
    [ValidateSet('quick', 'full')]
    [string]$Mode = 'quick',
    [switch]$Gpu
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$hooksRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptRoot = Split-Path -Parent $hooksRoot
$repoRoot = Split-Path -Parent $scriptRoot
$hookDir = Join-Path $repoRoot '.git/hooks'
if (-not (Test-Path $hookDir)) {
    throw 'Git hooks directory not found. Ensure this script runs inside a cloned repository.'
}

$precommitPath = Join-Path $scriptRoot 'precommit.ps1'
if (-not (Test-Path $precommitPath)) {
    throw 'scripts/precommit.ps1 not found; generate it before installing hooks.'
}

$runner = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $runner) {
    $runner = Get-Command powershell -ErrorAction SilentlyContinue
}
if (-not $runner) {
    throw 'Neither pwsh nor powershell found on PATH.'
}
$runnerName = Split-Path $runner.Source -Leaf

$modeArg = "-Mode $Mode"
$gpuArg = if ($Gpu) { ' -Gpu' } else { '' }
$escapedScript = $precommitPath.Replace('\', '/')
$hookContent = @"
#!/bin/sh
$runnerName -NoLogo -NoProfile -File "$escapedScript" $modeArg$gpuArg `$@
EXIT_CODE=`$?
exit `$EXIT_CODE
"@
$hookFile = Join-Path $hookDir 'pre-commit'
Set-Content -Path $hookFile -Value $hookContent -Encoding ASCII
Write-Host "Installed pre-commit hook invoking scripts/precommit.ps1 $modeArg$gpuArg via $runnerName"
