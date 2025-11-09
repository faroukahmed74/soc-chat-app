# Group Roles and Permissions

This document outlines all group roles and their associated features/permissions in the SOC Chat App.

## Overview

Group roles are stored in the `memberRoles` field of each group chat document. These roles are **group-specific** and completely separate from app-level admin roles. A user can be a group admin in one group while being a regular member in another group.

---

## Group Roles

### 1. **Creator / Group Admin** 
**Role Value:** `'admin'` (stored in `memberRoles`) or identified by `createdBy` field

**How to Identify:**
- User who created the group (stored in `chat.createdBy`)
- Has `memberRoles[userId] === 'admin'`
- Displayed as "Admin (Creator)" in the UI

**Features & Permissions:**
✅ **Add Members** - Can add new users to the group  
✅ **Remove Members** - Can remove any member from the group (except themselves)  
✅ **Change Member Roles** - Can promote members to Manager or demote Managers to Member  
✅ **View Group Info** - Full access to group information dialog  
✅ **Send Messages** - Can send messages in the group  
✅ **All Member Features** - Has all permissions of regular members  

**Restrictions:**
❌ **Cannot Remove Themselves** - Group creator cannot remove themselves from the group  
❌ **Cannot Change Own Role** - Creator's role cannot be changed (permanently admin)  
❌ **No App Admin Access** - Does NOT have access to app-wide admin features  

**Code Reference:**
- Backend: `servers/local_api_server/server.js` lines 1497, 1527, 1575
- Frontend: `lib/screens/chat_screen_mongodb.dart` lines 1155, 1222

---

### 2. **Manager**
**Role Value:** `'manager'` (stored in `memberRoles`)

**How to Identify:**
- Has `memberRoles[userId] === 'manager'`
- Displayed as "Manager" in the UI
- Can be assigned by the group creator only

**Features & Permissions:**
✅ **Add Members** - Can add new users to the group  
✅ **View Group Info** - Can access group information dialog  
✅ **Send Messages** - Can send messages in the group  
✅ **All Member Features** - Has all permissions of regular members  

**Restrictions:**
❌ **Cannot Remove Members** - Managers cannot remove members from the group  
❌ **Cannot Change Roles** - Managers cannot change other members' roles  
❌ **Cannot Remove Themselves** - Managers cannot remove themselves  
❌ **No App Admin Access** - Does NOT have access to app-wide admin features  

**Code Reference:**
- Backend: `servers/local_api_server/server.js` lines 1498, 1502
- Frontend: `lib/screens/chat_screen_mongodb.dart` lines 1156, 1297

---

### 3. **Member** (Default Role)
**Role Value:** `'member'` (stored in `memberRoles`) or default if not specified

**How to Identify:**
- Has `memberRoles[userId] === 'member'` or no role entry (defaults to member)
- Displayed as "Member" in the UI
- Default role for all new group members

**Features & Permissions:**
✅ **Send Messages** - Can send messages in the group  
✅ **View Group Info** - Can view group information (read-only)  
✅ **View Members** - Can see list of group members  
✅ **Leave Group** - Can leave the group (if implemented)  

**Restrictions:**
❌ **Cannot Add Members** - Members cannot add new users to the group  
❌ **Cannot Remove Members** - Members cannot remove other members  
❌ **Cannot Change Roles** - Members cannot change other members' roles  
❌ **No Management Features** - No administrative capabilities  
❌ **No App Admin Access** - Does NOT have access to app-wide admin features  

**Code Reference:**
- Backend: `servers/local_api_server/server.js` lines 1495, 1518
- Frontend: `lib/screens/chat_screen_mongodb.dart` lines 1154

---

## Role Hierarchy

```
Creator/Group Admin (Highest)
    ↓
Manager
    ↓
Member (Lowest)
```

**Inheritance:**
- Group Admin has all Manager permissions + additional permissions
- Manager has all Member permissions + ability to add members
- Member has basic group participation permissions

---

## Role Assignment Rules

### Who Can Assign Roles?
- **Only the Group Creator** can change member roles
- Group Admins (non-creator) cannot change roles
- Managers cannot change roles
- Members cannot change roles

### Valid Role Assignments:
1. **Creator → Manager**: Creator can promote a Member to Manager
2. **Creator → Member**: Creator can demote a Manager to Member
3. **Cannot Change Creator**: Creator's role is permanent and cannot be changed

### Role Assignment Endpoint:
- **Endpoint:** `PUT /api/chats/:chatId/members/:userId/role`
- **Required Body:** `{ "role": "member" | "manager" }`
- **Permission Check:** Only group creator can call this endpoint
- **Code Reference:** `servers/local_api_server/server.js` lines 1555-1607

---

## Permission Matrix

| Feature | Creator/Group Admin | Manager | Member |
|---------|-------------------|---------|--------|
| Send Messages | ✅ | ✅ | ✅ |
| View Group Info | ✅ | ✅ | ✅ |
| View Members List | ✅ | ✅ | ✅ |
| Add Members | ✅ | ✅ | ❌ |
| Remove Members | ✅ | ❌ | ❌ |
| Change Member Roles | ✅ | ❌ | ❌ |
| Remove Self | ❌ | ❌ | ✅* |
| Change Own Role | ❌ | ❌ | ❌ |

*Leave group functionality may be implemented separately

---

## Role Storage

### Database Structure:
```javascript
{
  _id: ObjectId("..."),
  type: "group",
  name: "Group Name",
  members: [ObjectId("user1"), ObjectId("user2"), ...],
  memberRoles: {
    "user1": "admin",    // Creator/Group Admin
    "user2": "manager",  // Manager
    "user3": "member",   // Member
    "user4": "member"    // Member (default)
  },
  createdBy: ObjectId("user1"), // Creator ID
  createdAt: Date,
  updatedAt: Date
}
```

### Key Points:
- `memberRoles` is a map/dictionary: `{ userId: role }`
- If a user's ID is not in `memberRoles`, they default to `'member'`
- `createdBy` field identifies the group creator (always has admin role)
- Roles are **group-specific** - same user can have different roles in different groups

---

## Security Considerations

### Separation of Concerns:
1. **Group Admin ≠ App Admin**
   - Group admin role is stored in `chat.memberRoles`
   - App admin role is stored in `user.role`
   - Group admins have NO access to app-wide admin features

2. **Permission Checks:**
   - All group operations check `memberRoles` for permissions
   - App admin operations check `user.role` for permissions
   - These are completely separate systems

3. **Creator Protection:**
   - Creator cannot remove themselves (prevents orphaned groups)
   - Creator's role cannot be changed (permanent admin status)
   - Creator is always identified by `createdBy` field

---

## API Endpoints

### Add Member
- **Endpoint:** `PUT /api/chats/:chatId/members`
- **Body:** `{ "userId": "...", "action": "add" }`
- **Required Role:** Group Admin or Manager
- **Code:** `servers/local_api_server/server.js` lines 1500-1524

### Remove Member
- **Endpoint:** `PUT /api/chats/:chatId/members`
- **Body:** `{ "userId": "...", "action": "remove" }`
- **Required Role:** Group Admin only
- **Code:** `servers/local_api_server/server.js` lines 1525-1545

### Change Member Role
- **Endpoint:** `PUT /api/chats/:chatId/members/:userId/role`
- **Body:** `{ "role": "member" | "manager" }`
- **Required Role:** Group Creator only
- **Code:** `servers/local_api_server/server.js` lines 1555-1607

---

## UI Features

### Group Info Dialog
- **Location:** `lib/screens/chat_screen_mongodb.dart` - `_showGroupInfo()` method
- **Access:** Click group icon in chat AppBar
- **Features:**
  - Lists all members with their roles
  - Shows role change options (for creator only)
  - Shows add member section (for admins/managers)
  - Displays role badges (Admin (Creator), Manager, Member)

---

## Examples

### Example 1: Creating a Group
1. User A creates a group "Project Team"
2. User A automatically becomes Creator/Group Admin
3. User A adds User B and User C as members
4. `memberRoles` = `{ "userA": "admin", "userB": "member", "userC": "member" }`

### Example 2: Promoting a Manager
1. Creator (User A) opens group info
2. Creator selects User B → "Make Manager"
3. `memberRoles` = `{ "userA": "admin", "userB": "manager", "userC": "member" }`
4. User B can now add members but cannot remove them

### Example 3: Adding Members
1. Group Admin (User A) or Manager (User B) opens group info
2. They see "Add Members" section
3. They select a user and click add
4. New user is added with default "member" role

---

## Notes

- All roles are **group-scoped** - they only apply within the specific group
- A user can be a group admin in one group and a regular member in another
- Group roles have **no impact** on app-wide permissions
- The creator role is **permanent** and cannot be transferred or changed
- When a member is removed, their role entry is also removed from `memberRoles`

