# VocabLock Japanese initialization (manual run).
# Resets learning data, writes a Japanese baseline config, then starts the app.
# Old data/config is backed up next to the release directory first.
#
#   .\scripts\init-ja.ps1                 # backup + reset + start
#   .\scripts\init-ja.ps1 -KeepData       # keep the DB, just re-apply config
#   .\scripts\init-ja.ps1 -Shutdown       # ... and power off 60s after starting
#   .\scripts\init-ja.ps1 -DailyTarget 20 -SessionBudget 30
param(
  [switch]$KeepData,
  [switch]$Shutdown,
  [int]$DailyTarget = 20,
  [int]$SessionBudget = 0
)

$ErrorActionPreference = 'Stop'
$release = (Resolve-Path (Join-Path $PSScriptRoot '..\release\VocabLock-ja-electron')).Path
$exe = Join-Path $release 'vocablock.exe'
if (-not (Test-Path $exe)) { throw "release not found: $exe" }

Write-Host "== VocabLock init (ja) =="
Write-Host "release: $release"

Get-Process -Name vocablock,vocablock-desktop -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path (Split-Path $release) "backup-init-$stamp"
New-Item -ItemType Directory -Path $backup | Out-Null
if (Test-Path (Join-Path $release 'configs')) { Copy-Item (Join-Path $release 'configs') (Join-Path $backup 'configs') -Recurse }
if (Test-Path (Join-Path $release 'data')) { Copy-Item (Join-Path $release 'data') (Join-Path $backup 'data') -Recurse }
Write-Host "backup:  $backup"

if (-not $KeepData) {
  Get-ChildItem (Join-Path $release 'data') -Filter 'vocablock.db*' -ErrorAction SilentlyContinue | Remove-Item -Force
  Get-ChildItem (Join-Path $release 'data\audio') -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
  Write-Host "data:    reset (fresh database)"
} else {
  Write-Host "data:    kept"
}

foreach ($asset in @('content', 'bin', 'models', 'configs\asr.yaml')) {
  if (-not (Test-Path (Join-Path $release $asset))) { throw "missing release asset: $asset" }
}

function Set-TopLevelKey([string]$text, [string]$key, [string]$value) {
  $line = "$key: $value"
  if ($text -match "(?m)^$key\s*:.*$") {
    return [regex]::Replace($text, "(?m)^$key\s*:.*$", [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $line })
  }
  return $text.TrimEnd() + [Environment]::NewLine + $line + [Environment]::NewLine
}

$appPath = Join-Path $release 'configs\app.yaml'
$app = Get-Content $appPath -Raw
$app = Set-TopLevelKey $app 'active_lang' 'ja'
$app = Set-TopLevelKey $app 'interface_lang' 'zh-CN'
$app = Set-TopLevelKey $app 'language_locked' 'true'
$app = Set-TopLevelKey $app 'daily_target' $DailyTarget
$app = Set-TopLevelKey $app 'session_time_budget' $SessionBudget
$app = Set-TopLevelKey $app 'content_dir' 'content'
$app = Set-TopLevelKey $app 'auto_expand_words' 'true'
$app = Set-TopLevelKey $app 'auto_start' 'true'
[IO.File]::WriteAllText($appPath, $app, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "config:  ja / zh-CN / target=$DailyTarget / budget=$SessionBudget"

$secrets = Join-Path $release 'configs\secrets.yaml'
if (-not (Test-Path $secrets)) { Write-Warning 'configs\secrets.yaml is missing: AI features will be disabled' }

Write-Host "start:   $exe"
$log = Join-Path $release "data\init-$stamp.log"
$errLog = "$log.err"
Start-Process -FilePath $exe -WorkingDirectory $release -RedirectStandardOutput $log -RedirectStandardError $errLog
Write-Host "log:     $log"

# First-run bootstrap (AI plan + initial words) runs asynchronously. Wait for
# its "bootstrap: done" line before powering off, otherwise the expansion is
# cut in half.
if ($Shutdown) {
  $deadline = (Get-Date).AddMinutes(10)
  $done = $false
  while ((Get-Date) -lt $deadline) {
    if ((Test-Path $log) -and (Select-String -Path $log -Pattern 'bootstrap: done' -Quiet)) { $done = $true; break }
    Start-Sleep -Seconds 5
  }
  if ($done) { Write-Host 'bootstrap: done' } else { Write-Warning 'bootstrap did not finish within 10 minutes; check the log before relying on this install' }
  Write-Host 'shutdown: 60s'
  shutdown.exe /s /t 60 /c 'VocabLock init complete'
}