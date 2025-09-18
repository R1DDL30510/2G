param(
    [int]$RetentionDays = 14,
    [int]$KeepRecent = 5,
    [string]$EvidenceRoot
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

if (-not $EvidenceRoot) {
    $resolvedEvidence = Get-RepoEvidenceRoot -RepoRoot $repoRoot
}
else {
    $resolvedEvidence = Resolve-RepoPath -RepoRoot $repoRoot -Path $EvidenceRoot
}
if (-not (Test-Path $resolvedEvidence)) {
    Write-Warning ("Evidence root '$resolvedEvidence' not found; nothing to prune.")
    return
}

if ($RetentionDays -le 0) {
    $cutoff = [DateTime]::MinValue
}
else {
    $cutoff = (Get-Date).AddDays(-[double]$RetentionDays)
}

$summary = @()

function Prune-Entries {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    if (-not (Test-Path $TargetPath)) { return }
    $items = Get-ChildItem -Path $TargetPath -Force |
        Where-Object { $_.Name -ne '.gitkeep' } |
        Sort-Object LastWriteTime -Descending
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        $shouldDelete = $false
        if ($KeepRecent -gt 0 -and $i -ge $KeepRecent) {
            $shouldDelete = $true
        }
        if (-not $shouldDelete -and $RetentionDays -gt 0 -and $item.LastWriteTime -lt $cutoff) {
            $shouldDelete = $true
        }

        if ($shouldDelete) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $summary += [pscustomobject]@{
                    Path = $item.FullName
                    LastWriteTime = $item.LastWriteTime
                    Type = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
                }
            }
            catch {
                Write-Warning ("Failed to prune $($item.FullName): $($_.Exception.Message)")
            }
        }
    }
}

Prune-Entries -TargetPath $resolvedEvidence
Get-ChildItem -Path $resolvedEvidence -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Prune-Entries -TargetPath $_.FullName
}

if ($summary.Count -eq 0) {
    Write-Output 'No evidence artifacts required pruning.'
}
else {
    Write-Output 'Pruned evidence artifacts:'
    foreach ($entry in $summary) {
        Write-Output (" - {0} (last write: {1:yyyy-MM-dd HH:mm:ss}, {2})" -f $entry.Path, $entry.LastWriteTime, $entry.Type)
    }
}
