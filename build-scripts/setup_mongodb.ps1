# MongoDB Setup Script for Windows Server 2022
# This script installs MongoDB Community Edition on Windows Server

# Create directories for MongoDB (SOC Chat App uses D:\soc-chat-data)
Write-Host "Creating MongoDB directories at D:\soc-chat-data..."
$dbRoot = "D:\soc-chat-data"
New-Item -ItemType Directory -Force -Path "$dbRoot\MongoDB\data\db" | Out-Null
New-Item -ItemType Directory -Force -Path "$dbRoot\MongoDB\log" | Out-Null

# Download MongoDB installer
Write-Host "Downloading MongoDB installer..."
$mongoUrl = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-6.0.6-signed.msi"
$installerPath = "C:\MongoDB\mongodb-installer.msi"
Invoke-WebRequest -Uri $mongoUrl -OutFile $installerPath

# Install MongoDB
Write-Host "Installing MongoDB..."
Start-Process msiexec.exe -ArgumentList "/i $installerPath ADDLOCAL=ALL /qn" -Wait

# Create MongoDB configuration file (uses D:\soc-chat-data for SOC Chat App)
Write-Host "Creating MongoDB configuration file..."
$dbRoot = "D:\soc-chat-data"
$configDir = "C:\MongoDB"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Force -Path $configDir | Out-Null }
$configContent = @"
storage:
  dbPath: $dbRoot\MongoDB\data\db
systemLog:
  destination: file
  path: $dbRoot\MongoDB\log\mongod.log
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: 27017
security:
  authorization: enabled
"@

Set-Content -Path "$configDir\mongod.cfg" -Value $configContent

# Install MongoDB as a service
Write-Host "Installing MongoDB as a service (config: $configDir\mongod.cfg)..."
& "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" --config "$configDir\mongod.cfg" --install

# Start MongoDB service
Write-Host "Starting MongoDB service..."
Start-Service MongoDB

# Create admin user
Write-Host "Creating admin user..."
$createAdminScript = @"
use admin
db.createUser(
  {
    user: 'admin',
    pwd: 'SecurePassword123!',
    roles: [ { role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase' ]
  }
)
"@

Set-Content -Path "$configDir\create-admin.js" -Value $createAdminScript

# Wait for MongoDB to start
Start-Sleep -Seconds 5

# Check if mongosh exists, otherwise try mongo (for backward compatibility)
if (Test-Path "C:\Program Files\MongoDB\Server\6.0\bin\mongosh.exe") {
    & "C:\Program Files\MongoDB\Server\6.0\bin\mongosh.exe" --port 27017 --file "$configDir\create-admin.js"
} elseif (Test-Path "C:\Program Files\MongoDB\Server\6.0\bin\mongo.exe") {
    & "C:\Program Files\MongoDB\Server\6.0\bin\mongo.exe" --port 27017 "$configDir\create-admin.js"
} else {
    Write-Host "MongoDB shell not found. Please create the admin user manually."
}

Write-Host "MongoDB setup complete! DB path: $dbRoot\MongoDB\data\db"