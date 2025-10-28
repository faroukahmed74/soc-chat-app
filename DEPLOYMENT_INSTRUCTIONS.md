# Deployment Instructions for Main PC Server

## Steps to Deploy the Fix:

### 1. Pull Latest Code
```bash
git pull origin main
```

### 2. Verify the Build Has the Fix
```bash
grep "canvasKitBaseUrl" build/web/index.html
# Should show: _flutter.buildConfig.canvasKitBaseUrl = './canvaskit/';
```

### 3. If build/web/index.html is NOT present or outdated:
```bash
flutter build web --release
```

### 4. Restart All Services
```bash
services_manager_interactive.bat
# Choose option 3 (Restart All Services)
```

### 5. Test from Local Network PC
- Access: `http://160.2.1.18:8082`
- Should load without CanvasKit errors
- Check console (F12) - no ERR_NAME_NOT_RESOLVED for CanvasKit

## Important Notes:

1. **Browser Cache:** The remote PC may be caching the old version. Clear cache:
   - Press Ctrl+Shift+Del
   - Select "Cached images and files" 
   - Time range: "All time"
   - Click "Clear data"
   - Refresh the page

2. **Hard Refresh:** 
   - Press Ctrl+F5 (hard refresh)
   - OR right-click refresh button → "Empty Cache and Hard Reload"

3. **Verify Files Are Being Served:**
   - Try to access: `http://160.2.1.18:8082/canvaskit/canvaskit.js`
   - Should download the file (not show error or loading screen)

## If Still Not Working:

Check if CanvasKit files exist:
```bash
ls -lh build/web/canvaskit/
# Should show canvaskit.js, canvaskit.wasm, etc.
```

If files are missing, download them:
```bash
bash servers/download_canvaskit.sh
```

