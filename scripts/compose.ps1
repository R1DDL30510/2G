param(
    [ValidateSet('up','down','restart','logs')]
    [string]$Action = 'up'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$composeFile = Join-Path $repoRoot 'infra\compose\docker-compose.yml'

if (-not (Test-Path $composeFile)) {
    Write-Error "Compose file not found at: $composeFile`nEnsure you are using the repo at $repoRoot"
    exit 1
}

$exitCode = 0

Push-Location $repoRoot
try {
    $composeArgs = @('compose', '-f', $composeFile)
    switch ($Action) {
        'up' { $composeArgs += @('up', '-d') }
        'down' { $composeArgs += @('down') }
        'restart' { $composeArgs += @('restart') }
        'logs' { $composeArgs += @('logs', '-f') }
    }

    & docker @composeArgs
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host ("docker compose $Action failed with exit code $exitCode") -ForegroundColor Red
    }
}
finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    exit $exitCode
}
