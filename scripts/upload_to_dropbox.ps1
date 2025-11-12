# =============================================================================
# SOC Chat App - Upload to Dropbox Script
# =============================================================================
# This script helps upload version_info.json and APK to Dropbox
# Usage: .\scripts\upload_to_dropbox.ps1

param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-release.apk",
    [string]$JsonPath = "version_info.json",
    [switch]$OpenDropbox = $false
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n=============================================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "=============================================================================`n" -ForegroundColor Cyan
}

Write-Header "SOC Chat App - Dropbox Upload Helper"

# Check if files exist
$filesToUpload = @()

if (Test-Path $JsonPath) {
    Write-Info "✓ Found version_info.json"
    $filesToUpload += @{
        Path = $JsonPath
        Name = "version_info.json"
        Type = "JSON"
    }
} else {
    Write-Error "✗ version_info.json not found at: $JsonPath"
    exit 1
}

if (Test-Path $ApkPath) {
    $apkInfo = Get-Item $ApkPath
    $apkSizeMB = [math]::Round($apkInfo.Length / 1MB, 2)
    Write-Info "✓ Found APK: $($apkInfo.Name) ($apkSizeMB MB)"
    $filesToUpload += @{
        Path = $ApkPath
        Name = $apkInfo.Name
        Type = "APK"
    }
} else {
    Write-Warning "✗ APK not found at: $ApkPath"
    Write-Warning "  Please build the APK first: flutter build apk --release"
    $filesToUpload = $filesToUpload | Where-Object { $_.Type -eq "JSON" }
}

if ($filesToUpload.Count -eq 0) {
    Write-Error "No files to upload!"
    exit 1
}

Write-Header "Upload Instructions"

Write-Host "To upload files to Dropbox, follow these steps:`n" -ForegroundColor White

Write-Host "1. Open Dropbox in your browser:" -ForegroundColor Yellow
Write-Host "   https://www.dropbox.com/home`n" -ForegroundColor Cyan

Write-Host "2. Navigate to your app folder (or create one)" -ForegroundColor Yellow
Write-Host "   Recommended folder: Apps/SOC-Chat-App`n" -ForegroundColor Cyan

Write-Host "3. Upload the following files:" -ForegroundColor Yellow
foreach ($file in $filesToUpload) {
    Write-Host "   - $($file.Name)" -ForegroundColor White
    Write-Host "     Location: $($file.Path)" -ForegroundColor Gray
}
Write-Host ""

Write-Host "4. After uploading, get the sharing links:" -ForegroundColor Yellow
Write-Host "   a. Right-click each file in Dropbox" -ForegroundColor White
Write-Host "   b. Select 'Copy link' or 'Share'" -ForegroundColor White
Write-Host "   c. Make sure the link uses 'dl.dropboxusercontent.com'" -ForegroundColor White
Write-Host "   d. Add '?dl=1' at the end for direct download`n" -ForegroundColor White

Write-Host "5. Update the URLs in your code:" -ForegroundColor Yellow
Write-Host "   File: lib\config\version_config.dart" -ForegroundColor Cyan
Write-Host "   - Update dropboxJsonUrl with the JSON file link" -ForegroundColor White
Write-Host "   - Update dropboxApkUrl with the APK file link`n" -ForegroundColor White

Write-Host "   File: version_info.json" -ForegroundColor Cyan
Write-Host "   - Update download_url with the APK file link`n" -ForegroundColor White

Write-Header "Current Configuration"

Write-Host "Current version_info.json URLs:" -ForegroundColor Yellow
$jsonContent = Get-Content $JsonPath -Raw | ConvertFrom-Json
Write-Host "  Version: $($jsonContent.version)" -ForegroundColor White
Write-Host "  Build: $($jsonContent.build_number)" -ForegroundColor White
Write-Host "  Download URL: $($jsonContent.download_url)" -ForegroundColor White
Write-Host ""

# Check if Dropbox CLI is available
$dropboxCli = Get-Command dropbox -ErrorAction SilentlyContinue
if ($dropboxCli) {
    Write-Info "Dropbox CLI detected!"
    Write-Host "`nWould you like to open Dropbox folder? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Info "Opening Dropbox folder..."
        Start-Process "explorer.exe" -ArgumentList "$env:USERPROFILE\Dropbox"
    }
} else {
    if ($OpenDropbox) {
        Write-Info "Opening Dropbox in browser..."
        Start-Process "https://www.dropbox.com/home"
    }
}

Write-Header "Quick Copy Commands"

Write-Host "To quickly open the files in File Explorer:" -ForegroundColor Yellow
Write-Host "  explorer.exe /select,$(Resolve-Path $JsonPath)" -ForegroundColor Cyan
if (Test-Path $ApkPath) {
    Write-Host "  explorer.exe /select,$(Resolve-Path $ApkPath)" -ForegroundColor Cyan
}

Write-Host "`n" -NoNewline
Write-Info "Script completed! Follow the instructions above to upload to Dropbox."

