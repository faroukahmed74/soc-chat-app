# 🔧 FCM Notification Setup Fix

## ❌ Current Issues Found

1. **Firebase Admin SDK NOT initialized** - Service account file is missing
2. **No FCM tokens in database** - Users need to log in to register tokens

## ✅ Step 1: Download Firebase Service Account Key

### Option A: From Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **soc-chat-app-ca57e**
3. Click the **gear icon** ⚙️ next to "Project Overview"
4. Select **"Project settings"**
5. Go to the **"Service accounts"** tab
6. Click **"Generate new private key"**
7. Click **"Generate key"** in the dialog
8. A JSON file will download (e.g., `soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json`)

### Option B: If you already have the file

If you have the service account JSON file somewhere, just copy it to the correct location.

## ✅ Step 2: Place the Service Account File

Place the downloaded JSON file in one of these locations:

**Preferred location:**
```
servers/assets/service-account/soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json
```

**Alternative locations (also checked by server):**
- `servers/assets/service-account/soc-chat-app-ca57e-bc21fed17ba4.json`
- `servers/local_api_server/assets/service-account/soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json`
- `servers/local_api_server/assets/service-account/soc-chat-app-ca57e-bc21fed17ba4.json`

### Quick Command (Windows PowerShell):

```powershell
# Create directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "servers\assets\service-account"

# Copy your downloaded file here (replace with actual filename)
# Copy-Item "C:\Users\YourName\Downloads\soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json" -Destination "servers\assets\service-account\"
```

## ✅ Step 3: Verify Setup

Run the diagnostic script to verify everything is working:

```bash
cd servers/local_api_server
node diagnose_fcm.js
```

You should see:
- ✅ Firebase Admin SDK initialized successfully
- ✅ MongoDB connected successfully
- ✅ FCM tokens in DB (after users log in)

## ✅ Step 4: Restart Your Server

After placing the service account file, restart your server:

```bash
# Stop the current server (Ctrl+C)
# Then restart:
cd servers/local_api_server
node server.js
```

You should now see in the logs:
```
✅ Firebase Admin SDK initialized successfully
```

## ✅ Step 5: Register FCM Tokens

FCM tokens are automatically registered when users log in to your app. Make sure:

1. **Users are logged in** to the app
2. **App can reach the server** at `/api/users/fcm-token`
3. **FCM service is initialized** in the app (should happen automatically)

### Check if tokens are being registered:

Run the diagnostic again after users log in:
```bash
cd servers/local_api_server
node diagnose_fcm.js
```

You should see users with FCM tokens listed.

## 🔍 Troubleshooting

### Issue: "Service account file not found"

**Solution:**
- Make sure the file is in one of the paths listed above
- Check the filename matches (case-sensitive)
- Verify the file is a valid JSON file

### Issue: "No FCM tokens in database"

**Solutions:**
1. **Check app connectivity:**
   - Verify the app can reach your server
   - Check server logs for `/api/users/fcm-token` requests
   - Look for errors in app logs

2. **Check FCM initialization in app:**
   - The app should automatically initialize FCM on startup
   - Check app logs for FCM-related errors

3. **Test token registration manually:**
   - Log in to the app
   - Check server logs for POST requests to `/api/users/fcm-token`
   - Run diagnostic: `node diagnose_fcm.js`

### Issue: "Firebase Admin SDK initialized but notifications not sending"

**Check:**
1. Are FCM tokens in the database? (run diagnostic)
2. Are users offline when messages are sent?
3. Check server logs when sending messages - you should see:
   ```
   📱 User {userId} is offline, sending FCM notification
   ✅ FCM notification sent to user {userId}
   ```

### Issue: "Invalid FCM token" errors

**Solution:**
- Tokens expire or become invalid when:
  - App is uninstalled
  - App data is cleared
  - Token is refreshed
- The server automatically removes invalid tokens
- Users need to log in again to register new tokens

## 📋 Quick Checklist

- [ ] Firebase service account JSON file downloaded
- [ ] File placed in `servers/assets/service-account/` directory
- [ ] Server restarted after placing the file
- [ ] Server logs show "✅ Firebase Admin SDK initialized successfully"
- [ ] Users have logged in to the app
- [ ] Diagnostic shows FCM tokens in database
- [ ] Test notification sent successfully (via diagnostic)

## 🧪 Test FCM Notifications

After setup is complete, you can test notifications:

1. **Via diagnostic script:**
   ```bash
   cd servers/local_api_server
   node diagnose_fcm.js
   ```
   The script will automatically test sending a notification if tokens are found.

2. **Via sending a message:**
   - Have two users logged in
   - Send a message from one user to another
   - The recipient should receive a push notification
   - Check server logs for FCM sending attempts

## 📞 Need More Help?

If you're still having issues:

1. **Check server logs** when:
   - Server starts (look for Firebase initialization)
   - Users log in (look for FCM token registration)
   - Messages are sent (look for FCM notification attempts)

2. **Run diagnostic regularly:**
   ```bash
   node servers/local_api_server/diagnose_fcm.js
   ```

3. **Check app logs** for FCM-related errors

4. **Verify Firebase project settings:**
   - Cloud Messaging API is enabled
   - Service account has proper permissions

