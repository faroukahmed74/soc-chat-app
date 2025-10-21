$projectRoot = (Resolve-Path '.').Path
$paths = @(
  (Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'),
  (Join-Path $projectRoot 'build/app/outputs/apk/release/app-release.apk'),
  (Join-Path $projectRoot 'android/app/build/outputs/apk/release/app-release.apk')
)

$found = $false
foreach ($p in $paths) {
  if (Test-Path $p) {
    $item = Get-Item $p
    $sizeMB = [Math]::Round($item.Length / 1MB, 2)
    Write-Host "FOUND $($item.FullName) SIZE ${sizeMB}MB"
    $found = $true
  }
}

if (-not $found) {
  Write-Host "NOT_FOUND in default locations"
  $paths | ForEach-Object { Write-Host "Checked: $_" }
}