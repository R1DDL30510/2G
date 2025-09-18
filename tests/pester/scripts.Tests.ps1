$script:here = if ($PesterScriptRoot) {
    $PesterScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).ProviderPath
}

$script:repoRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($script:here, '..', '..')
)

Describe 'scripts/compose.ps1' {
    BeforeAll {
        $script:composePath = Join-Path $script:repoRoot 'scripts/compose.ps1'
        $script:composeContent = Get-Content -Path $script:composePath -Raw
    }

    It 'declares expected actions' {
        $script:composeContent | Should -Match "ValidateSet\('up','down','restart','logs'\)"
    }
}

Describe 'scripts/bootstrap.ps1' {
    BeforeAll {
        $script:bootstrapPath = Join-Path $script:repoRoot 'scripts/bootstrap.ps1'
        $script:bootstrapContent = Get-Content -Path $script:bootstrapPath -Raw
    }

    It 'supports PromptSecrets switch' {
        $script:bootstrapContent | Should -Match '\[switch\]\$PromptSecrets'
    }

    It 'initialises context sweep profile entry' {
        $pattern = '(?s)function\s+Invoke-WorkspaceProvisioning.*?Ensure-EnvEntry\s+-Path\s+\$envLocal\s+-Key\s+''CONTEXT_SWEEP_PROFILE''' 
        $script:bootstrapContent | Should -Match $pattern
    }

    It 'Get-EnvValue returns captured assignment value' {
        $pattern = '(?s)function\s+Get-EnvValue.*?return\s+\$Matches\[1\]\.Trim\(\)'
        $script:bootstrapContent | Should -Match $pattern
    }
}

Describe 'context evaluation tooling' {
    BeforeAll {
        $script:sweepPath = Join-Path $script:repoRoot 'scripts/context-sweep.ps1'
        $script:sweepContent = Get-Content -Path $script:sweepPath -Raw
        $script:evalPath = Join-Path $script:repoRoot 'scripts/eval-context.ps1'
        $script:evalContent = Get-Content -Path $script:evalPath -Raw
    }

    It 'context sweep exposes built-in profiles' {
        foreach ($profile in @('llama31-long','qwen3-balanced','cpu-baseline')) {
            $pattern = [regex]::Escape($profile)
            $script:sweepContent | Should -Match $pattern
        }
    }

    It 'eval-context exposes CpuOnly switch' {
        $script:evalContent | Should -Match '\[switch\]\$CpuOnly'
    }
}
