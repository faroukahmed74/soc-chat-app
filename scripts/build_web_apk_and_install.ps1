# =============================================================================
# SOC Chat App - Build Web + APK and Install to Android Device
# =============================================================================
# Usage: .\scripts\build_web_apk_and_install.ps1
# Or:    .\scripts\build_web_apk_and_install.ps1 -SkipWeb -SkipAPK  (install only)
# =============================================================================

param(
    [switch]$SkipWeb = $false,
    [switch]$SkipAPK = $false,
    [switch]$SkipInstall = $false,
    [string]$ApiBase = "https://soc-chat-app.ngrok-free.app"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $projectRoot "pubspec.yaml"))) {
    $projectRoot = (Get-Location).Path
}
Set-Location $projectRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Build and Install" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Build Web
if (-not $SkipWeb) {
    Write-Host "[1/3] Building web release..." -ForegroundColor Yellow
    flutter clean | Out-Null
    flutter pub get | Out-Null
    flutter build web --release `
        --dart-define=API_BASE_URL_MOBILE=$ApiBase `
        --dart-define=USE_PHYSICAL_SERVER=true
    if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Host "[OK] Web build complete: build\web" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[1/3] Skipping web build" -ForegroundColor Gray
}

# 2. Build APK
if (-not $SkipAPK) {
    Write-Host "[2/3] Building APK release (Gradle may take 5-10 min)..." -ForegroundColor Yellow
    if (-not $SkipWeb) { flutter pub get | Out-Null }
    flutter build apk --release `
        --dart-define=API_BASE_URL_MOBILE=$ApiBase `
        --dart-define=USE_PHYSICAL_SERVER=true
    if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Host "[OK] APK build complete" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[2/3] Skipping APK build" -ForegroundColor Gray
}

# 3. Install to Android device
if (-not $SkipInstall) {
    Write-Host "[3/3] Installing APK to Android device(s)..." -ForegroundColor Yellow
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        $apkPath = "build\app\outputs\apk\release\app-release.apk"
    }
    if (-not (Test-Path $apkPath)) {
        Write-Host "[ERROR] APK not found. Build APK first." -ForegroundColor Red
        exit 1
    }

    $adbPath = $null
    foreach ($p in @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
    )) {
        if ($p -and (Test-Path $p)) { $adbPath = $p; break }
    }
    if (-not $adbPath) {
        Write-Host "[ERROR] ADB not found. Install Android SDK Platform Tools." -ForegroundColor Red
        Write-Host "APK location: $apkPath" -ForegroundColor Yellow
        exit 1
    }

    $devices = (& $adbPath devices 2>$null) | Where-Object { $_ -match "device$" } | ForEach-Object { ($_ -split "\s+")[0] }
    if ($devices.Count -eq 0) {
        Write-Host "[ERROR] No Android devices connected. Enable USB debugging." -ForegroundColor Red
        Write-Host "APK location: $apkPath" -ForegroundColor Yellow
        exit 1
    }

    foreach ($d in $devices) {
        & $adbPath -s $d install -r $apkPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Installed on $d" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Failed on $d" -ForegroundColor Red
        }
    }
    Write-Host ""
} else {
    Write-Host "[3/3] Skipping install" -ForegroundColor Gray
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Done" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Web:  build\web" -ForegroundColor Cyan
Write-Host "APK:  build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
Write-Host ""
