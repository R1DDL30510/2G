param(
    [string]$EvidenceRoot,
    [string[]]$Categories = @('state','benchmarks','context','ci','codex','precommit','environment'),
    [int]$MinimumPerCategory = 5,
    [int]$DaysToKeep = 14,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

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

if (-not $EvidenceRoot) {
    $envValue = Get-EnvValue -Key 'EVIDENCE_ROOT'
    if ($envValue) {
        if ([System.IO.Path]::IsPathRooted($envValue)) {
            $EvidenceRoot = $envValue
        }
        else {
            $EvidenceRoot = Join-Path $repoRoot $envValue
        }
    }
    else {
        $EvidenceRoot = Join-Path $repoRoot 'docs/evidence'
    }
}

if (-not (Test-Path $EvidenceRoot)) {
    Write-Warning ("Evidence root '{0}' does not exist. Nothing to prune." -f $EvidenceRoot)
    return
}

$now = Get-Date
$pruned = @()

foreach ($category in $Categories) {
    $categoryPath = if ([System.IO.Path]::IsPathRooted($category)) {
        $category
    }
    else {
        Join-Path $EvidenceRoot $category
    }

    if (-not (Test-Path $categoryPath)) {
        continue
    }

    $entries = Get-ChildItem -Path $categoryPath -Directory -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending

    if (-not $entries -or $entries.Count -eq 0) {
        continue
    }

    $preserveCount = [Math]::Max($MinimumPerCategory, 0)
    $retain = if ($preserveCount -gt 0) {
        $entries | Select-Object -First ([Math]::Min($preserveCount, $entries.Count))
    }
    else {
        @()
    }

    $retainNames = @{}
    foreach ($item in $retain) {
        $retainNames[$item.FullName] = $true
    }

    $candidates = @()
    foreach ($entry in $entries) {
        if ($retainNames.ContainsKey($entry.FullName)) {
            continue
        }

        $ageDays = ($now - $entry.LastWriteTime).TotalDays
        if ($ageDays -gt $DaysToKeep) {
            $candidates += [pscustomobject]@{ Item = $entry; AgeDays = [Math]::Round($ageDays, 2) }
        }
    }

    if ($candidates.Count -eq 0) {
        continue
    }

    foreach ($candidate in $candidates) {
        $path = $candidate.Item.FullName
        if ($WhatIf) {
            Write-Host ("[WhatIf] Would remove {0} (age {1} days)" -f $path, $candidate.AgeDays)
        }
        else {
            Remove-Item -Path $path -Recurse -Force
            Write-Host ("Removed {0} (age {1} days)" -f $path, $candidate.AgeDays)
        }
    }

    $pruned += [pscustomobject]@{
        Category = $category
        Removed = $candidates.Count
    }
}

if ($pruned.Count -eq 0) {
    Write-Host 'No evidence directories exceeded the retention policy.'
}
else {
    Write-Host ''
    Write-Host 'Retention summary:'
    foreach ($entry in $pruned) {
        Write-Host ("- {0}: removed {1}" -f $entry.Category, $entry.Removed)
    }
}
