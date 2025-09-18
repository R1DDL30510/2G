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

function Ensure-Pester {
    param(
        [string]$MinVersion = '5.0.0',
        [string]$VendorRoot
    )
    if (-not $VendorRoot) { $VendorRoot = Join-Path $repoRoot 'scripts/vendor/Modules' }
    try { Import-Module Pester -MinimumVersion $MinVersion -ErrorAction Stop; return $true } catch {}
    if (-not (Test-Path $VendorRoot)) { try { New-Item -ItemType Directory -Path $VendorRoot -Force | Out-Null } catch {} }
    $env:PSModulePath = "$VendorRoot;" + $env:PSModulePath
    $candidate = Get-ChildItem -Path (Join-Path $VendorRoot 'Pester') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($candidate) {
        $psd1 = Get-ChildItem -Path $candidate.FullName -Filter 'Pester.psd1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($psd1) { try { Import-Module $psd1.FullName -MinimumVersion $MinVersion -ErrorAction Stop; return $true } catch {} }
    }
    if (Get-Command Save-Module -ErrorAction SilentlyContinue) {
        try {
            Save-Module -Name Pester -RequiredVersion $MinVersion -Path $VendorRoot -Force -ErrorAction Stop
            $psd1 = Get-ChildItem -Path (Join-Path $VendorRoot 'Pester') -Filter 'Pester.psd1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($psd1) { Import-Module $psd1.FullName -ErrorAction Stop; return $true }
        } catch { Write-Warning ('Failed to vendor Pester: ' + $_.Exception.Message) }
    }
    return $false
}


$settings = switch ($Mode) {
    'quick' { @{ RunPytest = $true; RunPester = $true; Compose = $false; Sweep = $false; CaptureState = $false; CpuOnly = $true } }
    'full'  { @{ RunPytest = $true; RunPester = $true; Compose = $true; Sweep = $true; CaptureState = $true; CpuOnly = -not $Gpu.IsPresent } }
}

if ($settings.Compose -and -not $ArtifactsRoot) {
    $defaultEvidence = Get-RepoEnvValue -RepoRoot $repoRoot -Key 'EVIDENCE_ROOT'
    if (-not $defaultEvidence) { $defaultEvidence = './docs/evidence' }
    $defaultEvidence = Resolve-RepoPath -RepoRoot $repoRoot -Path $defaultEvidence
    $ArtifactsRoot = Join-Path $defaultEvidence 'precommit'
}

if ($ArtifactsRoot) {
    if (-not [System.IO.Path]::IsPathRooted($ArtifactsRoot)) {
        $ArtifactsRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ArtifactsRoot
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
        if (Ensure-Pester -MinVersion '5.0.0') {
        Invoke-Pester -Script (Join-Path $repoRoot 'tests/pester') -Output Detailed
      } else {
        Write-Warning 'Pester not installed and cannot be vendored; skipping Pester tests.'
      }
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
            $sweepParams = @{ Safe = $true; WriteReport = $true }
            if ($settings.CpuOnly) { $sweepParams['CpuOnly'] = $true }
            if ($Gpu) { $sweepParams['Profile'] = 'llama31-long' }
            Invoke-Step "Context sweep" {
                & (Join-Path $repoRoot 'scripts/context-sweep.ps1') @sweepParams
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
            if ($LASTEXITCODE -ne 0) { throw "docker compose down failed with exit code $LASTEXITCODE" }
        } -Always
    }
}

Write-Host "Pre-commit checks completed successfully." -ForegroundColor Green

















