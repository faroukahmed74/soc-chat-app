# Failed Services Diagnosis

## Window closes when running services_manager_interactive.bat

**Fix applied:** The script now opens a new titled window that stays open. Double-click `services_manager_interactive.bat` – a window titled "SOC Chat App - Services Manager" should open and stay open. If it still closes, run it from Command Prompt: `cd E:\GitHub\soc-chat-app` then `services_manager_interactive.bat`.

---

## 4. TURN Server (coturn) – FAILED

### Cause
**Docker daemon is not running.**

The error was:
```
failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine;
check if the path is correct and if the daemon is running
```

### Fix
1. **Start Docker Desktop** (or the Docker service) before running the services manager.
2. Wait until Docker is fully started (whale icon in system tray).
3. Run option 1 again.

### Alternative
If you don't need self-hosted TURN, the app can use **Twilio Cloud TURN** (already configured in your `.env`). Calls will work without coturn.

---

## 8. FCM Server – FAILED

### Cause
**Missing Firebase Admin SDK service account JSON file.**

The FCM server needs a Firebase service account key to send push notifications. It exits immediately with:
```
Cannot find module './assets/service-account/soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'
```

### Fix

**Option A – Use a service account file:**
1. Go to [Firebase Console](https://console.firebase.google.com/) → Project **soc-chat-app-ca57e** → Project Settings → Service accounts.
2. Click **Generate new private key**.
3. Save the JSON file. Any name containing `firebase` and `adminsdk` works (e.g. `soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json`).
4. Put it in **one** of these folders (both exist):
   - `E:\GitHub\soc-chat-app\servers\assets\service-account\`
   - `E:\GitHub\soc-chat-app\servers\local_api_server\assets\service-account\`

**Option B – Use production env vars:**
1. Set `NODE_ENV=production` when starting the FCM server.
2. Add Firebase credentials to `servers/.env.production` (see `env.production.example`).

### Note
FCM is optional. The app works without it; calls will work, but background push notifications for incoming calls will not.
