# Check Firebase config from google-services.json and open Firebase Console
# Run from project root or scripts folder

$projectRoot = if (Test-Path "android\app\google-services.json") { (Get-Location).Path } 
               elseif (Test-Path "..\android\app\google-services.json") { (Split-Path (Get-Location).Path -Parent) }
               else { Split-Path $PSScriptRoot -Parent }

$jsonPath = Join-Path $projectRoot "android\app\google-services.json"
if (-not (Test-Path $jsonPath)) {
    Write-Host "google-services.json not found at android\app\google-services.json" -ForegroundColor Yellow
    exit 1
}

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json
$projectId = $json.project_info.project_id
$projectNumber = $json.project_info.project_number
$consoleUrl = "https://console.firebase.google.com/project/$projectId"

Write-Host "Firebase (from google-services.json):" -ForegroundColor Cyan
Write-Host "  project_id:   $projectId" -ForegroundColor White
Write-Host "  project_no:   $projectNumber" -ForegroundColor White
Write-Host "  Console URL:  $consoleUrl" -ForegroundColor White
Write-Host ""

# Optional: open in browser (skip if -Open not passed)
param([switch]$Open)
if ($Open) {
    Start-Process $consoleUrl
    Write-Host "Opened Firebase Console in browser." -ForegroundColor Green
}

# Firebase CLI (if installed)
$firebase = Get-Command firebase -ErrorAction SilentlyContinue
if ($firebase) {
    Write-Host "Firebase CLI: found. Run 'firebase login' then 'firebase projects:list' to verify." -ForegroundColor Green
} else {
    Write-Host "Firebase CLI not installed. Install: npm install -g firebase-tools" -ForegroundColor Gray
}
