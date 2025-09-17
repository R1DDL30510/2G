param(
    [ValidateSet('pull','list','run','show','create','create-all')]
    [string]$Action = 'list',
    [string]$Model,
    [string]$Prompt,
    [int]$MainGpu = -1
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$composeFile = Join-Path $repoRoot 'infra\compose\docker-compose.yml'

function Get-OllamaId {
    $id = docker compose -f $composeFile ps -q ollama
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
    }
    else {
        docker exec -i $ContainerId ollama create $ModelName -f $file
    }
}

switch ($Action) {
    'list' {
        $id = Get-OllamaId
        docker exec -i $id ollama list
    }
    'pull' {
        if (-not $Model) {
            throw 'Specify -Model (e.g., llama3.1:8b)'
        }
        $id = Get-OllamaId
        docker exec -i $id ollama pull $Model
    }
    'create' {
        if (-not $Model) {
            throw 'Specify -Model name to create (e.g., llama31-8b-gpu)'
        }
        $id = Get-OllamaId
        $gpuIndex = if ($PSBoundParameters.ContainsKey('MainGpu')) { $MainGpu } else { -1 }
        Invoke-OllamaCreate -ContainerId $id -ModelName $Model -ModelfileName "$Model.Modelfile" -MainGpuIndex $gpuIndex
    }
    'create-all' {
        $id = Get-OllamaId
        $targets = @(
            @{ Name = 'llama31-8b-c4k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-c8k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-c16k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-c32k'; OverrideGpu = $false },
            @{ Name = 'llama31-8b-gpu'; OverrideGpu = $true }
        )
        foreach ($target in $targets) {
            $gpuIndex = if ($target.OverrideGpu -and $PSBoundParameters.ContainsKey('MainGpu')) { $MainGpu } else { -1 }
            try {
                Invoke-OllamaCreate -ContainerId $id -ModelName $target.Name -ModelfileName "$($target.Name).Modelfile" -MainGpuIndex $gpuIndex
            }
            catch {
                Write-Warning ("Failed to create {0}: {1}" -f $target.Name, $_.Exception.Message)
            }
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
            echo $content | docker exec -i $id ollama run $Model
        }
        else {
            docker exec -it $id ollama run $Model
        }
    }
    'show' {
        if (-not $Model) {
            throw 'Specify -Model'
        }
        $id = Get-OllamaId
        docker exec -i $id ollama show $Model
    }
}

