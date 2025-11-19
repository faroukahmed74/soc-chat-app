# SOC Chat App - Mirror Backup Guide

## 📋 What is a Mirror Backup?

A **mirror backup** creates an exact copy of your current data that is updated regularly. Unlike regular backups that keep multiple versions, a mirror backup keeps only the **latest version**.

### Key Differences

| Feature | Regular Backup | Mirror Backup |
|---------|---------------|---------------|
| **Versions** | Multiple (keeps history) | Single (latest only) |
| **Frequency** | Daily | Every 6 hours (configurable) |
| **Storage** | Grows over time | Fixed size |
| **Purpose** | Version history, recovery | Quick disaster recovery |
| **Restore** | Choose from versions | Restore latest only |

## 🎯 When to Use Mirror Backup

**Use Mirror Backup For:**
- ✅ Quick disaster recovery (exact current state)
- ✅ Real-time data protection
- ✅ Secondary backup location
- ✅ Fast restore (no need to extract ZIP)

**Use Regular Backup For:**
- ✅ Version history
- ✅ Point-in-time recovery
- ✅ Long-term archival

## 🚀 Quick Start

### Run Mirror Backup Now

```powershell
.\scripts\mirror_backup.ps1
```

### Schedule Automatic Mirror Backups

```powershell
# Default: Every 6 hours
.\scripts\schedule_mirror_backup.ps1

# Custom: Every 4 hours
.\scripts\schedule_mirror_backup.ps1 -IntervalHours 4
```

## 📁 Mirror Structure

```
F:\soc-chat-mirror\
├── MongoDB\
│   ├── data\db\          # Exact copy of MongoDB
│   └── log\              # MongoDB logs
├── uploads\
│   └── chat_media\       # Exact copy of all media files
├── config\
│   └── .env             # Configuration file
└── mirror_info.json     # Mirror metadata
```

## ⚙️ Configuration

### Default Settings

- **Mirror Location**: `F:\soc-chat-mirror`
- **Update Frequency**: Every 6 hours
- **Sync Method**: Robocopy (efficient Windows tool)

### Custom Mirror Location

```powershell
.\scripts\mirror_backup.ps1 -MirrorDir "F:\backup-mirror"
```

## 🔄 How Mirror Backup Works

1. **Syncs MongoDB**: Uses robocopy to mirror database files
2. **Syncs Media**: Mirrors all media files (adds new, updates changed, deletes removed)
3. **Syncs Config**: Copies configuration files
4. **No Compression**: Files remain accessible directly
5. **No History**: Only latest version kept

### Robocopy Features Used

- `/MIR` - Mirror mode (exact copy, deletes files not in source)
- `/R:3` - Retry 3 times on failure
- `/W:1` - Wait 1 second between retries
- Efficient: Only copies changed files

## 📊 Backup Strategy Recommendation

### Recommended Setup

**Daily Full Backups** (Version History)
- Time: 2:00 AM daily
- Location: `F:\soc-chat-backups\`
- Retention: 30 days
- Purpose: Version history, point-in-time recovery

**Mirror Backups** (Quick Recovery)
- Time: Every 6 hours
- Location: `F:\soc-chat-mirror\`
- Retention: Latest only
- Purpose: Quick disaster recovery

### Benefits of This Strategy

1. **Version History**: Daily backups keep 30 days of history
2. **Quick Recovery**: Mirror backup for fast restore
3. **Redundancy**: Two backup types protect against different scenarios
4. **Flexibility**: Choose backup type based on recovery need

## 🔧 Restore from Mirror

### Quick Restore

Since mirror backup is an exact copy (not compressed), you can:

1. **Copy directly**:
   ```powershell
   # Stop MongoDB
   Stop-Service MongoDB
   
   # Copy from mirror
   Copy-Item "F:\soc-chat-mirror\MongoDB\data\db\*" "D:\soc-chat-data\MongoDB\data\db\" -Recurse -Force
   Copy-Item "F:\soc-chat-mirror\uploads\*" "D:\soc-chat-data\uploads\" -Recurse -Force
   
   # Start MongoDB
   Start-Service MongoDB
   ```

2. **Or use restore script** (modify to point to mirror):
   ```powershell
   .\scripts\restore_app_data.ps1 -BackupPath "F:\soc-chat-mirror"
   ```

## 📝 Maintenance

### Check Mirror Status

```powershell
# View mirror info
Get-Content "F:\soc-chat-mirror\mirror_info.json"

# Check mirror size
Get-ChildItem "F:\soc-chat-mirror" -Recurse | Measure-Object -Property Length -Sum
```

### Dry Run (Test Without Changes)

```powershell
.\scripts\mirror_backup.ps1 -DryRun
```

This shows what would be synced without actually making changes.

## ⚠️ Important Notes

1. **No Version History**: Mirror backup keeps only latest version
2. **Deletes Removed Files**: If you delete a file from source, it's deleted from mirror
3. **Requires Space**: Mirror uses same space as source (~800 MB)
4. **Not Compressed**: Files are stored as-is (faster access)

## 🔐 Security

- Mirror backup contains exact copy of your data
- Store in secure location
- Consider encrypting mirror directory for sensitive data
- Same security considerations as regular backups

## 📞 Troubleshooting

### Mirror Sync Fails

**Issue**: Robocopy returns error code 8+
```powershell
# Check source paths exist
Test-Path "D:\soc-chat-data\MongoDB\data\db"
Test-Path "D:\soc-chat-data\uploads"

# Check permissions
# Ensure script has read access to source and write access to mirror
```

### Mirror Out of Sync

**Solution**: Run mirror backup manually
```powershell
.\scripts\mirror_backup.ps1
```

### Check Last Sync Time

```powershell
$info = Get-Content "F:\soc-chat-mirror\mirror_info.json" | ConvertFrom-Json
Write-Host "Last sync: $($info.timestamp)"
```

---

**Last Updated**: 2025-01-18
**Version**: 1.0

