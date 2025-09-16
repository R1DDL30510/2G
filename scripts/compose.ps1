param(
    [ValidateSet('up','down','restart','logs')]
    [string]$Action = 'up'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$composeFile = Join-Path $root '..\infra\compose\docker-compose.yml'
Push-Location (Join-Path $root '..')
try {
    switch ($Action) {
        'up' { docker compose -f $composeFile up -d }
        'down' { docker compose -f $composeFile down }
        'restart' { docker compose -f $composeFile restart }
        'logs' { docker compose -f $composeFile logs -f }
    }
}
finally { Pop-Location }

