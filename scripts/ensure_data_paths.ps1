# =============================================================================
# SOC Chat App - Ensure D:\soc-chat-data structure exists
# =============================================================================
# Creates MongoDB data/log and uploads directories under D:\soc-chat-data
# so the app and MongoDB use the correct DB path.
# =============================================================================

$ErrorActionPreference = "Stop"
$base = "D:\soc-chat-data"

$paths = @(
    (Join-Path $base "MongoDB\data\db"),
    (Join-Path $base "MongoDB\log"),
    (Join-Path $base "uploads")
)

Write-Host "Ensuring SOC Chat data paths under D:\soc-chat-data..." -ForegroundColor Cyan
foreach ($p in $paths) {
    if (!(Test-Path $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
        Write-Host "  Created: $p" -ForegroundColor Green
    } else {
        Write-Host "  Exists:  $p" -ForegroundColor Gray
    }
}
Write-Host "Done. MongoDB dbPath: D:\soc-chat-data\MongoDB\data\db" -ForegroundColor Cyan
