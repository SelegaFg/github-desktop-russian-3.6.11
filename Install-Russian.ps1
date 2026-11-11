# Unofficial Russian localization: GitHub Desktop 3.6.11 x64.
# Patch only byte-verified original application files. Windows PowerShell 5.1 compatible.
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifest = Get-Content -LiteralPath (Join-Path $base 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$appDir = Join-Path $env:LOCALAPPDATA 'GitHubDesktop\app-3.6.11\resources\app'
$backupDir = Join-Path $env:LOCALAPPDATA 'GitHubDesktop\RussianPatchBackups\3.6.11'
$stagingDir = Join-Path $backupDir '_before_public_install'
$names = @('main.js', 'renderer.js')
function HashOf([string]$p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function HashBytes([byte[]]$bytes) {
  $hash = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
  finally { $hash.Dispose() }
}
function StopWith([string]$reason) { Write-Host "ERROR: $reason" -ForegroundColor Red; exit 1 }
function Apply-BytePatch([byte[]]$original, $delta) {
  if ($delta.format -ne 'gdr-byte-delta-v1') { throw 'Unsupported delta format' }
  $result = New-Object System.IO.MemoryStream
  try {
    $position = 0
    foreach ($entry in $delta.replacements) {
      $offset = [int]$entry[0]
      $before = [Convert]::FromBase64String([string]$entry[1])
      $after = [Convert]::FromBase64String([string]$entry[2])
      if ($offset -lt $position -or $offset -gt $original.Length -or $offset + $before.Length -gt $original.Length) { throw 'Invalid or overlapping patch offsets' }
      for ($i = 0; $i -lt $before.Length; $i++) {
        if ($original[$offset + $i] -ne $before[$i]) { throw "Original bytes differ at offset $offset" }
      }
      $result.Write($original, $position, $offset - $position)
      $result.Write($after, 0, $after.Length)
      $position = $offset + $before.Length
    }
    $result.Write($original, $position, $original.Length - $position)
    return ,$result.ToArray()
  } finally { $result.Dispose() }
}

if (-not (Test-Path -LiteralPath $appDir -PathType Container)) { StopWith "GitHub Desktop 3.6.11 not found at $appDir" }
if (Get-Process -Name GitHubDesktop -ErrorAction SilentlyContinue) { StopWith 'Close GitHub Desktop using File > Exit, then try again.' }
$installedHash = @{}
$prepared = @{}
$allNew = $true
try {
  # Validate both installed files and both patch payloads BEFORE making any changes.
  foreach ($name in $names) {
    $info = $manifest.files.PSObject.Properties[$name].Value
    $installed = Join-Path $appDir $name
    $deltaPath = Join-Path (Join-Path $base 'patches') ($name + '.json')
    if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) { throw "Missing installed file: $name" }
    if (-not (Test-Path -LiteralPath $deltaPath -PathType Leaf)) { throw "Missing delta: $name" }
    if ((HashOf $deltaPath) -ne $info.deltaSha256) { throw "Delta SHA256 mismatch: $name. Extract an untampered ZIP." }
    $current = HashOf $installed
    if (@($info.sourceSha256, $info.previousSha256, $info.patchedSha256) -notcontains $current) { throw "Installed $name is not a supported original/v1/v2 file; nothing will be changed." }
    $installedHash[$name] = $current
    if ($current -ne $info.patchedSha256) { $allNew = $false }
    $originalBackup = Join-Path $backupDir $name
    if (Test-Path -LiteralPath $originalBackup -PathType Leaf) {
      if ((HashOf $originalBackup) -ne $info.sourceSha256) { throw "Existing original backup failed SHA256 verification: $name" }
      $original = [System.IO.File]::ReadAllBytes($originalBackup)
    } elseif ($current -eq $info.sourceSha256) {
      $original = [System.IO.File]::ReadAllBytes($installed)
    } else { throw "Cannot upgrade $name: original backup missing. Restore official 3.6.11 first." }
    if ((HashBytes $original) -ne $info.sourceSha256) { throw "Original SHA256 mismatch: $name" }
    $delta = Get-Content -LiteralPath $deltaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($delta.file -ne $name) { throw "Delta file field mismatch for $name" }
    $patched = Apply-BytePatch $original $delta
    if ((HashBytes $patched) -ne $info.patchedSha256) { throw "Patched SHA256 mismatch: $name" }
    $prepared[$name] = @{ original = $original; patched = $patched }
  }
  if ($allNew) { Write-Host 'DONE: This Russian translation is already installed.' -ForegroundColor Green; exit 0 }

  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  foreach ($name in $names) {
    $dest = Join-Path $backupDir $name
    if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
      [System.IO.File]::WriteAllBytes($dest, [byte[]]$prepared[$name].original)
      if ((HashOf $dest) -ne $manifest.files.PSObject.Properties[$name].Value.sourceSha256) { throw "Backup verification failed: $name" }
    }
  }

  New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
  foreach ($name in $names) {
    $stage = Join-Path $stagingDir $name
    Copy-Item -LiteralPath (Join-Path $appDir $name) -Destination $stage -Force
    if ((HashOf $stage) -ne $installedHash[$name]) { throw "Pre-install copy verification failed: $name" }
  }

  try {
    foreach ($name in $names) {
      $target = Join-Path $appDir $name
      [System.IO.File]::WriteAllBytes($target, [byte[]]$prepared[$name].patched)
      if ((HashOf $target) -ne $manifest.files.PSObject.Properties[$name].Value.patchedSha256) { throw "Post-install SHA256 mismatch: $name" }
    }
  } catch {
    Write-Host 'Installation failed: attempting rollback...' -ForegroundColor Yellow
    foreach ($name in $names) {
      $stage = Join-Path $stagingDir $name
      if ((Test-Path -LiteralPath $stage -PathType Leaf) -and (HashOf $stage) -eq $installedHash[$name]) {
        try { Copy-Item -LiteralPath $stage -Destination (Join-Path $appDir $name) -Force }
        catch { Write-Host "Manual restore may be required for $name ($stage)" -ForegroundColor Red }
      }
    }
    throw
  }
  Write-Host 'DONE: Russian localization 2.1 preview installed successfully.' -ForegroundColor Green
  Write-Host "Original backups: $backupDir"
  Write-Host 'NOTE: Some UI elements are still English. Test version.' -ForegroundColor Yellow
} catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
