param(
    [ValidateSet('pull','list','run','show','create','create-all')]
    [string]$Action = 'list',
    [string]$Model,
    [string]$Prompt,
    [int]$MainGpu = -1
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

function Join-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string[]]$Parts
    )

    $current = $repoRoot
    foreach ($segment in $Parts) {
        $current = Join-Path -Path $current -ChildPath $segment
    }

    return $current
}

function Get-AvailableGpuIndices {
    try {
        $raw = & nvidia-smi --query-gpu=index --format=csv,noheader 2>$null
        $exit = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($exit -ne 0 -or -not $raw) {
            return @()
        }
    }
    catch {
        return @()
    }

    $indices = @()
    foreach ($line in $raw) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if ($trimmed -match '^(?<idx>[0-9]+)') {
            $indices += [int]$Matches['idx']
        }
    }

    return ($indices | Sort-Object -Unique)
}

function Get-DefaultGpuIndex {
    $preferred = 1
    $envValue = Get-RepoEnvValue -RepoRoot $repoRoot -Key 'DEFAULT_GPU_INDEX'
    if ($envValue) {
        $parsed = 0
        if ([int]::TryParse($envValue, [ref]$parsed)) {
            $preferred = $parsed
        }
    }

    $available = Get-AvailableGpuIndices
    if ($available.Count -gt 0 -and -not ($available -contains $preferred)) {
        $fallback = $available | Sort-Object | Select-Object -First 1
        Write-Warning ("Preferred GPU index {0} not detected; falling back to GPU {1}." -f $preferred, $fallback)
        return [int]$fallback
    }

    return [int]$preferred
}

function Test-ModelfileRequiresGpu {
    param([string]$ModelfileName)

    if (-not $ModelfileName) { return $false }
    $path = Join-RepoPath -Parts @('modelfiles', $ModelfileName)
    if (-not (Test-Path $path)) { return $false }

    return Select-String -Path $path -Pattern 'PARAMETER\s+num_gpu' -Quiet
}

$composeFile = Join-RepoPath -Parts @('infra', 'compose', 'docker-compose.yml')

function Assert-LastExitCode {
    param(
        [string]$Context
    )

    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    if ($exitCode -ne 0) {
        $message = if ($Context) {
            "$Context failed with exit code $exitCode"
        } else {
            "Command failed with exit code $exitCode"
        }
        throw $message
    }
}

function Get-OllamaId {
    $args = @('compose', '-f', $composeFile, 'ps', '-q', 'ollama')
    $idOutput = & docker @args
    Assert-LastExitCode 'docker compose ps ollama'

    $id = ($idOutput | Select-Object -Last 1).Trim()
    if (-not $id) {
        throw 'Ollama container not found. Is the stack up?'
    }
    return $id
}

function Invoke-OllamaCreate {
    param(
        [string]$ContainerId,
        [string]$ModelName,
        [string]$ModelfileName,
        [int]$MainGpuIndex = -1
    )

    $file = "/modelfiles/$ModelfileName"
    docker exec -i $ContainerId sh -lc "test -f $file" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Modelfile not found in container: $file"
    }

    if ($MainGpuIndex -ge 0) {
        $command = "tmp=`$(mktemp); cp $file `$tmp; if grep -q '^PARAMETER main_gpu' `$tmp; then sed -i 's/^PARAMETER main_gpu .*/PARAMETER main_gpu $MainGpuIndex/' `$tmp; else echo 'PARAMETER main_gpu $MainGpuIndex' >> `$tmp; fi; ollama create $ModelName -f `$tmp; rm -f `$tmp"
        docker exec -i $ContainerId sh -lc $command
        Assert-LastExitCode "ollama create $ModelName (overriding main_gpu)"
    }
    else {
        docker exec -i $ContainerId ollama create $ModelName -f $file
        Assert-LastExitCode "ollama create $ModelName"
    }
}

switch ($Action) {
    'list' {
        $id = Get-OllamaId
        docker exec -i $id ollama list
        Assert-LastExitCode 'ollama list'
    }
    'pull' {
        if (-not $Model) {
            throw 'Specify -Model (e.g., llama3.1:8b)'
        }
        $id = Get-OllamaId
        docker exec -i $id ollama pull $Model
        Assert-LastExitCode "ollama pull $Model"
    }
    'create' {
        if (-not $Model) {
            throw 'Specify -Model name to create (e.g., llama31-8b-gpu)'
        }
        $id = Get-OllamaId
        $modelfileName = "$Model.Modelfile"
        $gpuIndex = -1
        if ($PSBoundParameters.ContainsKey('MainGpu')) {
            $gpuIndex = $MainGpu
        }
        elseif (Test-ModelfileRequiresGpu -ModelfileName $modelfileName) {
            $gpuIndex = Get-DefaultGpuIndex
        }
        Invoke-OllamaCreate -ContainerId $id -ModelName $Model -ModelfileName $modelfileName -MainGpuIndex $gpuIndex
    }
    'create-all' {
        $id = Get-OllamaId
        $defaultGpuIndex = Get-DefaultGpuIndex
        $targets = @(
            @{ Name = 'llama31-8b-c4k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-c8k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-c16k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-c32k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-gpu'; OverrideGpu = $true }
        )
        $failedCreates = @()
        foreach ($target in $targets) {
            $gpuIndex = -1
            if ($target.OverrideGpu) {
                if ($PSBoundParameters.ContainsKey('MainGpu')) {
                    $gpuIndex = $MainGpu
                }
                else {
                    $gpuIndex = $defaultGpuIndex
                }
            }
            try {
                Invoke-OllamaCreate -ContainerId $id -ModelName $target.Name -ModelfileName "${($target.Name)}.Modelfile" -MainGpuIndex $gpuIndex
            }
            catch {
                $failedCreates += $target.Name
                Write-Warning ("Failed to create {0}: {1}" -f $target.Name, $_.Exception.Message)
            }
        }
        if ($failedCreates.Count -gt 0) {
            throw ("One or more models failed to create: {0}" -f ($failedCreates -join ', '))
        }
    }
    'run' {
        if (-not $Model) {
            throw 'Specify -Model'
        }
        $id = Get-OllamaId
        if ($Prompt) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Prompt)
            $stream = [System.IO.MemoryStream]::new($bytes)
            $reader = [System.IO.StreamReader]::new($stream)
            $content = $reader.ReadToEnd()
            $content | docker exec -i $id ollama run $Model
            Assert-LastExitCode "ollama run $Model"
        }
        else {
            docker exec -it $id ollama run $Model
            Assert-LastExitCode "ollama run $Model"
        }
    }
    'show' {
        if (-not $Model) {
            throw 'Specify -Model'
        }
        $id = Get-OllamaId
        docker exec -i $id ollama show $Model
        Assert-LastExitCode "ollama show $Model"
    }
}
