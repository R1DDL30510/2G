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

Push-Location $repoRoot
try {
    switch ($Action) {
        'up' { docker compose -f $composeFile up -d }
        'down' { docker compose -f $composeFile down }
        'restart' { docker compose -f $composeFile restart }
        'logs' { docker compose -f $composeFile logs -f }
    }
}
finally { Pop-Location }

