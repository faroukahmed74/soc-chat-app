# SOC Chat App - Backup & Restore Guide

## 📋 Overview

This backup system provides complete data protection for your SOC Chat App, including:
- **MongoDB Database** (all messages, users, chats)
- **Media Files** (images, videos, audio, documents)
- **Configuration Files** (.env settings)

## 🚀 Quick Start

### Manual Backup

```powershell
# Basic backup (compressed, 30-day retention)
.\scripts\backup_app_data.ps1

# Custom backup
.\scripts\backup_app_data.ps1 -BackupDir "D:\backups" -RetentionDays 60

# Uncompressed backup
.\scripts\backup_app_data.ps1 -Compress:$false
```

### Restore from Backup

```powershell
# Restore from backup
.\scripts\restore_app_data.ps1 -BackupPath "F:\soc-chat-backups\soc_chat_backup_20250118_143022.zip"

# Restore only media files
.\scripts\restore_app_data.ps1 -BackupPath "F:\soc-chat-backups\backup.zip" -RestoreMongoDB:$false -RestoreConfig:$false
```

### Schedule Automatic Backups

```powershell
# Schedule daily backups at 2 AM
.\scripts\schedule_backup.ps1

# Custom schedule (every 12 hours, 60-day retention)
.\scripts\schedule_backup.ps1 -IntervalHours 12 -RetentionDays 60

# Remove scheduled backups
.\scripts\schedule_backup.ps1 -RemoveSchedule
```

## 📁 Backup Structure

```
F:\soc-chat-backups\
├── soc_chat_backup_20250118_143022.zip
├── soc_chat_backup_20250119_143022.zip
└── latest_backup.txt
```

Each backup contains:
```
soc_chat_backup_YYYYMMDD_HHMMSS/
├── mongodb/              # MongoDB database dump
│   ├── soc_chat_app/     # Database collections
│   └── data/db/          # Raw database files (if copied)
├── uploads/              # Media files
│   └── chat_media/       # Organized by chat ID
├── config/               # Configuration files
│   └── .env             # Server configuration
└── backup_info.json     # Backup metadata
```

## ⚙️ Configuration

### Environment Variables

You can set these in your system or `.env` file:

- `BACKUP_DIR` - Backup storage location (default: `F:\soc-chat-backups`)
- `RETENTION_DAYS` - How long to keep backups (default: 30 days)

### Backup Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-BackupDir` | Where to store backups | `F:\soc-chat-backups` |
| `-Compress` | Create ZIP archive | `$true` |
| `-RetentionDays` | Days to keep backups | `30` |
| `-Quiet` | Suppress output | `$false` |

## 🔄 Backup Process

1. **MongoDB Backup**
   - Uses `mongodump` if MongoDB is running
   - Falls back to direct file copy if MongoDB is stopped
   - Backs up all collections in `soc_chat_app` database

2. **Media Files Backup**
   - Copies entire `uploads/chat_media/` directory
   - Preserves folder structure by chat ID
   - Includes all file types (images, videos, audio, documents)

3. **Configuration Backup**
   - Backs up `.env` file
   - Creates `backup_info.json` with metadata

4. **Compression** (optional)
   - Creates ZIP archive
   - Removes uncompressed folder
   - Reduces storage by ~60-80%

5. **Cleanup**
   - Removes backups older than retention period
   - Keeps disk space manageable

## 🔧 Restore Process

### Prerequisites

1. **Stop MongoDB** (recommended for file-based restore)
   ```powershell
   Stop-Service MongoDB
   # Or stop mongod process
   ```

2. **Stop API Server** (to prevent data conflicts)

### Restore Steps

1. **Full Restore**
   ```powershell
   .\scripts\restore_app_data.ps1 -BackupPath "F:\soc-chat-backups\backup.zip"
   ```

2. **Selective Restore**
   ```powershell
   # Only restore MongoDB
   .\scripts\restore_app_data.ps1 -BackupPath "backup.zip" -RestoreMedia:$false -RestoreConfig:$false
   
   # Only restore media files
   .\scripts\restore_app_data.ps1 -BackupPath "backup.zip" -RestoreMongoDB:$false -RestoreConfig:$false
   ```

3. **After Restore**
   - Start MongoDB service
   - Start API server
   - Verify data integrity

## 📊 Backup Best Practices

### 1. Regular Backups
- **Daily**: For active production systems
- **Weekly**: For low-activity systems
- **Before Updates**: Always backup before major changes

### 2. Multiple Locations
- **Local**: Fast restore (D: drive)
- **External Drive**: Protection against disk failure
- **Cloud**: Protection against physical disaster

### 3. Test Restores
- Test restore process monthly
- Verify data integrity after restore
- Document restore procedures

### 4. Monitoring
- Check backup logs regularly
- Monitor backup disk space
- Set up alerts for backup failures

## 🛠️ Troubleshooting

### Backup Fails

**Issue**: MongoDB backup fails
```powershell
# Solution 1: Stop MongoDB and use file copy
Stop-Service MongoDB
.\scripts\backup_app_data.ps1

# Solution 2: Install MongoDB tools
# Download from: https://www.mongodb.com/try/download/database-tools
```

**Issue**: Insufficient disk space
```powershell
# Check available space
Get-PSDrive D

# Clean old backups manually
Get-ChildItem "F:\soc-chat-backups" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item
```

### Restore Fails

**Issue**: MongoDB restore fails
- Ensure MongoDB is stopped
- Check file permissions
- Verify backup integrity

**Issue**: Media files not restoring
- Check target directory exists
- Verify disk space
- Check file permissions

## 📝 Backup Verification

### Check Backup Contents

```powershell
# List all backups
Get-ChildItem "F:\soc-chat-backups" | Sort-Object LastWriteTime -Descending

# View backup info
Get-Content "F:\soc-chat-backups\latest_backup.txt"

# Check backup size
Get-ChildItem "F:\soc-chat-backups" | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}}
```

### Verify Backup Integrity

```powershell
# Test ZIP file
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [System.IO.Compression.ZipFile]::OpenRead("backup.zip") | Out-Null
    Write-Host "✅ Backup file is valid"
} catch {
    Write-Host "❌ Backup file is corrupted"
}
```

## 🔐 Security Considerations

1. **Backup Encryption**: Consider encrypting backups for sensitive data
2. **Access Control**: Restrict backup directory permissions
3. **Secure Storage**: Store backups in secure locations
4. **Backup Rotation**: Regularly rotate backup storage

## 📞 Support

For backup issues:
1. Check backup logs
2. Verify disk space
3. Test with manual backup
4. Check MongoDB/API server status

## 📅 Maintenance Schedule

- **Daily**: Automatic backups (if scheduled)
- **Weekly**: Verify backup integrity
- **Monthly**: Test restore procedure
- **Quarterly**: Review backup retention policy

---

**Last Updated**: 2025-01-18
**Version**: 1.0

