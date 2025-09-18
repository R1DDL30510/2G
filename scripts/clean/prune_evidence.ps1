param(
    [string]$EvidenceRoot,
    [string[]]$Category = @('state'),
    [int]$RetentionDays = 14,
    [int]$KeepLatest = 5,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

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

function Resolve-Root {
    param([string]$ProvidedRoot)

    if ($ProvidedRoot) {
        if ([System.IO.Path]::IsPathRooted($ProvidedRoot)) {
            return $ProvidedRoot
        }

        return Join-Path $repoRoot $ProvidedRoot
    }

    $envRoot = Get-EnvValue -Key 'EVIDENCE_ROOT'
    if ($envRoot) {
        if ([System.IO.Path]::IsPathRooted($envRoot)) {
            return $envRoot
        }

        return Join-Path $repoRoot $envRoot
    }

    return Join-Path $repoRoot 'docs/evidence'
}

function Try-ReadInt {
    param(
        [string]$Key,
        [int]$DefaultValue
    )

    $value = Get-EnvValue -Key $Key
    if (-not $value) {
        return $DefaultValue
    }

    $parsed = 0
    if ([int]::TryParse($value, [ref]$parsed)) {
        return $parsed
    }

    Write-Warning ("Unable to parse {0} value '{1}' from .env; using {2}" -f $Key, $value, $DefaultValue)
    return $DefaultValue
}

if (-not $PSBoundParameters.ContainsKey('RetentionDays')) {
    $RetentionDays = Try-ReadInt -Key 'EVIDENCE_RETENTION_DAYS' -DefaultValue $RetentionDays
}

if (-not $PSBoundParameters.ContainsKey('KeepLatest')) {
    $KeepLatest = Try-ReadInt -Key 'EVIDENCE_KEEP_LATEST' -DefaultValue $KeepLatest
}

if ($RetentionDays -lt 0) {
    throw 'RetentionDays must be greater than or equal to 0.'
}

if ($KeepLatest -lt 0) {
    throw 'KeepLatest must be greater than or equal to 0.'
}

$resolvedRoot = Resolve-Root -ProvidedRoot $EvidenceRoot
if (-not (Test-Path $resolvedRoot)) {
    throw "Evidence root '$resolvedRoot' does not exist."
}

$now = Get-Date
$removed = 0
$skipped = 0

foreach ($name in $Category) {
    $categoryPath = Join-Path $resolvedRoot $name
    if (-not (Test-Path $categoryPath)) {
        Write-Verbose ("Skipping category '{0}' because the directory was not found." -f $name)
        continue
    }

    $entries = Get-ChildItem -Path $categoryPath -Directory | Sort-Object LastWriteTime -Descending
    if (-not $entries) {
        continue
    }

    $index = 0
    foreach ($entry in $entries) {
        if ($index -lt $KeepLatest) {
            $index += 1
            continue
        }

        $age = $now - $entry.LastWriteTime
        if ($RetentionDays -gt 0 -and $age.TotalDays -lt $RetentionDays) {
            $skipped += 1
            continue
        }

        if ($DryRun) {
            Write-Host ("[dry-run] Would remove {0}" -f $entry.FullName)
        }
        else {
            Remove-Item -Path $entry.FullName -Recurse -Force
            Write-Host ("Removed {0}" -f $entry.FullName)
        }

        $removed += 1
    }
}

Write-Output ("Prune complete. Removed: {0}; Skipped: {1}; KeepLatest: {2}; RetentionDays: {3}" -f $removed, $skipped, $KeepLatest, $RetentionDays)
