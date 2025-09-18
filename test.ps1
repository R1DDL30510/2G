param([ValidateSet('quick','full')][string]$Mode='quick',[switch]$InstallPythonDeps)
Write-Host 'Mode:' $Mode 'Install:' $InstallPythonDeps
