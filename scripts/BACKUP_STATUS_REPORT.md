# SOC Chat App - Backup Status Report
**Generated:** 2025-12-08 16:19:04

---

## Executive Summary

**Overall Status:** [WARNING] Real-Time Backup Not Running

| Component | Status |
|-----------|--------|
| All Scheduled Tasks Found | [OK] Yes |
| All Tasks Ready | [OK] Yes |
| Real-Time Backup Running | [X] No |
| All Storage Directories Exist | [OK] Yes |

---

## 1. Full Backup System

### Scheduled Task Status
- **Task Name:** SOC_Chat_App_Backup
- **Status:** Found
- **State:** Ready
- **Enabled:** True
- **Last Run:** 12/8/2025 2:00:00 AM
- **Last Result:** 0
- **Next Run:** 12/9/2025 2:00:00 AM

### Storage Location
- **Path:** F:\soc-chat-backups
- **Exists:** [OK] Yes
- **Files:** 22
- **Directories:** 0
- **Total Size:** 11.12 GB (11389.18 MB)
- **Recent Backups:** 5
- **Latest Backup:** soc_chat_backup_20251208_020004.zip
- **Latest Backup Time:** 12/8/2025 2:03:48 AM

---

## 2. Mirror Backup System

### Scheduled Task Status
- **Task Name:** SOC_Chat_App_Mirror_Backup
- **Status:** Found
- **State:** Ready
- **Enabled:** True
- **Last Run:** 12/8/2025 12:00:00 PM
- **Last Result:** 0
- **Next Run:** 12/8/2025 6:00:00 PM

### Storage Location
- **Path:** F:\soc-chat-mirror
- **Exists:** [OK] Yes
- **Files:** 445
- **Directories:** 60
- **Total Size:** 0.84 GB (856.47 MB)

---

## 3. Real-Time Backup System

### Auto-Start Task Status
- **Task Name:** SOC_Chat_App_Start_RealTime_Backup
- **Status:** Found
- **State:** Ready
- **Enabled:** True
- **Last Run:** 12/8/2025 3:07:07 PM
- **Last Result:** 0

### Process Status
- **Status:** Not Running
- **Process Count:** 0

### Storage Location
- **Path:** F:\soc-chat-realtime
- **Exists:** [OK] Yes
- **Files:** 441
- **Directories:** 58
- **Total Size:** 0.84 GB (856.24 MB)

---

## Recommendations

[WARNING] **Action Required:** Real-Time backup is not running. Start it with:
- `.\scripts\start_realtime_backup.ps1`

---

**Report Generated:** 2025-12-08 16:19:04
