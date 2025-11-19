# SOC Chat App - Real-Time Backup Guide

## 📋 What is Real-Time Backup?

**Real-Time Backup** monitors your data directories and immediately syncs any changes to the backup location. Unlike scheduled backups, real-time backup happens **instantly** when files are created, modified, or deleted.

### Key Features

- ✅ **Instant Sync**: Changes backed up immediately
- ✅ **Continuous Monitoring**: Watches for file changes 24/7
- ✅ **No Scheduling**: No need to wait for scheduled time
- ✅ **Event-Driven**: Only syncs when changes occur
- ✅ **Background Service**: Runs continuously in background

## 🎯 When to Use Real-Time Backup

**Use Real-Time Backup For:**
- ✅ Critical data that needs immediate protection
- ✅ High-frequency changes (many messages/media per hour)
- ✅ Maximum data protection (zero data loss)
- ✅ Production systems requiring instant backup

**Considerations:**
- ⚠️ Requires continuous running process
- ⚠️ Uses system resources (minimal, but constant)
- ⚠️ Best combined with scheduled backups for redundancy

## 🚀 Quick Start

### Start Real-Time Backup

```powershell
# Start in foreground (see output)
.\scripts\realtime_backup.ps1

# Start in background (runs silently)
.\scripts\start_realtime_backup.ps1
```

### Stop Real-Time Backup

```powershell
# Stop the service
.\scripts\realtime_backup.ps1 -Stop

# Or stop by job ID
Stop-Job -Id <job-id>
```

### Check Status

```powershell
# Check if running
Get-Content "F:\soc-chat-realtime\realtime_status.json"

# View background job
Get-Job
```

## 📁 Real-Time Backup Structure

```
F:\soc-chat-realtime\
├── MongoDB\
│   └── data\db\          # Real-time synced MongoDB
├── uploads\
│   └── chat_media\       # Real-time synced media files
├── realtime_status.json  # Service status
└── last_full_sync.txt    # Last periodic sync time
```

## ⚙️ How It Works

### 1. File System Watchers

The script uses Windows `FileSystemWatcher` to monitor:
- **MongoDB Directory**: `D:\soc-chat-data\MongoDB\data\db`
- **Media Directory**: `D:\soc-chat-data\uploads`

### 2. Event Detection

Watches for:
- **Created**: New files/directories
- **Changed**: Modified files
- **Deleted**: Removed files

### 3. Immediate Sync

When a change is detected:
1. Event triggers immediately
2. File/directory is synced to backup location
3. Change is logged (if not in quiet mode)

### 4. Periodic Full Sync

Every hour, runs a full sync check to catch any missed changes (safety net).

## 📊 Backup Strategy Comparison

| Feature | Scheduled Backup | Mirror Backup | Real-Time Backup |
|---------|-----------------|---------------|------------------|
| **Frequency** | Daily | Every 6 hours | Instant |
| **Delay** | Up to 24 hours | Up to 6 hours | 0 seconds |
| **Resource Usage** | Low (periodic) | Low (periodic) | Continuous (minimal) |
| **Data Loss Risk** | Up to 24 hours | Up to 6 hours | Near zero |
| **Best For** | Version history | Quick recovery | Critical data |

## 🎯 Recommended Complete Backup Strategy

### Three-Layer Protection

1. **Real-Time Backup** (Instant Protection)
   - Location: `F:\soc-chat-realtime\`
   - Purpose: Zero data loss, instant sync
   - Use: Critical data protection

2. **Mirror Backup** (Quick Recovery)
   - Location: `F:\soc-chat-mirror\`
   - Frequency: Every 6 hours
   - Purpose: Fast disaster recovery

3. **Full Backups** (Version History)
   - Location: `F:\soc-chat-backups\`
   - Frequency: Daily
   - Retention: 30 days
   - Purpose: Point-in-time recovery

### Benefits

- **Zero Data Loss**: Real-time backup catches everything
- **Quick Recovery**: Mirror backup for fast restore
- **Version History**: Full backups for point-in-time recovery
- **Redundancy**: Three backup types protect against different scenarios

## 🔧 Configuration

### Default Settings

- **Backup Location**: `F:\soc-chat-realtime`
- **Monitoring**: Continuous (24/7)
- **Sync Method**: Immediate on change + hourly full check
- **Quiet Mode**: Available for background operation

### Custom Location

```powershell
.\scripts\realtime_backup.ps1 -RealtimeBackupDir "F:\backup-realtime"
```

## 📝 Monitoring

### Check Service Status

```powershell
# View status file
Get-Content "F:\soc-chat-realtime\realtime_status.json" | ConvertFrom-Json

# Check if process is running
Get-Process | Where-Object {$_.CommandLine -like "*realtime_backup*"}
```

### View Recent Activity

```powershell
# If running in foreground, see live output
# If running in background, check job output
Receive-Job -Id <job-id>
```

## ⚠️ Important Notes

1. **Continuous Process**: Real-time backup must run continuously
2. **System Resources**: Uses minimal CPU/memory, but always active
3. **Network Impact**: Only affects local disk (no network overhead)
4. **Power Consumption**: Minimal, but continuous
5. **Best on Server**: Ideal for always-on server systems

## 🔐 Security

- Real-time backup contains exact copy of your data
- Store in secure location
- Consider encrypting backup directory
- Monitor access to backup location

## 📞 Troubleshooting

### Service Not Syncing

**Check if running:**
```powershell
Get-Content "F:\soc-chat-realtime\realtime_status.json"
```

**Restart service:**
```powershell
.\scripts\realtime_backup.ps1 -Stop
.\scripts\start_realtime_backup.ps1
```

### High CPU Usage

**Issue**: FileSystemWatcher generating too many events
**Solution**: Add debouncing or reduce monitoring scope

### Missed Changes

**Issue**: Some changes not synced
**Solution**: Periodic full sync (every hour) catches missed changes

### Check Last Sync

```powershell
Get-Content "F:\soc-chat-realtime\last_full_sync.txt"
```

## 🚀 Running as Windows Service

For production use, consider installing as a Windows Service:

1. Use NSSM (Non-Sucking Service Manager)
2. Or use Windows Task Scheduler with "Run whether user is logged on or not"
3. Or use a service wrapper

---

**Last Updated**: 2025-01-18
**Version**: 1.0

