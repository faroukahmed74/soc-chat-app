# Firebase Service Account (optional)

For **FCM push notifications** from the API server, put your Firebase Admin SDK JSON key here.

1. Go to [Firebase Console](https://console.firebase.google.com) → your project → Project Settings → Service accounts.
2. Generate a new private key (JSON).
3. Save the file here, e.g. `soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json`.

The API server looks for Firebase Admin SDK JSON in:
- `local_api_server/assets/service-account/` (this folder)
- `local_api_server/assets/` (parent folder)

Place your `*-firebase-adminsdk-*.json` file in either location. Any `.json` whose filename contains "firebase" or "adminsdk" will be auto-detected.

**Do not commit the JSON file to git.** Add `*.json` to `.gitignore` in this folder if needed.

Alternatively, set **FIREBASE_*** variables in `servers/local_api_server/.env` instead of using a file.
