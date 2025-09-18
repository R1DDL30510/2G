Set-StrictMode -Version Latest

function Get-RepositoryRoot {
    param(
        [string]$StartingPath
    )

    if (-not $StartingPath) {
        $StartingPath = $PSScriptRoot
    }

    $currentPath = (Resolve-Path -Path $StartingPath -ErrorAction Stop).ProviderPath
    while (-not (Test-Path (Join-Path $currentPath '.git'))) {
        $parent = Split-Path -Parent $currentPath
        if (-not $parent -or $parent -eq $currentPath) {
            throw "Unable to locate repository root from '$StartingPath'."
        }
        $currentPath = $parent
    }

    return $currentPath
}

function Get-RepoEnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = Get-RepositoryRoot
    }

    $envPath = Join-Path $RepoRoot '.env'
    if (-not (Test-Path $envPath)) {
        return $null
    }

    foreach ($line in Get-Content -Path $envPath) {
        if ($line -match "^\s*$([regex]::Escape($Key))=(.*)$") {
            return $Matches[1]
        }
    }

    return $null
}

function Resolve-RepoPath {
    param(
        [string]$Path,
        [string]$RepoRoot
    )

    if (-not $Path) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    if (-not $RepoRoot) {
        $RepoRoot = Get-RepositoryRoot
    }

    $combined = Join-Path $RepoRoot $Path
    return [System.IO.Path]::GetFullPath($combined)
}

function Get-RepoEvidenceRoot {
    param(
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = Get-RepositoryRoot
    }

    $configured = Get-RepoEnvValue -RepoRoot $RepoRoot -Key 'EVIDENCE_ROOT'
    if (-not $configured) {
        $configured = './docs/evidence'
    }

    return Resolve-RepoPath -RepoRoot $RepoRoot -Path $configured
}
