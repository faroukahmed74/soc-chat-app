# DNS Fix for Loading Screen Issue

## Problem
The browser cannot resolve DNS for Google's CDN (`gstatic.com`), causing Flutter web app to be stuck on loading screen.

## Symptoms
- Persistent loading screen
- Console errors: `ERR_NAME_NOT_RESOLVED` for `fonts.gstatic.com`
- Console errors: `ERR_NAME_NOT_RESOLVED` for `www.gstatic.com`
- `Failed to download CanvasKit`

## Root Cause
The client PC's DNS server cannot resolve external domains like Google's CDN.

## Solution Options

### Option 1: Fix DNS (Recommended)
On the PC that can't load the app:

1. **Windows:**
   - Open Control Panel → Network and Sharing Center
   - Click your network connection
   - Click "Properties"
   - Select "Internet Protocol Version 4 (TCP/IPv4)"
   - Click "Properties"
   - Select "Use the following DNS server addresses:"
   - Enter: `8.8.8.8` (primary) and `8.8.4.4` (secondary)
   - Click OK and restart browser

2. **Or via Command Line:**
   ```cmd
   netsh interface ip set dns "Wi-Fi" static 8.8.8.8
   netsh interface ip add dns "Wi-Fi" 8.8.4.4 index=2
   ```

### Option 2: Use Working IP
Access the app via the working IP:
- Use: `http://10.120.4.230:8082` (the one that works)
- `http://160.2.1.18:8082` has DNS issues

### Option 3: Check Network Settings
The PC might be on a restricted network:
- Contact network administrator
- Check firewall settings
- Verify internet connectivity

### Option 4: Temporary Workaround
Install a different browser or try:
- Chrome
- Edge
- Firefox (as alternatives)

## Testing
After fixing DNS:
1. Clear browser cache (Ctrl+Shift+Del)
2. Restart browser
3. Access `http://160.2.1.18:8082`
4. Check console (F12) - should see no DNS errors

## Verification
In browser console (F12), you should see:
- No `ERR_NAME_NOT_RESOLVED` errors
- CanvasKit downloads successfully
- App loads past the loading screen

