# 🚀 Quick Backup Guide

## One-Command Backup

```powershell
# Run from project root
.\scripts\backup_app_data.ps1
```

This will:
- ✅ Backup MongoDB database
- ✅ Backup all media files (235+ files)
- ✅ Backup configuration
- ✅ Compress to ZIP
- ✅ Clean old backups (30+ days)
- ✅ Save to: `F:\soc-chat-backups\`

## Schedule Daily Backups

```powershell
.\scripts\schedule_backup.ps1
```

Backups will run automatically **every day at 2:00 AM**

## Restore from Backup

```powershell
.\scripts\restore_app_data.ps1 -BackupPath "F:\soc-chat-backups\soc_chat_backup_20250118_143022.zip"
```

## View Backups

```powershell
Get-ChildItem "F:\soc-chat-backups" | Sort-Object LastWriteTime -Descending
```

## What Gets Backed Up?

| Item | Location | Size |
|------|----------|------|
| MongoDB Database | `D:\soc-chat-data\MongoDB\data\db` | ~40 files |
| Media Files | `D:\soc-chat-data\uploads\chat_media\` | 235+ files |
| Configuration | `servers/local_api_server/.env` | 1 file |

## Backup Location

All backups stored in: **`F:\soc-chat-backups\`**

## Mirror Backup (Quick Recovery)

```powershell
# Run mirror backup (exact copy, updated every 6 hours)
.\scripts\mirror_backup.ps1

# Schedule automatic mirror backups
.\scripts\schedule_mirror_backup.ps1
```

**Mirror Location**: `F:\soc-chat-mirror\`

**Difference**: Mirror keeps only latest version (no history), perfect for quick recovery.

## Real-Time Backup (Instant Sync)

```powershell
# Start real-time backup (monitors and syncs instantly)
.\scripts\realtime_backup.ps1

# Start in background
.\scripts\start_realtime_backup.ps1

# Stop real-time backup
.\scripts\realtime_backup.ps1 -Stop
```

**Real-Time Location**: `F:\soc-chat-realtime\`

**Difference**: Syncs changes immediately (zero delay), perfect for critical data.

---

**Need more details?** 
- Regular Backups: See `scripts/BACKUP_README.md`
- Mirror Backups: See `scripts/MIRROR_BACKUP_README.md`
- Real-Time Backup: See `scripts/REALTIME_BACKUP_README.md`

