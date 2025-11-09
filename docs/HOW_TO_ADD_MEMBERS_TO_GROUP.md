# How to Add New Members to a Group

This guide explains how to add new members to an existing group in the SOC Chat App.

## Prerequisites

**Who can add members?**
- ✅ **Group Creator/Admin** - Can add members
- ✅ **Group Manager** - Can add members
- ❌ **Regular Members** - Cannot add members

## Step-by-Step Instructions

### Step 1: Open the Group Chat
1. Navigate to the group chat you want to add members to
2. Make sure you're in the chat screen (where you can see messages)

### Step 2: Access Group Info
1. Look at the **top AppBar** of the chat screen
2. Find the **group icon** (👥) on the right side of the AppBar
3. **Tap/Click** on the group icon

### Step 3: View Group Information Dialog
1. A dialog will open showing:
   - Group name at the top
   - List of current members with their roles
   - **"Add Members"** section (only visible if you're an admin or manager)

### Step 4: Add a Member
1. Scroll down to the **"Add Members"** section
2. You'll see a list of users who are **not** currently in the group
3. Find the user you want to add
4. **Tap/Click** the green **➕ (add circle)** icon next to their name
5. Wait for the confirmation message: **"Member added successfully"**

### Step 5: Verify
1. The dialog will automatically refresh
2. The newly added member will now appear in the **Members** list at the top
3. They will have the **"Member"** role by default

## Visual Guide

```
┌─────────────────────────────────────┐
│  Group Chat Screen                  │
│  ┌───────────────────────────────┐  │
│  │ Group Name          [👥]      │  │ ← Tap here
│  └───────────────────────────────┘  │
│                                      │
│  [Messages...]                       │
└─────────────────────────────────────┘

         ↓ Opens ↓

┌─────────────────────────────────────┐
│  Group Info: [Group Name]           │
│                                      │
│  Members                             │
│  ┌───────────────────────────────┐  │
│  │ 👤 User 1    [Admin (Creator)]│  │
│  │ 👤 User 2    [Manager]        │  │
│  │ 👤 User 3    [Member]         │  │
│  └───────────────────────────────┘  │
│                                      │
│  Add Members                         │
│  ┌───────────────────────────────┐  │
│  │ 👤 New User 1        [➕]     │  │ ← Tap to add
│  │ 👤 New User 2        [➕]     │  │
│  │ 👤 New User 3        [➕]     │  │
│  └───────────────────────────────┘  │
│                                      │
│                    [Close]           │
└─────────────────────────────────────┘
```

## Important Notes

### Permissions
- **Group Admins** and **Managers** can see the "Add Members" section
- **Regular Members** will NOT see the "Add Members" section
- If you don't see the section, you don't have permission to add members

### What Happens When You Add a Member?
1. The user is added to the group's member list
2. They receive a default **"Member"** role
3. They can immediately see and participate in group messages
4. They appear in the group info dialog for all members

### Limitations
- You can only add users who are **not already members**
- Users who are already in the group won't appear in the "Add Members" list
- If there are no available users, you'll see: **"No users available to add"**

## Troubleshooting

### "Add Members" section is not visible
**Possible reasons:**
- You're not a group admin or manager
- You're a regular member (only admins/managers can add members)
- Check your role in the members list at the top

### "No users available to add"
**Possible reasons:**
- All registered users are already members of the group
- There are no other users in the system

### Error message appears
**If you see an error:**
- Check your internet connection
- Make sure the server is running
- Verify you have the correct permissions
- Try again after a few seconds

## Code Reference

- **UI Location**: `lib/screens/chat_screen_mongodb.dart` - `_showGroupInfo()` method
- **Backend API**: `PUT /api/chats/:chatId/members` with `action: "add"`
- **Permission Check**: Lines 1155-1156, 1297 in `chat_screen_mongodb.dart`

## Quick Reference

| Action | Who Can Do It | Location |
|--------|---------------|----------|
| Add Members | Group Admin, Manager | Group Info Dialog → Add Members Section |
| Remove Members | Group Admin only | Group Info Dialog (not shown in this guide) |
| Change Roles | Group Creator only | Group Info Dialog → Member Menu |

---

**Need to remove a member?** Only group admins can remove members. Look for the member in the members list and use the remove option (if available).

**Want to change someone's role?** Only the group creator can change roles. Tap the menu (⋮) next to a member's name to promote them to Manager or demote to Member.

