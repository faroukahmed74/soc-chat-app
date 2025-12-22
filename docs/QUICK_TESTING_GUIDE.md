# Quick Testing Guide - Phase 1 & Phase 2 Features

## 📍 PHASE 1 FEATURES

### 1. Advanced Analytics Dashboard
**Location:** Admin Panel → **Analytics Tab** → Click **"View Advanced Analytics"** button

**Quick Test:**
- Navigate to Analytics tab
- Click "View Advanced Analytics" button
- Change time period (7d, 30d, 90d, 1y)
- View all charts and metrics

---

### 2. Content Moderation Tools
**Location:** Admin Panel → **Moderation Tab**

**Quick Test:**
- Go to Moderation tab
- **Rules Tab:** Create a test moderation rule
- **Queue Tab:** View flagged messages
- **History Tab:** Check moderation history

---

### 3. Real-Time Activity Feed
**Location:** Admin Panel → **Dashboard Tab** → "Recent Activity" section → Click **"Full Feed"** button

**Quick Test:**
- Go to Dashboard tab
- Scroll to "Recent Activity" section
- Click "Full Feed" button
- Perform actions (send message, create user)
- Watch activities appear in real-time

---

### 4. Advanced User Management
**Location:** Admin Panel → **Users Tab**

**Quick Test:**
- Go to Users tab
- **Click any user** → Opens detailed profile with tabs:
  - Profile, Activity, Messages, Chats, Devices, Violations
- **Select multiple users** → Use bulk action buttons
- Test bulk lock/unlock/delete/role-change

---

### 5. Scheduled Broadcasts
**Location:** Admin Panel → **Dashboard Tab** → "Broadcast" section → Click **"Schedule Broadcast"** button

**Quick Test:**
- Go to Dashboard tab
- Click "Schedule Broadcast" button
- Create a test broadcast (schedule 1 minute in future)
- Wait and verify it sends
- Check broadcast history

---

## 📍 PHASE 2 FEATURES

### 1. Advanced Search & Filtering
**Location:** Admin Panel → **Top AppBar** → **Search icon (🔍)** button

**Quick Test:**
- Click search icon in top AppBar
- Enter search query
- Select search types (users/chats/messages)
- Apply filters
- Save a search query
- Check "Saved" and "History" tabs

---

### 2. Security & Compliance
**Location:** Admin Panel → **Top AppBar** → **Security icon (🛡️)** button

**Quick Test:**
- Click security icon in top AppBar
- **Security Tab:** Review security settings
- **IP Management Tab:** Add/remove IPs from whitelist/blacklist
- **Activity Tab:** View failed logins and suspicious activity
- **Compliance Tab:** Test GDPR export/delete

---

### 3. Performance Monitoring
**Location:** Admin Panel → **Top AppBar** → **Performance icon (⚡)** button

**Quick Test:**
- Click performance icon in top AppBar
- View all metric cards (response times, error rates, etc.)
- Check charts (response time, error rate)
- View alerts section
- Verify auto-refresh works

---

### 4. Notification Management
**Location:** Admin Panel → **Top AppBar** → **Notifications icon (🔔)** button

**Quick Test:**
- Click notifications icon in top AppBar
- **Templates Tab:** Create a notification template
- **Send Tab:** Send a test notification
- **History Tab:** Check delivery status
- **Analytics Tab:** View notification statistics

---

### 5. Chat Moderation Tools
**Location:** Admin Panel → **Chats Tab** → Click **moderation icon (⚙️)** on any chat

**Quick Test:**
- Go to Chats tab
- Click moderation icon (⚙️) on any chat
- **Details Tab:** View chat info, mute/archive
- **Messages Tab:** View messages, delete a message
- **Members Tab:** View members, add/remove moderators
- **Settings Tab:** Transfer ownership, update permissions (groups only)

---

## 🎯 Quick Testing Checklist

### Phase 1
- [ ] Advanced Analytics - View charts
- [ ] Content Moderation - Create rules
- [ ] Real-Time Activity - See live updates
- [ ] User Management - View user details
- [ ] Scheduled Broadcasts - Schedule message

### Phase 2
- [ ] Advanced Search - Search across types
- [ ] Security & Compliance - Manage IPs
- [ ] Performance Monitoring - View metrics
- [ ] Notification Management - Send notification
- [ ] Chat Moderation - Moderate a chat

---

## 📱 Responsive Testing

Test on different screen sizes:
- **Mobile:** Tabs scroll, cards stack
- **Tablet:** Mixed layout
- **Desktop:** Full layout

---

## 🚀 Getting Started

1. Start servers: `services_manager_interactive.bat` → Option 1
2. Access: `http://localhost:8082` or `http://[YOUR_IP]:8082`
3. Login with admin credentials
4. Start testing!

For detailed testing instructions, see: `docs/TESTING_GUIDE.md`

