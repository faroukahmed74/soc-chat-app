# Admin Panel Testing Guide - Phase 1 & Phase 2

## How to Access the Admin Panel

1. **Start the servers:**
   - Run `services_manager_interactive.bat`
   - Choose option 1 (Start All Services)
   - Wait for all services to start

2. **Access the admin panel:**
   - **Web:** Open `http://localhost:8082` or `http://[YOUR_IP]:8082`
   - **Mobile:** Open the app and navigate to Admin Panel
   - Login with admin credentials

---

## Phase 1 Features Testing

### 1. Advanced Analytics Dashboard

**Location:** Admin Panel → Analytics Tab → Click "View Advanced Analytics" button

**What to Test:**
- ✅ **User Growth Chart:** View user registration trends over time
- ✅ **Message Trends:** See message volume charts
- ✅ **DAU/MAU Metrics:** Check Daily/Monthly Active Users
- ✅ **Retention Rates:** View user retention analytics
- ✅ **Peak Usage Times:** See when users are most active
- ✅ **Top Users/Chats:** View most active users and chats
- ✅ **Period Selection:** Change date ranges (7d, 30d, 90d, 1y)
- ✅ **Chart Types:** Line charts, bar charts, area charts

**Test Steps:**
1. Navigate to Analytics tab
2. Click "View Advanced Analytics" button
3. Select different time periods
4. Review all metric cards
5. Check chart responsiveness (mobile/tablet/desktop)

---

### 2. Content Moderation Tools

**Location:** Admin Panel → Moderation Tab

**What to Test:**
- ✅ **Rules Tab:**
  - Create new moderation rules
  - Add keywords to blacklist/whitelist
  - Configure auto-flagging rules
  - Edit/delete existing rules
  
- ✅ **Queue Tab:**
  - View flagged messages
  - Review message content
  - Approve/reject messages
  - Bulk actions on multiple items
  
- ✅ **History Tab:**
  - View moderation actions history
  - See user violations
  - Check moderation statistics

**Test Steps:**
1. Go to Moderation tab
2. Create a test moderation rule
3. Send a test message that triggers the rule
4. Check the Queue tab for flagged messages
5. Review and process flagged items
6. Check History tab for logged actions

---

### 3. Real-Time Activity Feed

**Location:** Admin Panel → Dashboard Tab → "Recent Activity" section → Click "Full Feed" button

**What to Test:**
- ✅ **Live Updates:** See real-time activity as it happens
- ✅ **Activity Types:** Filter by user registration, messages, reports, admin actions
- ✅ **Search:** Search activities by keyword
- ✅ **Activity Details:** View detailed information for each activity
- ✅ **Connection Status:** See WebSocket connection indicator

**Test Steps:**
1. Go to Dashboard tab
2. Scroll to "Recent Activity" section
3. Click "Full Feed" button
4. Perform actions (send message, create user, etc.)
5. Watch activities appear in real-time
6. Test filters and search

---

### 4. Advanced User Management

**Location:** Admin Panel → Users Tab

**What to Test:**
- ✅ **User Detail View:**
  - Click on any user to see detailed profile
  - View tabs: Profile, Activity, Messages, Chats, Devices, Violations
  - Check user statistics and insights
  
- ✅ **Bulk Operations:**
  - Select multiple users with checkboxes
  - Use bulk action buttons (Lock, Unlock, Delete, Change Role)
  - Confirm bulk operations
  
- ✅ **User Insights:**
  - View account age
  - Check activity metrics
  - See risk scores
  - Review violation history

**Test Steps:**
1. Go to Users tab
2. Click on a user to open detail view
3. Navigate through all tabs in user detail
4. Select multiple users
5. Perform bulk operations
6. Verify actions are logged

---

### 5. Scheduled Broadcasts

**Location:** Admin Panel → Dashboard Tab → "Broadcast" section → Click "Schedule Broadcast" button

**What to Test:**
- ✅ **Schedule New Broadcast:**
  - Set date and time
  - Choose recurrence (one-time, daily, weekly, monthly)
  - Select target users (all, specific roles, segments)
  - Compose message
  
- ✅ **View Scheduled Broadcasts:**
  - See list of all scheduled broadcasts
  - View broadcast details
  - Edit or cancel scheduled broadcasts
  
- ✅ **Broadcast History:**
  - See sent broadcasts
  - Check delivery status
  - View broadcast statistics

**Test Steps:**
1. Go to Dashboard tab
2. Click "Schedule Broadcast" button
3. Create a test broadcast (schedule for 1 minute in future)
4. Wait and verify broadcast is sent
5. Check broadcast history
6. Test recurrence options

---

## Phase 2 Features Testing

### 1. Advanced Search & Filtering

**Location:** Admin Panel → AppBar → Search icon (🔍) button

**What to Test:**
- ✅ **Unified Search:**
  - Search across users, chats, and messages simultaneously
  - Use multi-field search inputs
  - Apply filters (date range, role, status)
  
- ✅ **Saved Searches:**
  - Save frequently used search queries
  - Load saved searches
  - Delete saved searches
  
- ✅ **Search History:**
  - View recent searches
  - Re-run previous searches
  - Clear search history

**Test Steps:**
1. Click search icon in AppBar
2. Enter search query
3. Select search types (users/chats/messages)
4. Apply filters
5. Save a search query
6. Test saved searches tab
7. Check search history

---

### 2. Security & Compliance

**Location:** Admin Panel → AppBar → Security icon (🛡️) button

**What to Test:**
- ✅ **Security Tab:**
  - View security settings
  - Configure session timeout
  - Set password policies
  - Enable/disable 2FA settings
  
- ✅ **IP Management Tab:**
  - Add IPs to whitelist
  - Add IPs to blacklist
  - Remove IPs from lists
  - View current IP lists
  
- ✅ **Activity Tab:**
  - View failed login attempts
  - Check suspicious activity logs
  - Review security events
  
- ✅ **Compliance Tab:**
  - Export user data (GDPR)
  - Delete user data (GDPR)
  - Configure data retention policies
  - Track user consent

**Test Steps:**
1. Click security icon in AppBar
2. Go to Security tab - review settings
3. Go to IP Management tab - add test IPs
4. Go to Activity tab - check failed logins
5. Go to Compliance tab - test GDPR export
6. Test data retention settings

---

### 3. Performance Monitoring

**Location:** Admin Panel → AppBar → Performance icon (⚡) button

**What to Test:**
- ✅ **Metrics Dashboard:**
  - View API response times
  - Check error rates
  - Monitor active connections
  - See message delivery rates
  - View system resources (CPU, memory)
  
- ✅ **Charts:**
  - Response time trends (line chart)
  - Error rate trends (bar chart)
  - Resource usage graphs
  
- ✅ **Alerts:**
  - View performance alerts
  - Resolve alerts
  - Check alert history
  
- ✅ **Auto-Refresh:**
  - Metrics update automatically
  - Real-time monitoring

**Test Steps:**
1. Click performance icon in AppBar
2. Review all metric cards
3. Check response time charts
4. View error rate charts
5. Check alerts section
6. Verify auto-refresh works
7. Test alert resolution

---

### 4. Notification Management

**Location:** Admin Panel → AppBar → Notifications icon (🔔) button

**What to Test:**
- ✅ **Templates Tab:**
  - Create notification templates
  - Edit templates
  - Delete templates
  - View template list
  
- ✅ **Send Tab:**
  - Send test notifications
  - Use templates or custom messages
  - Select target users
  
- ✅ **History Tab:**
  - View notification history
  - Filter by status (sent/failed)
  - Retry failed notifications
  - See delivery details
  
- ✅ **Analytics Tab:**
  - View notification statistics
  - Check success rates
  - See notifications over time chart
  - View top templates

**Test Steps:**
1. Click notifications icon in AppBar
2. Go to Templates tab - create a template
3. Go to Send tab - send test notification
4. Go to History tab - check delivery status
5. Go to Analytics tab - review statistics
6. Test retry for failed notifications

---

### 5. Chat Moderation Tools

**Location:** Admin Panel → Chats Tab → Click moderation icon (⚙️) on any chat

**What to Test:**
- ✅ **Details Tab:**
  - View chat information
  - See owner and moderators
  - Check chat status (muted/archived)
  - Quick actions (mute/unmute, archive/unarchive)
  
- ✅ **Messages Tab:**
  - View all chat messages
  - Paginate through messages
  - Delete messages (admin action)
  - See sender information
  
- ✅ **Members Tab:**
  - View all members
  - See owner and moderators
  - Add/remove moderators
  - Navigate to user profiles
  
- ✅ **Settings Tab (Groups only):**
  - Transfer group ownership
  - Update group permissions
  - Configure member permissions

**Test Steps:**
1. Go to Chats tab
2. Click moderation icon on a chat
3. Review Details tab
4. Go to Messages tab - view and delete a message
5. Go to Members tab - add a moderator
6. Go to Settings tab - update permissions (for groups)
7. Test mute/archive actions

---

## Quick Testing Checklist

### Phase 1 Features
- [ ] Advanced Analytics Dashboard - View charts and metrics
- [ ] Content Moderation - Create rules and process queue
- [ ] Real-Time Activity Feed - See live updates
- [ ] Advanced User Management - View user details and bulk operations
- [ ] Scheduled Broadcasts - Schedule and send broadcasts

### Phase 2 Features
- [ ] Advanced Search - Search across users/chats/messages
- [ ] Security & Compliance - Manage IPs and GDPR tools
- [ ] Performance Monitoring - View metrics and alerts
- [ ] Notification Management - Create templates and send notifications
- [ ] Chat Moderation - Moderate chats and manage groups

---

## Responsive Design Testing

Test all features on different screen sizes:

1. **Mobile (< 600px):**
   - Tabs should be scrollable
   - Cards stack vertically
   - Icons-only navigation

2. **Tablet (600px - 1024px):**
   - Mixed layout (some side-by-side)
   - Text + icon tabs
   - Optimized spacing

3. **Desktop (> 1024px):**
   - Full layout with sidebars
   - All features visible
   - Maximum information density

---

## Common Issues & Solutions

**Issue:** Can't see real-time updates
- **Solution:** Check WebSocket connection status indicator

**Issue:** Search not returning results
- **Solution:** Ensure you've selected search types (users/chats/messages)

**Issue:** Performance metrics not updating
- **Solution:** Check auto-refresh is enabled, wait a few seconds

**Issue:** Notification not sending
- **Solution:** Check FCM server is running, verify user has valid token

**Issue:** Chat moderation actions not working
- **Solution:** Ensure you're testing on a group chat (not 1-on-1)

---

## Tips for Testing

1. **Start with Dashboard:** Get overview of all features
2. **Test in Order:** Phase 1 → Phase 2 for logical flow
3. **Use Test Data:** Create test users, chats, messages
4. **Check Logs:** Monitor server logs for errors
5. **Test Responsiveness:** Resize browser window
6. **Verify Persistence:** Refresh page, check data persists
7. **Test Edge Cases:** Empty states, large datasets, errors

---

## Need Help?

If you encounter issues:
1. Check browser console for errors
2. Verify all servers are running
3. Check network connectivity
4. Review server logs
5. Ensure MongoDB is running

Happy Testing! 🚀

