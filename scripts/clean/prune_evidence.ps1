param(
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Keep = 5,
    [ValidateRange(0, [int]::MaxValue)]
    [int]$MaxAgeDays = 0,
    [string]$Root
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

function Get-EnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $envFile = Join-Path -Path $repoRoot -ChildPath '.env'
    if (-not (Test-Path -Path $envFile)) {
        return $null
    }

    foreach ($line in Get-Content -Path $envFile) {
        if ($line -match "^\s*$([regex]::Escape($Key))=(.+)$") {
            return $Matches[1]
        }
    }

    return $null
}

if (-not $Root) {
    $envRoot = Get-EnvValue -Key 'EVIDENCE_ROOT'
    if ($envRoot) {
        $Root = if ([System.IO.Path]::IsPathRooted($envRoot)) {
            $envRoot
        }
        else {
            Join-Path -Path $repoRoot -ChildPath $envRoot
        }
    }
    else {
        $Root = Join-Path -Path $repoRoot -ChildPath 'docs/evidence'
    }
}

$stateRoot = Join-Path -Path $Root -ChildPath 'state'
if (-not (Test-Path -Path $stateRoot)) {
    Write-Host "State evidence directory not found at $stateRoot. Nothing to prune."
    return
}

$directories = Get-ChildItem -Path $stateRoot -Directory | Sort-Object -Property LastWriteTime -Descending
if (-not $directories) {
    Write-Host "No state evidence directories discovered under $stateRoot."
    return
}

$threshold = if ($MaxAgeDays -gt 0) { (Get-Date).AddDays(-$MaxAgeDays) } else { $null }
$removals = @()

for ($index = 0; $index -lt $directories.Count; $index++) {
    $dir = $directories[$index]
    $remove = $false
    $withinRetention = $index -lt $Keep

    if ($index -ge $Keep) {
        $remove = $true
    }

    if (-not $withinRetention -and $threshold -and $dir.LastWriteTime -lt $threshold) {
        $remove = $true
    }

    if ($remove) {
        $removals += $dir
    }
}

if ($removals.Count -eq 0) {
    Write-Host "No evidence directories required pruning."
    return
}

foreach ($directory in $removals) {
    Write-Host "Removing $($directory.FullName)"
    Remove-Item -Path $directory.FullName -Recurse -Force -ErrorAction Stop
}

Write-Host ("Pruned {0} state evidence director{1}." -f $removals.Count, $(if ($removals.Count -eq 1) { 'y' } else { 'ies' }))
