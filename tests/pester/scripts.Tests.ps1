if (-not $PSScriptRoot) {
    throw "PSScriptRoot was not populated; unable to determine repository root."
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if (-not $repoRoot) {
    throw "Unable to resolve repository root from PSScriptRoot: $PSScriptRoot"
}

if (-not (Test-Path -Path $repoRoot -PathType Container)) {
    throw "Resolved repository root does not exist: $repoRoot"
}

function Get-RequiredFileContent {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $RelativePath
    )

    $fullPath = Join-Path -Path $repoRoot -ChildPath $RelativePath

    if (-not $fullPath) {
        throw "Failed to build a path for '$RelativePath' from repository root '$repoRoot'."
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required file not found: $fullPath"
    }

    return Get-Content -LiteralPath $fullPath -Raw
}

Describe 'scripts/compose.ps1' {
    BeforeAll {
        $script:composeContent = Get-RequiredFileContent -RelativePath 'scripts/compose.ps1'
    }

    It 'declares expected actions' {
        ($script:composeContent -match "ValidateSet\('up','down','restart','logs'\)") | Should -BeTrue
    }
}

Describe 'scripts/bootstrap.ps1' {
    BeforeAll {
        $script:bootstrapContent = Get-RequiredFileContent -RelativePath 'scripts/bootstrap.ps1'
    }

    It 'supports PromptSecrets switch' {
        ($script:bootstrapContent -match '\[switch\]\$PromptSecrets') | Should -BeTrue
    }

    It 'initialises context sweep profile entry' {
        $pattern = '(?s)function\s+Invoke-WorkspaceProvisioning.*?Ensure-EnvEntry\s+-Path\s+\$envLocal\s+-Key\s+''CONTEXT_SWEEP_PROFILE'''
        ($script:bootstrapContent -match $pattern) | Should -BeTrue
    }
}

Describe 'context evaluation tooling' {
    BeforeAll {
        $script:sweepPath = Join-Path -Path $repoRoot -ChildPath 'scripts/context-sweep.ps1'
        $script:sweepContent = Get-Content -Path $script:sweepPath -Raw
        $script:evalPath = Join-Path -Path $repoRoot -ChildPath 'scripts/eval-context.ps1'
        $script:evalContent = Get-Content -Path $script:evalPath -Raw
    }

    It 'context sweep exposes built-in profiles' {
        foreach ($profile in @('llama31-long','qwen3-balanced','cpu-baseline')) {
            $pattern = [regex]::Escape($profile)
            ($script:sweepContent -match $pattern) | Should -BeTrue
        }
    }

    It 'eval-context exposes CpuOnly switch' {
        ($script:evalContent -match '\[switch\]\$CpuOnly') | Should -BeTrue
    }
}

Describe 'scripts/clean/prune_evidence.ps1' {
    BeforeAll {
        $script:prunePath = Join-Path -Path $repoRoot -ChildPath 'scripts/clean/prune_evidence.ps1'
        $script:pruneContent = Get-Content -Path $script:prunePath -Raw
    }

    It 'defines Keep parameter with default of 5' {
        ($script:pruneContent -match "\[int\]\$Keep = 5") | Should -BeTrue
    }

    It 'reads EVIDENCE_ROOT from .env when Root not provided' {
        ($script:pruneContent -match "Get-EnvValue -Key 'EVIDENCE_ROOT'") | Should -BeTrue
    }
}
