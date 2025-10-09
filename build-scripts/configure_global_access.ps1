# Global Access Configuration Script for Windows Server 2022
# This script configures your Windows Server for global access

# Parameters
param (
    [string]$ServerIP = $(Read-Host -Prompt "Enter your server's public IP address"),
    [string]$DomainName = $(Read-Host -Prompt "Enter your domain name (leave blank if none)"),
    [int]$ApiPort = 3000,
    [int]$NotificationPort = 3001
)

Write-Host "Starting global access configuration..." -ForegroundColor Green

# 1. Configure Windows Firewall
Write-Host "Configuring Windows Firewall..." -ForegroundColor Cyan
New-NetFirewallRule -DisplayName "SOC Chat API" -Direction Inbound -Protocol TCP -LocalPort $ApiPort -Action Allow
New-NetFirewallRule -DisplayName "SOC Chat Notifications" -Direction Inbound -Protocol TCP -LocalPort $NotificationPort -Action Allow
Write-Host "Firewall rules created for ports $ApiPort and $NotificationPort" -ForegroundColor Green

# 2. Install and configure IIS URL Rewrite for reverse proxy (optional)
$installIIS = Read-Host "Do you want to install IIS and URL Rewrite for reverse proxy? (y/n)"
if ($installIIS -eq "y") {
    Write-Host "Installing IIS and URL Rewrite..." -ForegroundColor Cyan
    
    # Install IIS
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    
    # Install URL Rewrite Module
    $urlRewriteInstaller = "$env:TEMP\rewrite_amd64.msi"
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi" -OutFile $urlRewriteInstaller
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$urlRewriteInstaller`" /quiet /norestart" -Wait
    
    Write-Host "IIS and URL Rewrite installed successfully" -ForegroundColor Green
}

# 3. Install Let's Encrypt SSL certificate if domain is provided
if ($DomainName) {
    $installSSL = Read-Host "Do you want to install a free SSL certificate using Let's Encrypt? (y/n)"
    if ($installSSL -eq "y") {
        Write-Host "Installing Certify The Web for Let's Encrypt SSL..." -ForegroundColor Cyan
        
        # Download and install Certify The Web
        $certifyInstaller = "$env:TEMP\CertifyTheWebSetup.exe"
        Invoke-WebRequest -Uri "https://certifytheweb.s3.amazonaws.com/downloads/archive/CertifyTheWebSetup.exe" -OutFile $certifyInstaller
        Start-Process -FilePath $certifyInstaller -ArgumentList "/VERYSILENT" -Wait
        
        Write-Host "Certify The Web installed. Please complete the following steps manually:" -ForegroundColor Yellow
        Write-Host "1. Open Certify The Web from the Start Menu" -ForegroundColor Yellow
        Write-Host "2. Click 'New Certificate' and enter your domain name: $DomainName" -ForegroundColor Yellow
        Write-Host "3. Complete the wizard to obtain and install your SSL certificate" -ForegroundColor Yellow
    }
}

# 4. Update API server configuration for global access
$envFilePath = "c:\Users\Administrator\Documents\GitHub\soc-chat-app\servers\local_api_server\.env"
$envContent = @"
PORT=$ApiPort
MONGO_URI=mongodb://localhost:27017/soc_chat_app
JWT_SECRET=your_secure_jwt_secret_key_change_this_in_production
NODE_ENV=production
ALLOWED_ORIGINS=*
"@

Set-Content -Path $envFilePath -Value $envContent
Write-Host "Updated API server configuration for global access" -ForegroundColor Green

# 5. Create a script to update app configuration
$updateAppConfigPath = "c:\Users\Administrator\Documents\GitHub\soc-chat-app\build-scripts\update_app_config.ps1"
$updateAppConfigContent = @"
# Update App Configuration for Global Access
param (
    [string]`$ServerAddress = "$ServerIP"
)

if ("$DomainName") {
    `$ServerAddress = "$DomainName"
}

`$configFilePath = "c:\Users\Administrator\Documents\GitHub\soc-chat-app\lib\config\database_config.dart"
`$configContent = Get-Content -Path `$configFilePath -Raw

# Update server URL
`$configContent = `$configContent -replace 'static const String serverUrl = ".*";', "static const String serverUrl = `"http://`$ServerAddress:$ApiPort`";"

Set-Content -Path `$configFilePath -Value `$configContent
Write-Host "Updated database_config.dart with global server address: `$ServerAddress" -ForegroundColor Green
"@

Set-Content -Path $updateAppConfigPath -Value $updateAppConfigContent
Write-Host "Created script to update app configuration for global access" -ForegroundColor Green

# 6. Instructions for router/network configuration
Write-Host "`nTo complete global access setup, you need to:" -ForegroundColor Magenta
Write-Host "1. Configure your router to forward ports $ApiPort and $NotificationPort to this server ($ServerIP)" -ForegroundColor Magenta
Write-Host "2. If using a domain name, update your DNS settings to point to your public IP address" -ForegroundColor Magenta
Write-Host "3. Run the update_app_config.ps1 script to update your app configuration" -ForegroundColor Magenta

Write-Host "`nGlobal access configuration completed!" -ForegroundColor Green