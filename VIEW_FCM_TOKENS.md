# 📱 How to View FCM Token Details

## Quick View

Run this command to see all FCM tokens with detailed information:

```bash
node servers/local_api_server/show_fcm_tokens.js
```

This will show:
- User IDs
- Email addresses
- Display names
- Full FCM tokens
- Platform (iOS/Android/Web)
- Token update timestamps
- Token age and status (active/stale)
- Token validation status

## Query Options

For more specific queries, use the query script:

```bash
# Show all tokens
node servers/local_api_server/query_fcm_tokens.js

# Show only iOS tokens
node servers/local_api_server/query_fcm_tokens.js --platform=ios

# Show only Android tokens
node servers/local_api_server/query_fcm_tokens.js --platform=android

# Show only Web tokens
node servers/local_api_server/query_fcm_tokens.js --platform=web

# Show only active tokens (updated in last 5 minutes)
node servers/local_api_server/query_fcm_tokens.js --active

# Export tokens to JSON file
node servers/local_api_server/query_fcm_tokens.js --export

# Show all users (including those without tokens)
node servers/local_api_server/query_fcm_tokens.js --all
```

## Direct MongoDB Query

You can also query MongoDB directly:

```javascript
// Connect to MongoDB
use soc-chat-app

// Find all users with FCM tokens
db.users.find({ fcmToken: { $exists: true, $ne: "" } })

// Find tokens by platform
db.users.find({ fcmPlatform: "ios" })
db.users.find({ fcmPlatform: "android" })
db.users.find({ fcmPlatform: "web" })

// Find active tokens (updated in last 5 minutes)
db.users.find({
  fcmToken: { $exists: true, $ne: "" },
  fcmTokenUpdatedAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }
})

// Count tokens by platform
db.users.aggregate([
  { $match: { fcmToken: { $exists: true, $ne: "" } } },
  { $group: { _id: "$fcmPlatform", count: { $sum: 1 } } }
])
```

## What the Output Shows

### Token Status
- 🟢 **Active**: Token updated in last 5 minutes (user likely online)
- 🟡 **Stale**: Token older than 5 minutes (user may be offline)

### Token Information
- **Full Token**: Complete FCM token string
- **Token Length**: Character count (typically 150+ characters)
- **Platform**: iOS, Android, or Web
- **Last Updated**: When the token was last refreshed

## Example Output

```
📱 FCM Token Details Viewer

================================================================================
✅ Connected to MongoDB

📊 Found 3 user(s) with FCM tokens:

👤 User #1
--------------------------------------------------------------------------------
   User ID:        507f1f77bcf86cd799439011
   Email:          user@example.com
   Display Name:   John Doe
   Platform:       ios
   Token Updated:  1/15/2025, 2:30:45 PM
   Full Token:     dKx8Yz9aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890...
   Token Length:   163 characters
   Token Preview:  dKx8Yz9aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890...
   Token Age:      2 minutes
   Status:         🟢 Active (recent)
   Token Format:   ✅ Valid format
   Validation:     ✅ Appears valid (format check)
```

## Troubleshooting

### No tokens found?
1. Make sure users have logged in to the app
2. Check if FCM service is initialized in the app
3. Verify server is receiving token registration requests

### Want to see specific user's token?
```bash
# Use MongoDB query
db.users.findOne({ email: "user@example.com" }, { fcmToken: 1, fcmPlatform: 1, fcmTokenUpdatedAt: 1 })
```

### Export tokens for backup?
```bash
node servers/local_api_server/query_fcm_tokens.js --export
```

This creates a JSON file with all token details.

