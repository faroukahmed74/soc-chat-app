# Build Flutter web app for production (creates build/web for port 8082)
# Flutter at E:\flutter - use scripts\add_flutter_to_path.ps1 to add to PATH

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $projectRoot) { $projectRoot = (Get-Location).Path }

$flutterPath = "E:\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterPath)) {
    $flutterPath = $null
}
if (-not $flutterPath) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) { $flutterPath = $flutter.Source }
}
if (-not $flutterPath) {
    Write-Host "Flutter not found. Expected E:\flutter\bin\flutter.bat" -ForegroundColor Yellow
    Write-Host "Run: .\scripts\add_flutter_to_path.ps1" -ForegroundColor Cyan
    Write-Host "Or run manually: E:\flutter\bin\flutter.bat build web --release" -ForegroundColor Cyan
    exit 1
}

Set-Location $projectRoot
Write-Host "Building web app (release)... This may take 5-10 minutes." -ForegroundColor Cyan
& $flutterPath build web --release
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done. build/web is ready. Start web server (port 8082) to serve the app." -ForegroundColor Green
} else {
    Write-Host "Build failed." -ForegroundColor Red
    exit 1
}
