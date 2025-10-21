$ErrorActionPreference = 'Stop'

# Detect JDK 11 installed by install_jdk11.ps1
$jdkBase = 'C:\\tools\\jdk11'
if (-not (Test-Path $jdkBase)) { throw "JDK base path not found at $jdkBase. Run scripts/install_jdk11.ps1 first." }
$jdkDir = Get-ChildItem -Directory $jdkBase | Where-Object { $_.Name -like 'jdk-*' -or $_.Name -like 'jdk-11*' -or $_.Name -like 'microsoft*' } | Select-Object -First 1
if (-not $jdkDir) { throw 'JDK directory not found under tools path' }

$env:JAVA_HOME = $jdkDir.FullName
Write-Host "Using JAVA_HOME=$($env:JAVA_HOME)"
& "$env:JAVA_HOME\\bin\\java.exe" -version

# Flutter build with reserved ngrok URL
$apiBase = 'https://soc-chat-app.ngrok-free.app'
$usePhysical = 'true'

Write-Host 'Running flutter clean'
flutter clean
Write-Host 'Running flutter pub get'
flutter pub get

Write-Host 'Building release APK'
flutter build apk --release --verbose --dart-define=API_BASE_URL_MOBILE=$apiBase --dart-define=USE_PHYSICAL_SERVER=$usePhysical | Tee-Object -FilePath build_release_log.txt

$projectRoot = (Resolve-Path '.').Path
$apkCandidates = @(
  (Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'),
  (Join-Path $projectRoot 'build/app/outputs/apk/release/app-release.apk'),
  (Join-Path $projectRoot 'android/app/build/outputs/apk/release/app-release.apk')
)

$apkPath = $null
foreach ($p in $apkCandidates) {
  if (Test-Path $p) { $apkPath = $p; break }
}

if ($apkPath) {
  $sizeMB = [Math]::Round((Get-Item $apkPath).Length / 1MB, 2)
  Write-Host "APK built: $apkPath ($sizeMB MB)"
} else {
  throw "Release APK not found in known locations. See build_release_log.txt for details."
}