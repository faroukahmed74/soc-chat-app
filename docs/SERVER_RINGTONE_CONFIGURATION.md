# Server-Side Ringtone Configuration

## ✅ Required Server-Side Updates

The ringtone feature requires server-side configuration to:
1. Store user ringtone preferences in the database
2. Use custom ringtones in FCM notifications for calls
3. Provide API endpoints for ringtone management

---

## 📋 Server Configuration Checklist

### 1. **Database Schema**
Add the following fields to the `users` collection:

```javascript
{
  customRingtone: String,      // Ringtone name/identifier
  customRingtoneUrl: String,   // Original download URL (optional)
}
```

### 2. **FCM Notification Enhancement**
Update the `sendFCMNotification()` function in your main server file to:

```javascript
// Get user's ringtone preference (if stored on server)
const isCallNotification = data.type === 'call_invitation';
const customRingtone = user.customRingtone || null;
const soundName = isCallNotification && customRingtone 
  ? customRingtone 
  : 'default';

// In the FCM message:
data: {
  ...data,
  sound: soundName,
  customRingtone: customRingtone || 'default',
},
android: {
  notification: {
    channelId: isCallNotification ? 'call_notifications' : 'chat_notifications',
    sound: soundName !== 'default' ? soundName : undefined,
    defaultSound: soundName === 'default',
    color: isCallNotification ? '#4CAF50' : '#2196F3',
  },
},
apns: {
  payload: {
    aps: {
      sound: soundName !== 'default' ? `${soundName}.caf` : 'default',
      category: isCallNotification ? 'call_invitation' : 'default',
    },
  },
},
```

### 3. **API Endpoints**
Add these endpoints to your main server file:

#### **PUT /api/users/ringtone** - Update ringtone preference
```javascript
app.put('/api/users/ringtone', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { ringtoneName, ringtoneUrl } = req.body;

    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const updateData = {};
    if (ringtoneName !== undefined) {
      updateData.customRingtone = ringtoneName;
    }
    if (ringtoneUrl !== undefined) {
      updateData.customRingtoneUrl = ringtoneUrl;
    }

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ error: 'No ringtone data provided' });
    }

    updateData.updatedAt = new Date();

    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: updateData }
    );

    console.log(`✅ Updated ringtone preference for user ${userId}: ${ringtoneName || 'default'}`);

    return res.status(200).json({
      success: true,
      message: 'Ringtone preference updated',
      ringtoneName: ringtoneName || null,
      ringtoneUrl: ringtoneUrl || null,
    });
  } catch (error) {
    console.error('❌ Error updating ringtone preference:', error);
    return res.status(500).json({ error: 'Failed to update ringtone preference' });
  }
});
```

#### **GET /api/users/ringtone** - Get ringtone preference
```javascript
app.get('/api/users/ringtone', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const user = await db.collection('users').findOne(
      { _id: new ObjectId(userId) },
      { projection: { customRingtone: 1, customRingtoneUrl: 1 } }
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.status(200).json({
      success: true,
      ringtoneName: user.customRingtone || null,
      ringtoneUrl: user.customRingtoneUrl || null,
    });
  } catch (error) {
    console.error('❌ Error getting ringtone preference:', error);
    return res.status(500).json({ error: 'Failed to get ringtone preference' });
  }
});
```

---

## 🔧 Implementation Steps

1. **Locate your main server file** (usually `servers/local_api_server/server.js`)
2. **Find the `sendFCMNotification()` function** (around line 647-755)
3. **Update the function** to read `user.customRingtone` and use it for call notifications
4. **Add the two API endpoints** above (PUT and GET `/api/users/ringtone`)
5. **Test the endpoints** using the client-side ringtone service

---

## 📝 Notes

- **Client-side ringtones** are stored locally on the device
- **Server-side preferences** are optional but enable:
  - FCM notifications with custom sounds
  - Cross-device ringtone sync (future feature)
  - Server-side ringtone management

- **FCM Sound Names**:
  - Android: Must match a sound file in `res/raw/` or system sounds
  - iOS: Must match a sound file in the app bundle (`.caf` format)

- **Current Implementation**:
  - Client-side ringtones work independently
  - Server-side sync is optional enhancement
  - FCM notifications will use custom sounds if server is configured

---

## ✅ Verification

After implementing, verify:

1. **Database**: Check that `customRingtone` field is saved in user documents
2. **FCM**: Check that call notifications include custom sound in payload
3. **API**: Test PUT and GET endpoints with authentication
4. **Logs**: Check server logs for ringtone preference updates

---

*Last Updated: 2025-01-XX*

