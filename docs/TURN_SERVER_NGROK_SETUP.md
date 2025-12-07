# TURN Server Configuration for ngrok + Local Network

## Current Setup

- **Web Clients**: Use local network IP `10.120.4.230` via proxy
- **Mobile Clients**: Use ngrok URL `https://soc-chat-app.ngrok-free.app`

## TURN Server Configuration

### ✅ Web Clients (Local Network)
- **TURN Server IP**: `10.120.4.230:3478`
- **Status**: ✅ Working - Web clients can reach TURN server directly

### ⚠️ Mobile Clients (ngrok)
- **Issue**: Mobile devices connect via ngrok, but TURN server is on local IP
- **Problem**: Mobile devices cannot reach `10.120.4.230:3478` directly
- **Solution Options**:

#### Option 1: Expose TURN Server Through ngrok (Recommended)
Create a separate ngrok tunnel for TURN server:

```bash
# In a new terminal, create TURN tunnel
ngrok tcp 3478
```

This will give you a URL like: `tcp://0.tcp.ngrok.io:12345`

Then update mobile TURN config to use this ngrok tunnel.

#### Option 2: Use Local IP When on Same Network
Detect if mobile device is on same network and use local IP, otherwise skip TURN.

#### Option 3: Use Cloud TURN Service for Mobile
Use Twilio or other cloud TURN service for mobile clients, self-hosted for web.

## Current Implementation

The app is configured to:
- **Web**: Use `10.120.4.230:3478` (local network IP)
- **Mobile**: Try to use ngrok hostname, but this won't work without ngrok tunnel

## Next Steps

1. **For immediate testing**: Web clients will have TURN support
2. **For mobile**: Either:
   - Create ngrok tunnel for TURN server (port 3478)
   - Or accept that mobile will use STUN only (works for most cases)

## Testing

- **Web**: Test calls between web clients - TURN should work
- **Mobile**: Test calls - may fall back to STUN if TURN unreachable

