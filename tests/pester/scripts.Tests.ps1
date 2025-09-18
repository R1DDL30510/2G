if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

if (-not $PSScriptRoot) {
    throw "PSScriptRoot was not populated; unable to determine repository root."
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Describe 'scripts/compose.ps1' {
    BeforeAll {
        $script:composePath = Join-Path -Path $repoRoot -ChildPath 'scripts/compose.ps1'
        $script:composeContent = Get-Content -Path $script:composePath -Raw
    }

    It 'declares expected actions' {
        ($script:composeContent -match "ValidateSet\('up','down','restart','logs'\)") | Should -BeTrue
    }
}

Describe 'scripts/bootstrap.ps1' {
    BeforeAll {
        $script:bootstrapPath = Join-Path -Path $repoRoot -ChildPath 'scripts/bootstrap.ps1'
        $script:bootstrapContent = Get-Content -Path $script:bootstrapPath -Raw
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
