[CmdletBinding()]
param(
  # По умолчанию кладём репозитории рядом с этим проектом: C:\_azerothcore
  # (скрипт лежит в aimaya-wow-lk\tools\sync)
  [string]$TargetDir = $(
    (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  )
)

$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = '0'

function Invoke-Git([string[]]$Args, [string]$WorkDir = $null) {
  $base = @('-c','http.sslBackend=openssl','-c','http.version=HTTP/1.1','-c','http.maxRequests=1')
  if ($WorkDir) {
    & git @base '-C' $WorkDir @Args
  } else {
    & git @base @Args
  }
  if ($LASTEXITCODE -ne 0) {
    throw ("git failed: " + ($Args -join ' '))
  }
}

$reposPath = Join-Path $PSScriptRoot 'repos.json'
if (-not (Test-Path -LiteralPath $reposPath)) {
  throw "Not found: $reposPath"
}

$repos = Get-Content -Raw -LiteralPath $reposPath | ConvertFrom-Json

Write-Host "TargetDir: $TargetDir"

foreach ($r in $repos) {
  $name = [string]$r.name
  $url = [string]$r.url
  if (-not $name -or -not $url) { throw 'Bad repos.json entry (need name+url)' }

  $path = Join-Path $TargetDir $name

  if (Test-Path -LiteralPath (Join-Path $path '.git')) {
    Write-Host "UPDATE: $name"
    Invoke-Git @('pull','--ff-only') $path
    # submodules (if any)
    Invoke-Git @('submodule','update','--init','--recursive') $path
    continue
  }

  if (Test-Path -LiteralPath $path) {
    Write-Host "SKIP (exists but not git repo): $path" -ForegroundColor Yellow
    continue
  }

  Write-Host "CLONE: $url -> $path"
  Invoke-Git @('clone','--recurse-submodules', $url, $path)
}

Write-Host 'OK'
