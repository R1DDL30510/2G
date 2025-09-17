$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

Describe 'scripts/compose.ps1' {
    $composePath = Join-Path $repoRoot 'scripts/compose.ps1'
    $composeContent = Get-Content -Path $composePath -Raw

    It 'declares expected actions' {
        $composeContent | Should Match 'ValidateSet\(''up'',''down'',''restart'',''logs''\)'
    }
}

Describe 'scripts/bootstrap.ps1' {
    $bootstrapPath = Join-Path $repoRoot 'scripts/bootstrap.ps1'
    $bootstrapContent = Get-Content -Path $bootstrapPath -Raw

    It 'supports PromptSecrets switch' {
        $bootstrapContent | Should Match '\[switch\]\$PromptSecrets'
    }

    It 'initialises context sweep profile entry' {
        $bootstrapContent | Should Match 'CONTEXT_SWEEP_PROFILE'
    }
}

Describe 'context evaluation tooling' {
    $sweepPath = Join-Path $repoRoot 'scripts/context-sweep.ps1'
    $sweepContent = Get-Content -Path $sweepPath -Raw

    It 'context sweep exposes built-in profiles' {
        foreach ($profile in @('llama31-long','qwen3-balanced','cpu-baseline')) {
            $pattern = [regex]::Escape($profile)
            $sweepContent | Should Match $pattern
        }
    }

    It 'eval-context exposes CpuOnly switch' {
        $evalPath = Join-Path $repoRoot 'scripts/eval-context.ps1'
        $evalContent = Get-Content -Path $evalPath -Raw
        $evalContent | Should Match '\[switch\]\$CpuOnly'
    }
}
