# SOC Chat App - Start MongoDB via Docker (workaround if local MongoDB 8.2 crashes with 0xC000001D)
# Uses D:\soc-chat-data\MongoDB\data\db as the data volume; listens on localhost:27017.

$ErrorActionPreference = "Stop"
$dbPath = "D:\soc-chat-data\MongoDB\data\db"
$containerName = "soc-chat-mongodb"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker not found. Install Docker Desktop or use MongoDB 6.0 locally (see MANUAL_STEPS_FOR_FULL_FUNCTIONALITY.md)."
    exit 1
}

$dockerOk = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Docker daemon not running. Start Docker Desktop, then run this script again. Or install MongoDB 6.0 and use scripts\run\start_mongodb.bat"
    exit 1
}

$existing = docker ps -a --filter "name=$containerName" --format "{{.Names}}" 2>$null
if ($existing -eq $containerName) {
    $running = docker ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
    if ($running -eq $containerName) {
        Write-Host "MongoDB container already running on port 27017."
        exit 0
    }
    docker start $containerName
    Write-Host "Started existing MongoDB container. Port 27017."
    exit 0
}

if (-not (Test-Path $dbPath)) {
    New-Item -ItemType Directory -Path $dbPath -Force | Out-Null
}

docker run -d --name $containerName -p 27017:27017 -v "${dbPath}:C:\data\db" mongo:6.0 2>$null
if ($LASTEXITCODE -ne 0) {
    # Windows path format for Docker Desktop
    docker run -d --name $containerName -p 27017:27017 -v "${dbPath}:/data/db" mongo:6.0
}
Write-Host "MongoDB (Docker) started. Port 27017, data: $dbPath"
