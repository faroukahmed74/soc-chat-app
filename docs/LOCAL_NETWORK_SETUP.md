# 🌐 Local Network Setup for SOC Chat App

This guide explains how to run your Flutter app on your local network so other devices can access it.

## 📱 **What This Does**

- Runs your Flutter web app on your local network
- Makes it accessible to other devices (phones, tablets, computers) on the same WiFi
- Automatically detects your local IP address
- Binds to all network interfaces (0.0.0.0)

## 🚀 **Quick Start**

### **Windows Users**
1. **Double-click** `run_local_network.bat` OR
2. **Right-click** → "Run as administrator" for `run_local_network.ps1`

### **macOS/Linux Users**
1. **Double-click** `run_local_network.sh` OR
2. **Terminal**: `./run_local_network.sh`

## 📋 **Prerequisites**

- Flutter SDK installed and in PATH
- Flutter web support enabled: `flutter config --enable-web`
- Your device and other devices on the same WiFi network

## 🔧 **How It Works**

1. **Detects your local IP** (e.g., 192.168.1.100)
2. **Starts Flutter web server** on port 8080
3. **Binds to all interfaces** (0.0.0.0:8080)
4. **Shows access URL** for other devices

## 🌍 **Access from Other Devices**

Once running, other devices on your network can access:
```
http://YOUR_LOCAL_IP:8080
```

**Example**: `http://192.168.1.100:8080`

## ⚠️ **Important Notes**

- **Firewall**: Windows/macOS may ask for network access permission
- **Port 8080**: Make sure this port isn't blocked by your router
- **Same Network**: All devices must be on the same WiFi network
- **Security**: This exposes your app to your local network only

## 🛠️ **Troubleshooting**

### **Port Already in Use**
```bash
# Kill process using port 8080
lsof -ti:8080 | xargs kill -9  # macOS/Linux
netstat -ano | findstr :8080   # Windows
```

### **Can't Access from Other Devices**
1. Check if devices are on same network
2. Verify firewall settings
3. Try different port: `flutter run -d web-server --web-port 8081`

### **IP Address Issues**
- Windows: Use `ipconfig` to see your IP
- macOS/Linux: Use `ifconfig` or `ip addr`

## 🔄 **Alternative Commands**

### **Manual Flutter Commands**
```bash
# Basic local network run
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

# With specific port
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000

# With hot reload enabled
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --hot
```

### **Build and Serve Static Files**
```bash
# Build for production
flutter build web

# Serve with Python (if available)
cd build/web
python3 -m http.server 8080

# Serve with Node.js (if available)
npx serve -s build/web -l 8080
```

## 📱 **Testing on Mobile**

1. **Start the script** on your computer
2. **Note the IP address** shown in the output
3. **Open browser** on your phone/tablet
4. **Navigate to**: `http://YOUR_IP:8080`
5. **Test the app** functionality

## 🎯 **Use Cases**

- **Mobile Testing**: Test responsive design on real devices
- **Team Development**: Share app with team members
- **Client Demos**: Show app to clients on their devices
- **Cross-Platform Testing**: Test on different browsers/devices

---

**Happy Testing! 🚀**
