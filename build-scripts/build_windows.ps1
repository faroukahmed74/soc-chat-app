# SOC Chat App - Windows Build Script (PowerShell)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Windows Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host $flutterVersion -ForegroundColor Green
} catch {
    Write-Host "ERROR: Flutter not found in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to PATH" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Checking Windows desktop support..." -ForegroundColor Yellow
flutter config --enable-windows-desktop

Write-Host ""
Write-Host "Running flutter doctor..." -ForegroundColor Yellow
flutter doctor

Write-Host ""
Write-Host "Building Windows executable..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
Write-Host ""

$buildResult = flutter build windows --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL! 🎉" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Windows executable is located at:" -ForegroundColor Green
    Write-Host "build\windows\runner\Release\soc_chat_app.exe" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can now distribute this .exe file!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  BUILD FAILED! ❌" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above" -ForegroundColor Red
    Write-Host "and ensure all Windows requirements are met" -ForegroundColor Red
    Write-Host ""
}

Read-Host "Press Enter to exit"

