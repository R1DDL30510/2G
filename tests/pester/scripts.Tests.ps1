function Get-RepoRoot {
    param(
        [string]$ScriptRoot
    )

    if (-not $ScriptRoot) {
        throw 'PSScriptRoot was not populated; unable to determine repository root.'
    }

    $testsDirectory = [System.IO.Directory]::GetParent($ScriptRoot)
    if ($null -eq $testsDirectory) {
        throw "Unable to locate tests directory from '$ScriptRoot'."
    }

    $repositoryDirectory = [System.IO.Directory]::GetParent($testsDirectory.FullName)
    if ($null -eq $repositoryDirectory) {
        throw "Unable to resolve repository root from '$($testsDirectory.FullName)'."
    }

    return $repositoryDirectory.FullName
}

Describe 'scripts/compose.ps1' {
    BeforeAll {
        $repoRoot = Get-RepoRoot -ScriptRoot $PSScriptRoot
        $script:composePath = [System.IO.Path]::Combine($repoRoot, 'scripts', 'compose.ps1')
        $script:composeContent = [System.IO.File]::ReadAllText($script:composePath)
    }

    It 'declares expected actions' {
        ($script:composeContent -match "ValidateSet\('up','down','restart','logs'\)") | Should -BeTrue
    }
}

Describe 'scripts/bootstrap.ps1' {
    BeforeAll {
        $repoRoot = Get-RepoRoot -ScriptRoot $PSScriptRoot
        $script:bootstrapPath = [System.IO.Path]::Combine($repoRoot, 'scripts', 'bootstrap.ps1')
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
        $repoRoot = Get-RepoRoot -ScriptRoot $PSScriptRoot
        $script:sweepPath = [System.IO.Path]::Combine($repoRoot, 'scripts', 'context-sweep.ps1')
        $script:sweepContent = [System.IO.File]::ReadAllText($script:sweepPath)
        $script:evalPath = [System.IO.Path]::Combine($repoRoot, 'scripts', 'eval-context.ps1')
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
