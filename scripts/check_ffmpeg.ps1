# Check if FFmpeg is installed (needed for video transcoding and thumbnails)
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpeg) {
    Write-Host "FFmpeg: OK" -ForegroundColor Green
    & ffmpeg -version 2>&1 | Select-Object -First 1
} else {
    Write-Host "FFmpeg: NOT FOUND" -ForegroundColor Yellow
    Write-Host "Install: winget install ffmpeg" -ForegroundColor Cyan
    Write-Host "Or: choco install ffmpeg" -ForegroundColor Cyan
    Write-Host "Or download from: https://ffmpeg.org/download.html" -ForegroundColor Cyan
    exit 1
}
