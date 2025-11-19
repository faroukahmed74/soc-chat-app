# SOC Chat App - Auto-Start Services Guide

## 📋 Overview

This guide explains how services are automatically started at system startup, even when the user is not logged in.

## 🚀 Services Startup Order

Services start automatically in this order:

1. **Web Server** (`servers/server.js`)
   - Port: 8082
   - Environment: `PORT=8082`, `API_TARGET=http://localhost:3003`

2. **API Server** (`servers/local_api_server/server.js`)
   - Port: 3003
   - Environment: `PORT=3003`, `HOST=0.0.0.0`

3. **Additional Services** (from `services_manager_interactive.bat` option 1)
   - MongoDB service
   - ngrok tunnel
   - Network URLs service

## ⚙️ Configuration

### Auto-Start Task

- **Task Name**: `SOC_Chat_App_Startup_Services`
- **Trigger**: At system startup
- **Delay**: 2 minutes (to ensure system is ready)
- **Logon Type**: S4U (runs even when user not logged in)
- **Run Level**: Highest

### Startup Script

- **Script**: `scripts/startup_all_services.ps1`
- **Log File**: `logs/startup.log`
- **Process IDs**: `logs/startup_pids.json`

## 📝 What Happens After Restart

### Timeline

1. **0:00** - PC boots up
2. **0:02** - Auto-start task triggers (2 minute delay)
3. **0:02** - Web Server starts (Port 8082)
4. **0:05** - API Server starts (Port 3003)
5. **0:05** - MongoDB, ngrok, Network URLs start

### Example

**PC restarts at 10:00 AM:**
- **10:02 AM**: Web Server starts
- **10:05 AM**: API Server starts
- **10:05 AM**: MongoDB, ngrok, Network URLs start
- **10:05 AM**: All services ready

## 🔍 Verification

### Check if Services Are Running

```powershell
# Check scheduled task
Get-ScheduledTask -TaskName "SOC_Chat_App_Startup_Services"

# Check if services are listening
netstat -an | findstr ":8082"  # Web Server
netstat -an | findstr ":3003"  # API Server
netstat -an | findstr ":4040"  # ngrok

# Check MongoDB service
net start | findstr -i mongo

# View startup log
Get-Content "logs\startup.log" -Tail 50

# View process IDs
Get-Content "logs\startup_pids.json" | ConvertFrom-Json
```

### Check Process Status

```powershell
# View all Node.js processes
Get-Process -Name "node" -ErrorAction SilentlyContinue

# View ngrok process
Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
```

## 🛠️ Management

### Enable Auto-Start

```powershell
.\scripts\setup_startup_services.ps1
```

### Disable Auto-Start

```powershell
.\scripts\setup_startup_services.ps1 -Remove
```

### Manual Start (Test)

```powershell
.\scripts\startup_all_services.ps1
```

## 📊 Logs

### Startup Log

Location: `logs\startup.log`

Contains:
- Timestamp of each step
- Success/failure status
- Process IDs
- Error messages (if any)

### Process IDs

Location: `logs\startup_pids.json`

Contains:
- Timestamp
- Web Server PID
- API Server PID
- ngrok PID
- Network URLs PID

## ⚠️ Troubleshooting

### Services Don't Start After Restart

1. **Check Task Scheduler**:
   ```powershell
   Get-ScheduledTask -TaskName "SOC_Chat_App_Startup_Services"
   ```

2. **Check Logs**:
   ```powershell
   Get-Content "logs\startup.log" -Tail 50
   ```

3. **Check Permissions**:
   - Ensure task has "Run with highest privileges"
   - Ensure user account has permission to start services

4. **Check Node.js**:
   ```powershell
   node --version
   where.exe node
   ```

5. **Check MongoDB Service**:
   ```powershell
   net start MongoDB
   ```

### Port Already in Use

If ports 8082 or 3003 are already in use:

```powershell
# Find process using port
netstat -ano | findstr ":8082"
netstat -ano | findstr ":3003"

# Kill process (replace PID)
taskkill /F /PID <PID>
```

### ngrok Not Starting

- Ensure ngrok is in system PATH
- Check ngrok authentication: `ngrok config check`
- Verify domain: `soc-chat-app.ngrok-free.app`

## 🔧 Manual Service Management

### Start Services Manually

```powershell
# Start Web Server
cd servers
Start-Process node -ArgumentList "server.js" -Environment @{"PORT"="8082";"API_TARGET"="http://localhost:3003"}

# Start API Server
cd servers\local_api_server
Start-Process node -ArgumentList "server.js" -Environment @{"PORT"="3003";"HOST"="0.0.0.0"}

# Start MongoDB
net start MongoDB

# Start ngrok
Start-Process ngrok -ArgumentList "http","3003","--domain=soc-chat-app.ngrok-free.app"
```

### Stop Services

```powershell
# Stop Node.js processes
Get-Process -Name "node" | Stop-Process -Force

# Stop ngrok
Get-Process -Name "ngrok" | Stop-Process -Force

# Stop MongoDB
net stop MongoDB
```

## 📝 Summary

| Feature | Status |
|---------|--------|
| **Auto-Start** | ✅ Enabled |
| **Startup Delay** | 2 minutes |
| **Runs Without User** | ✅ Yes |
| **Logging** | ✅ Yes (`logs\startup.log`) |
| **Process Tracking** | ✅ Yes (`logs\startup_pids.json`) |

**All services will start automatically after PC restart!**

---

**Last Updated**: 2025-01-18

