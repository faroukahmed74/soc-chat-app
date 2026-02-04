# Firebase Service Account (for FCM Server)

Put your **Firebase Admin SDK JSON** key here for the FCM server (port 3000).

## Steps

1. Go to [Firebase Console](https://console.firebase.google.com) → Project **soc-chat-app-ca57e** → Project Settings → Service accounts
2. Click **Generate new private key**
3. Save the JSON file in this folder

## Accepted filenames

- `soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json` (exact match)
- Any file containing `firebase` and `adminsdk` in the name, e.g. `my-firebase-adminsdk-abc123.json`

## Alternative location

You can also put the file in:
- `servers/local_api_server/assets/service-account/`

**Do not commit the JSON file to git.** It contains secrets.
