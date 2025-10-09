# MongoDB Setup Script for Windows Server 2022
# This script installs MongoDB Community Edition on Windows Server

# Create directories for MongoDB
Write-Host "Creating MongoDB directories..."
New-Item -ItemType Directory -Force -Path "C:\MongoDB\data\db"
New-Item -ItemType Directory -Force -Path "C:\MongoDB\log"

# Download MongoDB installer
Write-Host "Downloading MongoDB installer..."
$mongoUrl = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-6.0.6-signed.msi"
$installerPath = "C:\MongoDB\mongodb-installer.msi"
Invoke-WebRequest -Uri $mongoUrl -OutFile $installerPath

# Install MongoDB
Write-Host "Installing MongoDB..."
Start-Process msiexec.exe -ArgumentList "/i $installerPath ADDLOCAL=ALL /qn" -Wait

# Create MongoDB configuration file
Write-Host "Creating MongoDB configuration file..."
$configContent = @"
storage:
  dbPath: C:\MongoDB\data\db
systemLog:
  destination: file
  path: C:\MongoDB\log\mongod.log
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: 27017
security:
  authorization: enabled
"@

Set-Content -Path "C:\MongoDB\mongod.cfg" -Value $configContent

# Install MongoDB as a service
Write-Host "Installing MongoDB as a service..."
& "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" --config "C:\MongoDB\mongod.cfg" --install

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

Set-Content -Path "C:\MongoDB\create-admin.js" -Value $createAdminScript

# Wait for MongoDB to start
Start-Sleep -Seconds 5

# Check if mongosh exists, otherwise try mongo (for backward compatibility)
if (Test-Path "C:\Program Files\MongoDB\Server\6.0\bin\mongosh.exe") {
    & "C:\Program Files\MongoDB\Server\6.0\bin\mongosh.exe" --port 27017 --file "C:\MongoDB\create-admin.js"
} elseif (Test-Path "C:\Program Files\MongoDB\Server\6.0\bin\mongo.exe") {
    & "C:\Program Files\MongoDB\Server\6.0\bin\mongo.exe" --port 27017 "C:\MongoDB\create-admin.js"
} else {
    Write-Host "MongoDB shell not found. Please create the admin user manually."
}

Write-Host "MongoDB setup complete!"