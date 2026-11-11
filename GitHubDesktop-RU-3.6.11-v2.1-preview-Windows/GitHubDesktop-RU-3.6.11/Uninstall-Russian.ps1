# Restore English original files, only for exact GitHub Desktop 3.6.11 x64 files.
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifest = Get-Content -LiteralPath (Join-Path $base 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$appDir = Join-Path $env:LOCALAPPDATA 'GitHubDesktop\app-3.6.11\resources\app'
$backupDir = Join-Path $env:LOCALAPPDATA 'GitHubDesktop\RussianPatchBackups\3.6.11'
$names = @('main.js', 'renderer.js')
function HashOf([string]$p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function StopWith([string]$message) { Write-Host "ERROR: $message" -ForegroundColor Red; exit 1 }
if (Get-Process -Name GitHubDesktop -ErrorAction SilentlyContinue) { StopWith 'Close GitHub Desktop using File > Exit first.' }
if (-not (Test-Path -LiteralPath $appDir -PathType Container)) { StopWith 'GitHub Desktop 3.6.11 installation folder not found.' }
$needRestore = $false
foreach ($name in $names) {
  $info = $manifest.files.PSObject.Properties[$name].Value
  $appFile = Join-Path $appDir $name
  $backup = Join-Path $backupDir $name
  if (-not (Test-Path -LiteralPath $appFile -PathType Leaf)) { StopWith "Missing application file: $name" }
  if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { StopWith "Missing English backup: $backup" }
  if ((HashOf $backup) -ne $info.sourceSha256) { StopWith "Corrupted English backup: $name" }
  $hash = HashOf $appFile
  if (@($info.sourceSha256, $info.previousSha256, $info.patchedSha256) -notcontains $hash) { StopWith "Unknown application file: $name. No changes made." }
  if ($hash -ne $info.sourceSha256) { $needRestore = $true }
}
if (-not $needRestore) { Write-Host 'DONE: English files already restored.' -ForegroundColor Green; exit 0 }
try {
  foreach ($name in $names) {
    Copy-Item -LiteralPath (Join-Path $backupDir $name) -Destination (Join-Path $appDir $name) -Force
    if ((HashOf (Join-Path $appDir $name)) -ne $manifest.files.PSObject.Properties[$name].Value.sourceSha256) { throw "Restore verification failed for $name" }
  }
  Write-Host 'DONE: Original English files restored.' -ForegroundColor Green
  Write-Host "Backups retained at $backupDir"
} catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
