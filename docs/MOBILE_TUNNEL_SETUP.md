# Mobile-only Tunnel Setup

This guide configures Android/iOS to access your local API via a public tunnel, while keeping the web app restricted to the internal network.

## Overview
- Web runs at `http://192.168.x.x:8080` and talks to `API_BASE_URL_WEB` (internal URL).
- Mobile builds use `API_BASE_URL_MOBILE` set to your tunnel URL (e.g., `https://<sub>.loca.lt`).
 - Preferred: Use ngrok for a stable HTTPS mobile tunnel (e.g., `https://<sub>.ngrok.app`).

## Steps
1. Start the local API server
   - `cd servers/local_api_server && npm install && npm start`
   - Verify it logs: `Server running on http://0.0.0.0:3003`

2. Start a tunnel (Ngrok, LocalTunnel, or Cloudflare Tunnel)
   - Ngrok (recommended):
     - Sign in at `https://dashboard.ngrok.com/get-started/setup` and copy your authtoken
     - Add token: `npx ngrok config add-authtoken <YOUR_AUTHTOKEN>`
     - Start tunnel: `npx ngrok http 3003`
     - Copy the `https://<random>.ngrok.app` URL shown in the console
     - Optional: reserve a domain in ngrok dashboard and use `npx ngrok http --domain <your-sub>.ngrok.app 3003`
   - LocalTunnel: `npx localtunnel --port 3003` (ephemeral, less reliable)
   - Cloudflare Tunnel: `cloudflared tunnel --url http://localhost:3003` (see `docs/CLOUDFLARE_TUNNEL_SETUP.md`)

3. Configure server `.env`
   - Leave `PUBLIC_BASE_URL` empty to auto-compute from each request host (works for both LAN and tunnels):
     - `PUBLIC_BASE_URL=`
   - Adjust `ALLOWED_ORIGINS` to include only internal web origins (e.g., `http://192.168.x.x:8080`). Mobile requests often have no Origin and are allowed.

4. Build mobile using dart-define
   - Android: `flutter build apk --dart-define=API_BASE_URL_MOBILE=https://<your>.ngrok.app --dart-define=USE_PHYSICAL_SERVER=true`
   - iOS: `flutter build ios --dart-define=API_BASE_URL_MOBILE=https://<your>.ngrok.app --dart-define=USE_PHYSICAL_SERVER=true`

5. Keep web internal
   - Run web pointing to internal: `flutter run -d chrome --dart-define=API_BASE_URL_WEB=http://192.168.x.x:3003 --dart-define=USE_PHYSICAL_SERVER=true`
   - Ensure network firewall restricts external access to web `:8080`.

## Windows Quick Commands
- In project root, start ngrok: `npx ngrok http 3003`
- If ngrok v3 is used, you can fetch the public URL via local API: `curl http://127.0.0.1:4040/api/tunnels`
- Copy the `https` URL and use it for `API_BASE_URL_MOBILE`

## Notes
- Mobile requests typically have no `Origin` header; server CORS is configured to allow such requests.
- For production, prefer Cloudflare Tunnel or Nginx reverse proxy with TLS and auth.
- If Android profile/debug uses HTTP on LAN, ensure `android:usesCleartextTraffic="true"` (already set). iOS is fine with ngrok HTTPS.