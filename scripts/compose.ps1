param(
    [ValidateSet('up','down','restart','logs')]
    [string]$Action = 'up',
    [string[]]$File = @()
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$composeRoot = Join-Path -Path $repoRoot -ChildPath 'infra/compose'
$composeFile = Join-Path -Path $composeRoot -ChildPath 'docker-compose.yml'

function Resolve-ComposePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path -Path $composeRoot -ChildPath $Path
}

if (-not (Test-Path $composeFile)) {
    Write-Error "Compose file not found at: $composeFile`nEnsure you are using the repo at $repoRoot"
    exit 1
}

$composeFile = (Get-Item -LiteralPath $composeFile).FullName

$envFile = Join-Path -Path $repoRoot -ChildPath '.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    $envTemplate = Join-Path -Path $repoRoot -ChildPath '.env.example'
    if (Test-Path -LiteralPath $envTemplate) {
        Write-Warning "No .env found at $envFile. Falling back to template overrides."
        $envFile = $envTemplate
    }
    else {
        Write-Error "No environment file found. Create .env or copy from .env.example first."
        exit 1
    }
}

$envFile = (Get-Item -LiteralPath $envFile).FullName

$exitCode = 0

Push-Location $repoRoot
try {
    $composeArgs = @('compose', '--env-file', $envFile, '-f', $composeFile)

    foreach ($overlay in $File) {
        $resolved = Resolve-ComposePath -Path $overlay
        if (-not (Test-Path -LiteralPath $resolved)) {
            Write-Error "Compose overlay not found: $overlay"
            exit 1
        }
        $composeArgs += @('-f', (Get-Item -LiteralPath $resolved).FullName)
    }

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
