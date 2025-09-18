$script:repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

Describe 'scripts/compose.ps1' {
    BeforeAll {
        $script:composePath = Join-Path $script:repoRoot 'scripts/compose.ps1'
        $script:composeContent = [System.IO.File]::ReadAllText($script:composePath)
    }

    It 'declares expected actions' {
        ($script:composeContent -match "ValidateSet\('up','down','restart','logs'\)") | Should -BeTrue
    }
}

Describe 'scripts/bootstrap.ps1' {
    BeforeAll {
        $script:bootstrapPath = Join-Path $script:repoRoot 'scripts/bootstrap.ps1'
        $script:bootstrapContent = [System.IO.File]::ReadAllText($script:bootstrapPath)
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
        $script:sweepPath = Join-Path $script:repoRoot 'scripts/context-sweep.ps1'
        $script:sweepContent = [System.IO.File]::ReadAllText($script:sweepPath)
        $script:evalPath = Join-Path $script:repoRoot 'scripts/eval-context.ps1'
        $script:evalContent = [System.IO.File]::ReadAllText($script:evalPath)
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
