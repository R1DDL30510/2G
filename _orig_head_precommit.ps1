param(
    [ValidateSet('quick', 'full')]
    [string]$Mode = 'quick',
    [switch]$InstallPythonDeps,
    [switch]$InstallPester,
    [switch]$Gpu,
    [string]$ArtifactsRoot,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

function Resolve-Tool {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Alternatives
    )

    $candidates = @($Name)
    if ($Alternatives) { $candidates += $Alternatives }
    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    throw "Required tool '$Name' not found."
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [switch]$Always
    )

    Write-Host "==> $Name"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action
    }
    catch {
        $timer.Stop()
        Write-Host "<== $Name (failed after $([math]::Round($timer.Elapsed.TotalSeconds,2))s)" -ForegroundColor Red
        throw
    }
    $timer.Stop()
    Write-Host "<== $Name (completed in $([math]::Round($timer.Elapsed.TotalSeconds,2))s)" -ForegroundColor Green
}

function Ensure-EnvFile {
    $envPath = Join-Path $repoRoot '.env'
    if (-not (Test-Path $envPath)) {
        $template = Join-Path $repoRoot '.env.example'
        if (-not (Test-Path $template)) {
            throw 'Missing .env and .env.example; run scripts/bootstrap.ps1 first.'
        }
        Copy-Item $template $envPath
        Write-Host 'Created .env from template.'
    }
}

$settings = switch ($Mode) {
    'quick' { @{ RunPytest = $true; RunPester = $true; Compose = $false; Sweep = $false; CaptureState = $false; CpuOnly = $true } }
    'full'  { @{ RunPytest = $true; RunPester = $true; Compose = $true; Sweep = $true; CaptureState = $true; CpuOnly = -not $Gpu.IsPresent } }
}

if ($settings.Compose -and -not $ArtifactsRoot) {
    $ArtifactsRoot = 'docs/evidence/precommit'
}

if ($ArtifactsRoot) {
    if (-not [System.IO.Path]::IsPathRooted($ArtifactsRoot)) {
        $ArtifactsRoot = Join-Path $repoRoot $ArtifactsRoot
    }
    if (-not (Test-Path $ArtifactsRoot)) {
        New-Item -ItemType Directory -Path $ArtifactsRoot | Out-Null
    }
    Set-Item -Path Env:EVIDENCE_ROOT -Value $ArtifactsRoot
    if ($Verbose) { Write-Host "EVIDENCE_ROOT set to $ArtifactsRoot" }
}

Ensure-EnvFile

if ($InstallPythonDeps) {
    $python = Resolve-Tool -Name 'python' -Alternatives @('py')
    Invoke-Step "Install Python dev dependencies" {
        & $python -m pip install -r (Join-Path $repoRoot 'requirements-dev.txt')
        if ($LASTEXITCODE -ne 0) { throw "pip install failed with exit code $LASTEXITCODE" }
    }
}

if ($InstallPester -and -not (Get-Module -ListAvailable -Name Pester)) {
    Invoke-Step "Install Pester" {
        Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
    }
}

if (-not $InstallPester -and -not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host 'Pester module not found; pass -InstallPester to install automatically.' -ForegroundColor Yellow
}

if ($settings.RunPytest) {
    $python = Resolve-Tool -Name 'python' -Alternatives @('py')
    Invoke-Step "Run pytest" {
        Push-Location $repoRoot
        try {
            & $python -m pytest --maxfail=1 --disable-warnings -q
            if ($LASTEXITCODE -ne 0) { throw "pytest failed with exit code $LASTEXITCODE" }
        }
        finally {
            Pop-Location
        }
    }
}

if ($settings.RunPester) {
    Invoke-Step "Run Pester" {
        Import-Module Pester -MinimumVersion 5 -ErrorAction Stop
        Invoke-Pester -Script (Join-Path $repoRoot 'tests/pester') -Output Detailed
    }
}

if ($settings.Compose) {
    $composeFiles = @(
        (Join-Path $repoRoot 'infra/compose/docker-compose.yml')
    )
    if ($settings.CpuOnly) {
        $composeFiles += (Join-Path $repoRoot 'infra/compose/docker-compose.ci.yml')
    }
    else {
        $composeFiles += (Join-Path $repoRoot 'infra/compose/docker-compose.gpu.yml')
    }
    $composeArgs = @()
    foreach ($file in $composeFiles) {
        $composeArgs += @('-f', $file)
    }

    Invoke-Step "docker compose up" {
        & docker compose @composeArgs up -d
        if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }
    }

    try {
        Invoke-Step "Wait for services" {
            $python = Resolve-Tool -Name 'python' -Alternatives @('py')
            & $python (Join-Path $repoRoot 'scripts/wait_for_http.py') --retries 24 --delay 5 --timeout 5 `
                'http://localhost:11434/api/version' `
                'http://localhost:6333/collections' `
                'http://localhost:3000'
            if ($LASTEXITCODE -ne 0) { throw "Service wait failed" }
        }

        if ($settings.Sweep) {
            $sweepArgs = @('-Safe', '-WriteReport')
            if ($settings.CpuOnly) { $sweepArgs += '-CpuOnly' }
            if ($Gpu) { $sweepArgs += '-Profile'; $sweepArgs += 'llama31-long' }
            Invoke-Step "Context sweep" {
                & (Join-Path $repoRoot 'scripts/context-sweep.ps1') @sweepArgs
                if ($LASTEXITCODE -ne 0) { throw "Context sweep failed" }
            }
        }

        if ($settings.CaptureState) {
            Invoke-Step "Capture state" {
                & (Join-Path $repoRoot 'scripts/clean/capture_state.ps1')
                if ($LASTEXITCODE -ne 0) { throw "State capture failed" }
            }
        }
    }
    finally {
        Invoke-Step "docker compose down" {
            & docker compose @composeArgs down -v
        } -Always
    }
}

Write-Host "Pre-commit checks completed successfully." -ForegroundColor Green










