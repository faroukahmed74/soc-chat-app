# SOC Chat App - Backup Storage Calculator

## 📊 Current Data Sizes

Based on your actual data:
- **MongoDB Database**: 0.49 GB (490 MB)
- **Media Files**: 0.30 GB (300 MB)
- **Total Source Data**: **0.79 GB (790 MB)**
- **Compressed Backup Size**: **0.50 GB (500 MB)** per backup

---

## 💾 Storage Requirements for All Three Backup Types

### 1. Real-Time Backup
- **Location**: `F:\soc-chat-realtime\`
- **Type**: Mirror (latest only, uncompressed)
- **Size**: **0.79 GB** (same as source data)
- **Retention**: Latest only (fixed size, no time limit)
- **Growth**: Fixed (doesn't grow over time)

### 2. Mirror Backup
- **Location**: `F:\soc-chat-mirror\`
- **Type**: Mirror (latest only, uncompressed)
- **Size**: **0.79 GB** (same as source data)
- **Retention**: Latest only (fixed size, no time limit)
- **Growth**: Fixed (doesn't grow over time)

### 3. Full Backups
- **Location**: `F:\soc-chat-backups\`
- **Type**: Full backup (compressed ZIP)
- **Size per backup**: **0.50 GB** (500 MB)
- **Frequency**: Daily
- **Retention**: 30 days
- **Total storage**: **15 GB** (30 days × 500 MB)

---

## 📈 Total Storage Requirements

### Current Setup (30-day retention)

| Backup Type | Size | Retention | Total Storage |
|-------------|------|-----------|---------------|
| Real-Time | 0.79 GB | Latest only | **0.79 GB** |
| Mirror | 0.79 GB | Latest only | **0.79 GB** |
| Full Backups | 0.50 GB each | 30 days | **15.00 GB** |
| **TOTAL** | | | **~16.6 GB** |

### Storage Breakdown

```
F:\
├── soc-chat-realtime\     → 0.79 GB (fixed)
├── soc-chat-mirror\       → 0.79 GB (fixed)
└── soc-chat-backups\      → 15.00 GB (grows with retention)
    ├── backup_day1.zip   → 500 MB
    ├── backup_day2.zip   → 500 MB
    ├── ...
    └── backup_day30.zip  → 500 MB
```

---

## 📅 Storage Over Time

### 30-Day Retention (Current)
- **Total Storage**: ~16.6 GB
- **Real-Time**: 0.79 GB (fixed)
- **Mirror**: 0.79 GB (fixed)
- **Full Backups**: 15 GB (30 days)

### 60-Day Retention
- **Total Storage**: ~31.6 GB
- **Real-Time**: 0.79 GB (fixed)
- **Mirror**: 0.79 GB (fixed)
- **Full Backups**: 30 GB (60 days)

### 90-Day Retention
- **Total Storage**: ~46.6 GB
- **Real-Time**: 0.79 GB (fixed)
- **Mirror**: 0.79 GB (fixed)
- **Full Backups**: 45 GB (90 days)

### 365-Day Retention (1 Year)
- **Total Storage**: ~183.6 GB
- **Real-Time**: 0.79 GB (fixed)
- **Mirror**: 0.79 GB (fixed)
- **Full Backups**: 182 GB (365 days)

---

## 💡 Storage Optimization Options

### Option 1: Reduce Full Backup Retention
- **30 days** → **15 days**: Saves 7.5 GB (Total: ~9.1 GB)
- **30 days** → **7 days**: Saves 11.5 GB (Total: ~5.1 GB)

### Option 2: Remove One Mirror Backup
- Keep only **Real-Time** OR **Mirror** (not both)
- Saves: **0.79 GB** (Total: ~15.8 GB)

### Option 3: Weekly Full Backups
- Full backup: **Weekly** instead of daily
- 30 days = 4-5 backups instead of 30
- Saves: **~12.5 GB** (Total: ~4.1 GB)

### Option 4: Incremental Full Backups
- Weekly full + daily incremental
- Saves: **~70% storage** (Total: ~5-6 GB)

---

## 📊 Recommended Configurations

### Minimum Storage (Basic Protection)
- **Real-Time Backup**: 0.79 GB
- **Full Backups**: 7 days retention = 3.5 GB
- **Total**: **~4.3 GB**

### Balanced (Recommended)
- **Real-Time Backup**: 0.79 GB
- **Mirror Backup**: 0.79 GB
- **Full Backups**: 30 days = 15 GB
- **Total**: **~16.6 GB**

### Maximum Protection
- **Real-Time Backup**: 0.79 GB
- **Mirror Backup**: 0.79 GB
- **Full Backups**: 90 days = 45 GB
- **Total**: **~46.6 GB**

---

## 🔄 Storage Growth Projection

Assuming your data grows:

| Data Growth | Real-Time | Mirror | Full (30 days) | Total |
|-------------|-----------|--------|----------------|-------|
| **Current** (0.79 GB) | 0.79 GB | 0.79 GB | 15 GB | **16.6 GB** |
| **2x Growth** (1.58 GB) | 1.58 GB | 1.58 GB | 30 GB | **33.2 GB** |
| **5x Growth** (3.95 GB) | 3.95 GB | 3.95 GB | 75 GB | **82.9 GB** |
| **10x Growth** (7.9 GB) | 7.9 GB | 7.9 GB | 150 GB | **165.8 GB** |

---

## 💾 F: Partition Space Check

To check available space on F: partition:

```powershell
Get-PSDrive F | Select-Object Used, Free, @{Name="Total(GB)";Expression={[math]::Round($_.Used/1GB + $_.Free/1GB, 2)}}, @{Name="Free(GB)";Expression={[math]::Round($_.Free/1GB, 2)}}
```

---

## 📝 Summary

**Current Storage Needed (30-day retention):**
- **Minimum**: ~16.6 GB for all three backup types
- **Real-Time**: 0.79 GB (fixed, no growth)
- **Mirror**: 0.79 GB (fixed, no growth)
- **Full Backups**: 15 GB (grows with retention period)

**Time Periods:**
- **Real-Time**: Continuous (no time limit, fixed size)
- **Mirror**: Continuous (no time limit, fixed size)
- **Full Backups**: 30 days retention (configurable)

---

**Last Updated**: 2025-01-18

