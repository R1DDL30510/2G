param(
    [switch]$Report,
    [switch]$PromptSecrets,
    [switch]$Menu,
    [switch]$NoMenu
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$docsRoot = Join-Path $repoRoot 'docs'

function Invoke-CommandSafely {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    $result = [pscustomobject]@{
        Success = $false
        Output  = ''
        ExitCode = $null
        Error   = $null
    }

    try {
        $output = & $Command @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        $text = ($output | Out-String).Trim()
        if ($exitCode -eq $null -or $exitCode -eq 0) {
            $result.Success = $true
        }
        elseif (-not $text) {
            $text = "Exit code $exitCode"
        }
        $result.ExitCode = $exitCode
        $result.Output = $text
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

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

function Get-EvidenceRoot {
    $configured = Get-EnvValue -Key 'EVIDENCE_ROOT'
    $envLocalPath = Join-Path $repoRoot '.env'
    $null = Ensure-EnvEntry -Path $envLocalPath -Key 'CONTEXT_SWEEP_PROFILE' -DefaultValue 'baseline-cpu' -Comment 'Default context sweep profile (baseline-cpu).' -PromptValue:$PromptSecrets
    if ($configured) {
        if ([System.IO.Path]::IsPathRooted($configured)) {
            return $configured
        }
        return Join-Path $repoRoot $configured
    }
    return Join-Path $repoRoot 'docs/evidence'
}

function New-EvidenceFile {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Prefix,
        [string[]]$Content,
        [string]$Extension = 'md'
    )

    $targetRoot = Get-EvidenceRoot
    Ensure-Directory -Path $targetRoot
    $categoryPath = Join-Path $targetRoot $Category
    Ensure-Directory -Path $categoryPath

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $fileName = "{0}-{1}.{2}" -f $Prefix, $timestamp, $Extension
    $fullPath = Join-Path $categoryPath $fileName

    if ($Content) {
        Set-Content -Path $fullPath -Value ($Content -join "`n") -Encoding UTF8
    }
    else {
        New-Item -Path $fullPath -ItemType File -Force | Out-Null
    }

    return $fullPath
}

function Ensure-EnvEntry {
    param(
        [string]$Path,
        [string]$Key,
        [string]$DefaultValue,
        [string]$Comment,
        [switch]$PromptValue
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $lines = @(Get-Content -Path $Path)
    $index = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^\s*{0}=" -f [regex]::Escape($Key))) {
            $index = $i
            break
        }
    }

    if ($null -eq $index) {
        if ($Comment) {
            Add-Content -Path $Path -Value ("# " + $Comment)
        }
        Add-Content -Path $Path -Value ("$Key=$DefaultValue")
        Write-Output ("Added {0} to .env (default applied)." -f $Key)
        return $DefaultValue
    }

    $parts = $lines[$index].Split('=', 2)
    $currentValue = if ($parts.Length -gt 1) { $parts[1] } else { '' }
    $valueToSet = $currentValue
    $needsWrite = $false

    if (-not $currentValue.Trim()) {
        $valueToSet = $DefaultValue
        if ($PromptValue.IsPresent) {
            $input = Read-Host -Prompt ("Value for {0} (Enter to keep default '{1}')" -f $Key, $DefaultValue)
            if ($input) {
                $valueToSet = $input
            }
        }
        $needsWrite = $true
    }
    elseif ($PromptValue.IsPresent) {
        $input = Read-Host -Prompt ("Update {0}? Current value '{1}' (Enter to keep)" -f $Key, $currentValue)
        if ($input) {
            $valueToSet = $input
            $needsWrite = $true
        }
    }

    if ($needsWrite) {
        $lines[$index] = "$Key=$valueToSet"
        Set-Content -Path $Path -Value $lines -Encoding UTF8
        Write-Output ("Updated {0} in .env." -f $Key)
    }

    return $valueToSet
}

function Invoke-VersionCheck {
    param(
        [string]$Name,
        [string]$Command,
        [string[]]$Arguments = @(),
        [switch]$Mandatory
    )

    $result = Invoke-CommandSafely -Command $Command -Arguments $Arguments
    $status = if ($result.Success -and $result.Output) { $result.Output.Split("`n")[0] } elseif ($result.Error) { $result.Error } else { 'Not detected' }

    return [pscustomobject]@{
        Name = $Name
        Command = $Command
        Arguments = $Arguments
        Status = $status
        Success = $result.Success
        Mandatory = $Mandatory.IsPresent
    }
}

function Get-GpuInventory {
    $gpuLines = @()
    $nvidiaList = Invoke-CommandSafely -Command 'nvidia-smi' -Arguments @('-L')
    if ($nvidiaList.Success -and $nvidiaList.Output) {
        $gpuLines += ($nvidiaList.Output -split "`n" | Where-Object { $_.Trim() })
    }

    if (-not $gpuLines.Count) {
        try {
            $controllers = Get-CimInstance Win32_VideoController | Sort-Object Name
            if ($controllers) {
                foreach ($controller in $controllers) {
                    $gpuLines += ("{0} ({1} MB)" -f $controller.Name, [math]::Round($controller.AdapterRAM / 1MB, 2))
                }
            }
        }
        catch {
            $gpuLines = @()
        }
    }

    if (-not $gpuLines.Count) {
        $gpuLines = @('No NVIDIA GPU detected (nvidia-smi unavailable).')
    }

    return $gpuLines
}

function Invoke-EnvironmentReport {
    $reportLines = @('# Environment Report', '', '*Generated by scripts/bootstrap.ps1 -Report*', '')

    try {
        $os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1
        if ($os) {
            $reportLines += "- OS: $($os.Caption) $($os.Version) (Build $($os.BuildNumber))"
            $reportLines += "- Architecture: $($os.OSArchitecture)"
        }
        else {
            $reportLines += "- OS: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
            $reportLines += "- Architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
        }
    }
    catch {
        $reportLines += "- OS: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
        $reportLines += "- Architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
    }

    $reportLines += "- PowerShell: $($PSVersionTable.PSVersion)"
    $reportLines += ''

    $reportLines += '## Tooling'
    $reportLines += ''

    $probes = @(
        Invoke-VersionCheck -Name 'Git' -Command 'git' -Arguments @('--version') -Mandatory
        Invoke-VersionCheck -Name 'Docker' -Command 'docker' -Arguments @('--version') -Mandatory
        Invoke-VersionCheck -Name 'Docker Compose' -Command 'docker' -Arguments @('compose', 'version') -Mandatory
        Invoke-VersionCheck -Name 'WSL' -Command 'wsl' -Arguments @('--status')
        Invoke-VersionCheck -Name 'Python' -Command 'python' -Arguments @('--version')
        Invoke-VersionCheck -Name 'Node' -Command 'node' -Arguments @('-v')
        Invoke-VersionCheck -Name 'npm' -Command 'npm' -Arguments @('-v')
        Invoke-VersionCheck -Name '.NET' -Command 'dotnet' -Arguments @('--info')
        Invoke-VersionCheck -Name 'curl' -Command 'curl' -Arguments @('--version')
        Invoke-VersionCheck -Name 'pytest' -Command 'pytest' -Arguments @('--version')
        Invoke-VersionCheck -Name 'nvidia-smi' -Command 'nvidia-smi' -Arguments @('--query-gpu=name,memory.total', '--format=csv,noheader')
        Invoke-VersionCheck -Name 'ollama' -Command 'ollama' -Arguments @('--version')
        Invoke-VersionCheck -Name 'PowerShell (pwsh)' -Command 'pwsh' -Arguments @('--version')
    )

    foreach ($probe in $probes) {
        $status = if ($probe.Success) { $probe.Status } else { "Not detected" }
        if (-not $probe.Success -and $probe.Mandatory) {
            $status = "Missing (required)"
        }
        elseif (-not $probe.Success -and $probe.Status -and $probe.Status -ne 'Not detected') {
            $status = $probe.Status
        }
        $reportLines += "- **$($probe.Name)**: $status"
    }


    $failedMandatory = $probes | Where-Object { $_.Mandatory -and -not $_.Success }
    $reportLines += ''
    $reportLines += '## GPU Inventory'
    $reportLines += ''
    foreach ($line in Get-GpuInventory) {
        $reportLines += "- $line"
    }

    $envPath = Join-Path $docsRoot 'ENVIRONMENT.md'
    Set-Content -Path $envPath -Value ($reportLines -join "`n") -Encoding UTF8
    Write-Output "Wrote $envPath"

    $evidencePath = New-EvidenceFile -Category 'environment' -Prefix 'environment-report' -Content $reportLines
    Write-Output "Archived detailed report under $evidencePath"

    if ($failedMandatory -and $failedMandatory.Count -gt 0) {
        $missing = $failedMandatory | ForEach-Object { $_.Name }
        throw ("Missing required tooling: {0}" -f ($missing -join ', '))
    }
}

function Invoke-GpuEvaluation {
    $lines = @('# GPU Evaluation', '', '*Generated via scripts/bootstrap.ps1*', '')
    $lines += '## Detected devices'
    $lines += ''
    foreach ($line in Get-GpuInventory) {
        $lines += "- $line"
    }

    $query = Invoke-CommandSafely -Command 'nvidia-smi' -Arguments @('--query-gpu=index,name,memory.total,memory.free,utilization.gpu,utilization.memory,temperature.gpu,driver_version', '--format=csv,noheader')
    if ($query.Success -and $query.Output) {
        $lines += ''
        $lines += '## Utilization snapshot'
        $lines += ''
        $lines += '| GPU | Name | Memory total | Memory free | Utilization GPU | Utilization Mem | Temp | Driver |'
        $lines += '| --- | --- | --- | --- | --- | --- | --- | --- |'
        foreach ($row in $query.Output -split "`n") {
            if (-not $row.Trim()) { continue }
            $cells = $row.Split(',').Trim()
            $lines += "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f $cells
        }
    }
    else {
        $lines += ''
        $lines += 'nvidia-smi not available; unable to query utilization.'
    }

    $full = New-EvidenceFile -Category 'gpu' -Prefix 'gpu-evaluation' -Content $lines
    Write-Output "GPU evaluation saved to $full"
}

function Invoke-HostVerification {
    $lines = @('# Host health checks', '', '*Generated via scripts/bootstrap.ps1*', '')
    $checks = @()

    $checks += [pscustomobject]@{ Name = 'Docker daemon'; Result = Invoke-CommandSafely -Command 'docker' -Arguments @('info', '--format', '{{.ServerVersion}}'); Description = 'Verifies Docker engine availability.' }

    $composeFile = [System.IO.Path]::Combine($repoRoot, 'infra', 'compose', 'docker-compose.yml')
    if (Test-Path $composeFile) {
        $checks += [pscustomobject]@{ Name = 'Compose file validation'; Result = Invoke-CommandSafely -Command 'docker' -Arguments @('compose', '-f', $composeFile, 'config'); Description = 'Ensures docker-compose.yml parses.' }
    }
    else {
        $lines += '- Compose file missing; skipped validation.'
    }

    $ollamaUrl = Get-EnvValue -Key 'OLLAMA_BASE_URL'
    if (-not $ollamaUrl) {
        $ollamaUrl = 'http://localhost:11434'
    }

    $checks += [pscustomobject]@{ Name = 'Ollama endpoint'; Result = $null; Description = "GET $ollamaUrl/api/version" }
    try {
        $response = Invoke-RestMethod -Uri ("{0}/api/version" -f $ollamaUrl.TrimEnd('/')) -Method Get -TimeoutSec 5
        $checks[-1].Result = [pscustomobject]@{ Success = $true; Output = $response.version; ExitCode = 0 }
    }
    catch {
        $checks[-1].Result = [pscustomobject]@{ Success = $false; Output = $_.Exception.Message }
    }

    foreach ($check in $checks) {
        if ($null -eq $check.Result) { continue }
        $status = if ($check.Result.Success) { 'OK' } else { 'FAIL' }
        $detail = if ($check.Result.Output) { ($check.Result.Output -split "`n")[0] } else { '' }
        $lines += "- **$($check.Name)**: $status $detail"
    }

    $path = New-EvidenceFile -Category 'host-checks' -Prefix 'host-health' -Content $lines
    Write-Output "Host checks archived to $path"
}

function Invoke-WorkspaceProvisioning {
    param([switch]$PromptSecrets)

    $envSample = Join-Path $repoRoot '.env.example'
    $envLocal = Join-Path $repoRoot '.env'
    if ((Test-Path $envSample) -and -not (Test-Path $envLocal)) {
        Copy-Item $envSample $envLocal
        Write-Output 'Created .env from .env.example'
    }

    $null = Ensure-EnvEntry -Path $envLocal -Key 'OLLAMA_IMAGE' -DefaultValue 'ollama/ollama' -Comment 'Base image used by the baseline stack. Override to experiment with alternative tags.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'OLLAMA_PORT' -DefaultValue '11434' -Comment 'Host port forwarded to the Ollama API container.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'MODELS_DIR' -DefaultValue './models' -Comment 'Relative directory used to persist downloaded Ollama models.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'OLLAMA_API_KEY' -DefaultValue 'ollama-local' -Comment 'Dummy key required by Codex CLI workflows when proxying to local Ollama. Replace with a real token if bridging to remote services.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'OLLAMA_BASE_URL' -DefaultValue 'http://localhost:11434' -Comment 'Base URL for local Ollama API. Used by health checks and benchmarking.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'OLLAMA_BENCH_MODEL' -DefaultValue 'llama3.1' -Comment 'Default model targeted by scripts/clean/bench_ollama.ps1.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'OLLAMA_BENCH_PROMPT' -DefaultValue './docs/prompts/bench-default.txt' -Comment 'Prompt file consumed by bench_ollama.ps1 during latency sampling.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'EVIDENCE_ROOT' -DefaultValue './docs/evidence' -Comment 'Destination directory for diagnostics artifacts.' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'CONTEXT_SWEEP_PROFILE' -DefaultValue 'baseline-cpu' -Comment 'Default context sweep profile (baseline-cpu).' -PromptValue:$PromptSecrets
    $null = Ensure-EnvEntry -Path $envLocal -Key 'LOG_FILE' -DefaultValue './logs/stack.log' -Comment 'Relative path for stack diagnostics emitted by helper scripts.' -PromptValue:$PromptSecrets

    foreach ($directory in @('data', 'models')) {
        Ensure-Directory -Path (Join-Path $repoRoot $directory)
    }
    Ensure-Directory -Path (Join-Path $repoRoot 'logs')
    Ensure-Directory -Path (Get-EvidenceRoot)
    Ensure-Directory -Path (Join-Path $docsRoot 'prompts')

    $dependencyChecks = @(
        @{ Name = 'Docker'; Cmd = 'docker'; Args = @('--version'); Mandatory = $true },
        @{ Name = 'Codex CLI'; Cmd = 'codex'; Args = @('--version'); Mandatory = $false },
        @{ Name = 'curl'; Cmd = 'curl'; Args = @('--version'); Mandatory = $false }
    )

    foreach ($check in $dependencyChecks) {
        $result = Invoke-CommandSafely -Command $check.Cmd -Arguments $check.Args
        if ($result.Success -and $result.Output) {
            Write-Output ("Detected {0}: {1}" -f $check.Name, $result.Output.Split("`n")[0])
        }
        elseif ($check.Mandatory) {
            Write-Warning ("{0} not detected. Install it before running compose operations." -f $check.Name)
        }
        else {
            Write-Warning ("Optional tool missing: {0}." -f $check.Name)
        }
    }
}

function Invoke-CaptureState {
    $scriptPath = Join-Path $repoRoot 'scripts/clean/capture_state.ps1'
    if (Test-Path $scriptPath) {
        & $scriptPath
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($exitCode -ne 0) {
            throw "capture_state.ps1 failed with exit code $exitCode"
        }
    }
    else {
        Write-Warning 'capture_state.ps1 not found under scripts/clean.'
    }
}

function Invoke-Bench {
    $scriptPath = Join-Path $repoRoot 'scripts/clean/bench_ollama.ps1'
    if (Test-Path $scriptPath) {
        & $scriptPath
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($exitCode -ne 0) {
            throw "bench_ollama.ps1 failed with exit code $exitCode"
        }
    }
    else {
        Write-Warning 'bench_ollama.ps1 not found under scripts/clean.'
    }
}

function Show-MainMenu {
    while ($true) {
        Write-Host ''
        Write-Host 'Bootstrap utility menu' -ForegroundColor Cyan
        Write-Host '----------------------------------' -ForegroundColor Cyan
        Write-Host '[1] Provision workspace (.env, data/, models/)'
        Write-Host '[2] Generate environment report'
        Write-Host '[3] Run GPU evaluation snapshot'
        Write-Host '[4] Run host health checks'
        Write-Host '[5] Capture host state (scripts/clean/capture_state.ps1)'
        Write-Host '[6] Run Ollama benchmark (scripts/clean/bench_ollama.ps1)'
        Write-Host '[0] Exit'
        $choice = Read-Host 'Select option'

        switch ($choice) {
            '1' { Invoke-WorkspaceProvisioning -PromptSecrets:$PromptSecrets }
            '2' { Invoke-EnvironmentReport }
            '3' { Invoke-GpuEvaluation }
            '4' { Invoke-HostVerification }
            '5' { Invoke-CaptureState }
            '6' { Invoke-Bench }
            '0' { break }
            default { Write-Warning 'Unrecognized option. Enter a number from the menu.' }
        }
    }
}

if ($Report) {
    Invoke-EnvironmentReport
    exit 0
}

Invoke-WorkspaceProvisioning -PromptSecrets:$PromptSecrets

$shouldLaunchMenu = $Menu.IsPresent -or (($PSBoundParameters.Count -eq 0) -and -not $NoMenu.IsPresent)
if ($shouldLaunchMenu) {
    Show-MainMenu
}
else {
    Write-Output 'Bootstrap complete. Use scripts/compose.ps1 to manage the stack.'
}


