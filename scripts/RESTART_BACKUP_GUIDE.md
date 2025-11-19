# SOC Chat App - Backup Behavior After PC Restart

## ✅ What Happens After Restart

### 1. Full Backups (Daily at 2 AM)
- **Status**: ✅ **Will continue working**
- **Configuration**: Runs even when user is not logged in
- **Behavior**: Automatically runs at scheduled time (2:00 AM daily)
- **No action needed**: Fully automatic

### 2. Mirror Backups (Every 6 hours)
- **Status**: ✅ **Will continue working**
- **Configuration**: Runs even when user is not logged in
- **Behavior**: Automatically runs every 6 hours
- **No action needed**: Fully automatic

### 3. Real-Time Backup
- **Status**: ✅ **Will auto-start after restart**
- **Configuration**: Auto-start task created
- **Behavior**: Starts automatically when PC boots up
- **Delay**: Starts within 1-2 minutes after restart

---

## 🔄 Restart Timeline

### Immediately After Restart

1. **0-2 minutes**: PC boots up
2. **~2 minutes**: Real-time backup auto-starts
3. **Next scheduled time**: Mirror backup runs (within 6 hours)
4. **Next scheduled time**: Full backup runs (at 2:00 AM)

### Example Scenario

**PC restarts at 10:00 AM:**
- **10:02 AM**: Real-time backup starts automatically
- **12:00 PM**: Mirror backup runs (next 6-hour interval)
- **2:00 AM (next day)**: Full backup runs

---

## ✅ Verification After Restart

### Check if Backups Are Running

```powershell
# Check scheduled tasks
Get-ScheduledTask -TaskName "SOC_Chat_App_Backup"
Get-ScheduledTask -TaskName "SOC_Chat_App_Mirror_Backup"
Get-ScheduledTask -TaskName "SOC_Chat_App_Start_RealTime_Backup"

# Check real-time backup
Get-Job | Where-Object {$_.Command -like "*realtime_backup*"}

# Check backup locations
Test-Path "F:\soc-chat-realtime"
Test-Path "F:\soc-chat-mirror"
Test-Path "F:\soc-chat-backups"
```

---

## ⚙️ Configuration Details

### Scheduled Tasks Configuration

All scheduled tasks are configured with:
- **LogonType**: S4U (Service for User)
- **RunLevel**: Highest
- **StartWhenAvailable**: Yes
- **AllowStartIfOnBatteries**: Yes

This means they will:
- ✅ Run even when user is not logged in
- ✅ Run after PC restart
- ✅ Run automatically at scheduled times
- ✅ Continue working without user intervention

### Real-Time Backup Auto-Start

- **Trigger**: At system startup
- **Delay**: ~1-2 minutes after boot
- **Status**: Automatically starts in background

---

## 🔧 Manual Start (If Needed)

If backups don't start automatically after restart:

### Start Real-Time Backup Manually

```powershell
.\scripts\start_realtime_backup.ps1
```

### Check Scheduled Tasks

```powershell
# View all backup tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like "*SOC_Chat_App*"}

# Check task history
Get-WinEvent -LogName Microsoft-Windows-TaskScheduler/Operational | 
    Where-Object {$_.Message -like "*SOC_Chat_App*"} | 
    Select-Object -First 10
```

---

## 📝 Summary

| Backup Type | After Restart | Auto-Start | User Action Needed |
|-------------|---------------|------------|-------------------|
| **Full Backups** | ✅ Works | ✅ Yes | ❌ No |
| **Mirror Backups** | ✅ Works | ✅ Yes | ❌ No |
| **Real-Time Backup** | ✅ Works | ✅ Yes (2 min delay) | ❌ No |

**All backups will continue working automatically after PC restart!**

---

**Last Updated**: 2025-01-18

