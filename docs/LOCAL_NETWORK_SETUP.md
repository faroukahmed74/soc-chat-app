# 🌐 Local Network Setup for SOC Chat App

This guide explains how to run your Flutter app on your local network so other devices can access it.

## 📱 **What This Does**

- Runs your Flutter web app on your local network
- Makes it accessible to other devices (phones, tablets, computers) on the same WiFi
- Automatically detects your local IP address
- Binds to all network interfaces (0.0.0.0)
- **Configured for local network IP: 10.120.4.230:8082**

## 🚀 **Quick Start**

### **Windows Users**
1. **Double-click** `run_local_network.bat` OR
2. **Right-click** → "Run as administrator" for `run_local_network.ps1`

### **macOS/Linux Users**
1. **Double-click** `run_local_network.sh` OR
2. **Terminal**: `./run_local_network.sh`

### **Build Responsive Web App**
```bash
./build_responsive_web.sh
```

## 📋 **Prerequisites**

- Flutter SDK installed and in PATH
- Flutter web support enabled: `flutter config --enable-web`
- Your device and other devices on the same WiFi network
- Local network access to 10.120.4.230:8082

## 🔧 **How It Works**

1. **Detects your local IP** (e.g., 10.120.4.230)
2. **Starts Flutter web server** on port 8082
3. **Binds to all interfaces** (0.0.0.0:8082)
4. **Shows access URL** for other devices
5. **Enables responsive features** for all screen sizes

## 🌍 **Access from Other Devices**

Once running, other devices on your network can access:
```
http://10.120.4.230:8082
```

**Alternative URLs**:
- `http://localhost:8082` (local access)
- `http://127.0.0.1:8082` (local access)

## 📱 **Responsive Features**

### **Mobile (< 600px)**
- Touch-friendly interface
- Bottom navigation
- Optimized for phones
- Swipe gestures

### **Tablet (600px - 900px)**
- Two-column layouts
- Larger touch targets
- Optimized for tablets
- Side navigation

### **Desktop (> 900px)**
- Multi-column layouts
- Hover effects
- Keyboard shortcuts
- Full feature access

## ⚠️ **Important Notes**

- **Firewall**: Windows/macOS may ask for network access permission
- **Port 8082**: Make sure this port isn't blocked by your router
- **Same Network**: All devices must be on the same WiFi network
- **Security**: This exposes your app to your local network only
- **Responsive**: All features work on mobile, tablet, and desktop

## 🛠️ **Troubleshooting**

### **Port Already in Use**
```bash
# Kill process using port 8082
lsof -ti:8082 | xargs kill -9  # macOS/Linux
netstat -ano | findstr :8082   # Windows
```

### **Can't Access from Other Devices**
1. Check if devices are on same network
2. Verify firewall settings
3. Try different port: `flutter run -d web-server --web-port 8083`
4. Test with: `./test_local_network.sh`

### **IP Address Issues**
- Windows: Use `ipconfig` to see your IP
- macOS/Linux: Use `ifconfig` or `ip addr`
- Default configured for: 10.120.4.230

## 🔄 **Alternative Commands**

### **Manual Flutter Commands**
```bash
# Basic local network run
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8082

# With specific port
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000

# With hot reload enabled
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8082 --hot
```

### **Build and Serve Static Files**
```bash
# Build for production
flutter build web

# Serve with Python (if available)
cd build/web
python3 -m http.server 8082

# Serve with Node.js (if available)
npx serve -s build/web -l 8082
```

## 📱 **Testing on Mobile**

1. **Start the script** on your computer
2. **Note the IP address** shown in the output (10.120.4.230)
3. **Open browser** on your phone/tablet
4. **Navigate to**: `http://10.120.4.230:8082`
5. **Test the app** functionality
6. **Verify responsive features** work properly

## 🎯 **Use Cases**

- **Mobile Testing**: Test responsive design on real devices
- **Team Development**: Share app with team members
- **Client Demos**: Show app to clients on their devices
- **Cross-Platform Testing**: Test on different browsers/devices
- **Local Network Access**: Access from any device on the network

## 🔧 **Features Available**

### **Core Features**
- ✅ User authentication
- ✅ Real-time messaging
- ✅ Group chats
- ✅ Media uploads
- ✅ Notifications
- ✅ Admin panel

### **Responsive Features**
- ✅ Mobile-optimized UI
- ✅ Tablet-friendly layout
- ✅ Desktop-optimized design
- ✅ Touch-friendly controls
- ✅ Adaptive media handling
- ✅ Responsive modals
- ✅ Responsive navigation

---

**Happy Testing! 🚀**
