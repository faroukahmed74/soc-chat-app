# 🚀 Quick FCM Fix - What You Need to Do

## ❌ Problem Found

Your FCM notifications aren't working because:
1. **Firebase service account file is missing** - Server can't initialize Firebase Admin SDK
2. **No FCM tokens registered yet** - Users need to log in first

## ✅ Solution (3 Steps)

### Step 1: Download Firebase Service Account Key

1. Go to: https://console.firebase.google.com/
2. Select project: **soc-chat-app-ca57e**
3. Click ⚙️ → **Project settings** → **Service accounts** tab
4. Click **"Generate new private key"** → **"Generate key"**
5. Save the downloaded JSON file

### Step 2: Place the File

Copy the downloaded JSON file to:
```
servers/assets/service-account/soc-chat-app-ca57e-bc21fed17ba4.json
```

**OR** rename your downloaded file to match one of these names:
- `soc-chat-app-ca57e-bc21fed17ba4.json`
- `soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json`

### Step 3: Restart Server

```bash
# Stop current server (Ctrl+C)
cd servers/local_api_server
node server.js
```

You should see: `✅ Firebase Admin SDK initialized successfully`

## ✅ Verify It Works

Run this diagnostic:
```bash
cd servers/local_api_server
node diagnose_fcm.js
```

## 📱 After Fix: Register FCM Tokens

Once the server is running with Firebase initialized:
1. Have users **log in to the app**
2. The app will automatically register FCM tokens
3. Check with diagnostic: `node diagnose_fcm.js`

## 🧪 Test Notifications

After users log in and tokens are registered:
1. Send a message from one user to another
2. The recipient should receive a push notification
3. Check server logs for FCM sending messages

---

**That's it!** Once you place the Firebase service account file and restart the server, FCM will work for all platforms (Android, iOS, Web).

