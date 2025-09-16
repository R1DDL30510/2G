param(
  [ValidateSet('pull','list','run','show','create','create-all')]
  [string]$Action = 'list',
  [string]$Model,
  [string]$Prompt
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$composeFile = Join-Path $repoRoot 'infra\compose\docker-compose.yml'

function GetOllamaId() {
  $id = docker compose -f $composeFile ps -q ollama
  if (-not $id) { throw 'Ollama container not found. Is the stack up?' }
  return $id
}

switch ($Action) {
  'list' {
    $id = GetOllamaId
    docker exec -i $id ollama list
  }
  'pull' {
    if (-not $Model) { throw 'Specify -Model (e.g., llama3.1:8b)' }
    $id = GetOllamaId
    docker exec -i $id ollama pull $Model
  }
  'create' {
    if (-not $Model) { throw 'Specify -Model name to create (e.g., llama31-8b-gpu)' }
    $id = GetOllamaId
    $file = "/modelfiles/$Model.Modelfile"
    docker exec -i $id sh -lc "test -f $file" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Modelfile not found in container: $file" }
    docker exec -i $id ollama create $Model -f $file
  }
  'create-all' {
    $id = GetOllamaId
    $targets = @('llama31-8b-c4k','llama31-8b-c8k','llama31-8b-c16k','llama31-8b-c32k')
    foreach($t in $targets){
      $file = "/modelfiles/$t.Modelfile"
      docker exec -i $id sh -lc "test -f $file && ollama create $t -f $file || echo 'skip: missing ' $file"
    }
  }
  'run' {
    if (-not $Model) { throw 'Specify -Model' }
    $id = GetOllamaId
    if ($Prompt) {
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($Prompt)
      $stream = New-Object System.IO.MemoryStream(,$bytes)
      $reader = New-Object System.IO.StreamReader($stream)
      $content = $reader.ReadToEnd()
      echo $content | docker exec -i $id ollama run $Model
    } else {
      docker exec -it $id ollama run $Model
    }
  }
  'show' {
    if (-not $Model) { throw 'Specify -Model' }
    $id = GetOllamaId
    docker exec -i $id ollama show $Model
  }
}
