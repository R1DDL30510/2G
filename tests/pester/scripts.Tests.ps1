if (-not ) {
    throw 'PSScriptRoot was not populated; unable to determine repository root.'
}

function Get-RepoRoot {
    param([string])

     = [System.IO.Path]::GetDirectoryName()
    if (-not ) {
        throw "Unable to locate tests directory from ''."
    }

     = [System.IO.Path]::GetDirectoryName()
    if (-not ) {
        throw "Unable to resolve repository root from ''."
    }

    return 
}

Describe 'scripts/compose.ps1' {
    BeforeAll {
         = Get-RepoRoot -StartPath 
         = Join-Path (Join-Path  'scripts') 'compose.ps1'
         = Get-Content -Path  -Raw
    }

    It 'declares expected actions' {
        ( -match "ValidateSet\('up','down','restart','logs'\)") | Should -BeTrue
    }
}

Describe 'scripts/bootstrap.ps1' {
    BeforeAll {
         = Get-RepoRoot -StartPath 
         = Join-Path (Join-Path  'scripts') 'bootstrap.ps1'
         = Get-Content -Path  -Raw
    }

    It 'supports PromptSecrets switch' {
        ( -match '\[switch\]\') | Should -BeTrue
    }

    It 'initialises context sweep profile entry' {
         = '(?s)function\s+Invoke-WorkspaceProvisioning.*?Ensure-EnvEntry\s+-Path\s+\\s+-Key\s+''CONTEXT_SWEEP_PROFILE'''
        ( -match ) | Should -BeTrue
    }
}

Describe 'context evaluation tooling' {
    BeforeAll {
         = Get-RepoRoot -StartPath 
         = Join-Path (Join-Path  'scripts') 'context-sweep.ps1'
         = Get-Content -Path  -Raw
         = Join-Path (Join-Path  'scripts') 'eval-context.ps1'
         = Get-Content -Path  -Raw
    }

    It 'context sweep exposes built-in profiles' {
        foreach (C:\Users\MvP\OneDrive\Dokumente\PowerShell\Microsoft.PowerShell_profile.ps1 in @('llama31-long','qwen3-balanced','cpu-baseline')) {
             = [regex]::Escape(C:\Users\MvP\OneDrive\Dokumente\PowerShell\Microsoft.PowerShell_profile.ps1)
            ( -match ) | Should -BeTrue
        }
    }

    It 'eval-context exposes CpuOnly switch' {
        ( -match '\[switch\]\') | Should -BeTrue
    }
}
