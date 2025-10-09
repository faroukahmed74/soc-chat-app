# Cloudflare Tunnel Setup for SOC Chat API (Windows)

This guide secures public HTTPS access to your local API server without exposing MongoDB.

## Prerequisites
- A free Cloudflare account
- A domain added to Cloudflare (e.g., `yourdomain.com`)
- Windows host running the API on `http://localhost:3000` and MongoDB bound to `127.0.0.1`

## Steps

1. Install Cloudflare Tunnel (cloudflared)
   - Download from: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
   - Install and ensure `cloudflared.exe` is on PATH

2. Authenticate cloudflared
   - Run: `cloudflared tunnel login`
   - Select your domain when prompted

3. Create a tunnel
   - `cloudflared tunnel create soc-chat-api`
   - This prints a Tunnel UUID and stores credentials locally

4. Create a config file
   - Create `%USERPROFILE%\\.cloudflared\\config.yml` with:
```
tunnel: soc-chat-api
credentials-file: C:\\Users\\<YourUser>\\.cloudflared\\<TunnelUUID>.json

ingress:
  - hostname: api.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

5. Create DNS route
   - `cloudflared tunnel route dns soc-chat-api api.yourdomain.com`

6. Run the tunnel
   - `cloudflared tunnel run soc-chat-api`
   - Verify the public URL `https://api.yourdomain.com` resolves and proxies to your local API

## API Server Configuration
- Set `HOST=0.0.0.0` and `PORT=3000` in your API env
- Set `ALLOWED_ORIGINS` to allowed web origins (e.g., `http://192.168.1.10:8080,https://api.yourdomain.com`)
- Bind MongoDB to `127.0.0.1` and require auth; do not expose MongoDB

## Flutter Client Configuration
- Use build-time `dart-define` to set `API_BASE_URL`
  - Web (LAN): `http://<LAN_IP>:3000`
  - Mobile (global): `https://api.yourdomain.com`

## Notes
- Consider Cloudflare Access to protect admin routes
- Enforce JWT auth and rate limiting on the API
- Rotate JWT secrets and restrict CORS origins