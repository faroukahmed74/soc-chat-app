# 🔧 SOC Chat App - Troubleshooting Guide

This comprehensive troubleshooting guide helps you diagnose and resolve common issues with the SOC Chat App.

## 📋 **Table of Contents**

1. [Quick Diagnostics](#quick-diagnostics)
2. [Server Issues](#server-issues)
3. [Database Issues](#database-issues)
4. [Mobile App Issues](#mobile-app-issues)
5. [Network Issues](#network-issues)
6. [Authentication Issues](#authentication-issues)
7. [Performance Issues](#performance-issues)
8. [Security Issues](#security-issues)
9. [ngrok Issues](#ngrok-issues)
10. [Emergency Procedures](#emergency-procedures)

## 🚨 **Quick Diagnostics**

### **Health Check Commands**
```bash
# Check server health
curl http://localhost:3003/health

# Check MongoDB status
curl http://localhost:3003/api/status/mongodb

# Check ngrok tunnel
curl http://localhost:4040/api/tunnels

# Check PM2 processes
pm2 status

# Check system resources
htop
```

### **Common Error Patterns**
- **Connection Refused**: Server not running or wrong port
- **CORS Error**: Origin not allowed or CORS misconfigured
- **Authentication Failed**: Invalid credentials or token expired
- **Database Error**: MongoDB connection issues
- **Permission Denied**: Mobile app permissions not granted

## 🖥️ **Server Issues**

### **Server Won't Start**

#### **Issue**: Port already in use
```bash
# Check what's using the port
sudo lsof -i :3003
sudo netstat -tulpn | grep :3003

# Kill process using the port
sudo kill -9 <PID>

# Or use different port
export PORT=3004
npm start
```

#### **Issue**: MongoDB connection failed
```bash
# Check MongoDB status
sudo systemctl status mongod

# Check MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Test MongoDB connection
mongosh "mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin"

# Restart MongoDB
sudo systemctl restart mongod
```

#### **Issue**: Environment variables missing
```bash
# Check environment file
ls -la servers/local_api_server/.env

# Copy example file
cp servers/env.example servers/local_api_server/.env

# Edit environment file
nano servers/local_api_server/.env
```

### **Server Crashes**

#### **Issue**: Out of memory
```bash
# Check memory usage
free -h
pm2 monit

# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"
pm2 restart soc-chat-api
```

#### **Issue**: Unhandled exceptions
```bash
# Check PM2 logs
pm2 logs soc-chat-api --lines 100

# Check for unhandled promise rejections
# Add to server.js:
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});
```

### **Server Performance Issues**

#### **Issue**: High CPU usage
```bash
# Check CPU usage
top -p $(pgrep node)

# Check for memory leaks
pm2 monit

# Restart application
pm2 restart soc-chat-api
```

#### **Issue**: Slow response times
```bash
# Check database indexes
cd servers/local_api_server
npm run db:indexes:list

# Check MongoDB slow queries
mongosh --eval "db.setProfilingLevel(2, {slowms: 100})"

# Check network latency
ping your-ngrok-url.ngrok.app
```

## 🗄️ **Database Issues**

### **MongoDB Connection Problems**

#### **Issue**: Authentication failed
```bash
# Check MongoDB users
mongosh --eval "use admin; db.getUsers()"

# Create admin user
mongosh --eval "
use admin;
db.createUser({
  user: 'admin',
  pwd: 'SecurePassword123!',
  roles: [{role: 'userAdminAnyDatabase', db: 'admin'}]
});
"

# Create app user
mongosh --eval "
use soc_chat_app;
db.createUser({
  user: 'socchat',
  pwd: 'SecurePassword123!',
  roles: [{role: 'readWrite', db: 'soc_chat_app'}]
});
"
```

#### **Issue**: Database not found
```bash
# Check databases
mongosh --eval "show dbs"

# Create database
mongosh --eval "use soc_chat_app; db.createCollection('users')"
```

#### **Issue**: Index creation failed
```bash
# Check existing indexes
cd servers/local_api_server
npm run db:indexes:list

# Drop and recreate indexes
npm run db:indexes:drop
npm run db:indexes
```

### **Database Performance Issues**

#### **Issue**: Slow queries
```bash
# Enable query profiling
mongosh --eval "db.setProfilingLevel(2, {slowms: 100})"

# Check slow queries
mongosh --eval "db.system.profile.find().sort({ts: -1}).limit(5)"

# Create missing indexes
npm run db:indexes
```

#### **Issue**: High memory usage
```bash
# Check MongoDB memory usage
mongosh --eval "db.serverStatus().mem"

# Check database stats
mongosh --eval "db.stats()"

# Optimize database
mongosh --eval "db.runCommand({compact: 'collection_name'})"
```

## 📱 **Mobile App Issues**

### **Android Issues**

#### **Issue**: "Cleartext HTTP traffic not permitted"
```xml
<!-- Check AndroidManifest.xml -->
<application
    android:usesCleartextTraffic="true">
```
```bash
# Rebuild app
flutter clean
flutter build apk --dart-define=API_BASE_URL_MOBILE=https://your-ngrok-url.ngrok.app
```

#### **Issue**: Permission denied errors
```bash
# Check permissions
adb shell pm list permissions -d -g | grep socchat

# Grant permissions manually
adb shell pm grant com.faroukahmed74.socchatapp android.permission.CAMERA
adb shell pm grant com.faroukahmed74.socchatapp android.permission.RECORD_AUDIO
adb shell pm grant com.faroukahmed74.socchatapp android.permission.READ_EXTERNAL_STORAGE
```

#### **Issue**: App crashes on launch
```bash
# Check logs
adb logcat | grep flutter

# Check for native crashes
adb logcat | grep -i crash

# Rebuild with debug info
flutter build apk --debug
```

### **iOS Issues**

#### **Issue**: ATS blocking HTTP requests
```xml
<!-- Check Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

#### **Issue**: Permission not requested
```bash
# Check Info.plist permissions
grep -A 1 "UsageDescription" ios/Runner/Info.plist

# Rebuild app
flutter clean
flutter build ios --dart-define=API_BASE_URL_MOBILE=https://your-ngrok-url.ngrok.app
```

#### **Issue**: Background notifications not working
```xml
<!-- Check Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-processing</string>
</array>
```

### **Cross-Platform Issues**

#### **Issue**: API calls failing
```bash
# Test API connectivity
curl -X GET https://your-ngrok-url.ngrok.app/health

# Check CORS headers
curl -H "Origin: https://your-ngrok-url.ngrok.app" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS https://your-ngrok-url.ngrok.app/health
```

#### **Issue**: Real-time messaging not working
```bash
# Test WebSocket connection
wscat -c wss://your-ngrok-url.ngrok.app/socket.io/?EIO=4&transport=websocket

# Check Socket.IO logs
pm2 logs soc-chat-api | grep socket
```

## 🌐 **Network Issues**

### **ngrok Issues**

#### **Issue**: ngrok tunnel not accessible
```bash
# Check ngrok status
curl http://localhost:4040/api/tunnels

# Restart ngrok
pkill ngrok
./build-scripts/start_ngrok.sh -p 3003

# Check ngrok authentication
ngrok config check
```

#### **Issue**: ngrok URL changes frequently
```bash
# Use reserved domain (paid ngrok)
ngrok http --domain=your-reserved-domain.ngrok.app 3003

# Or use ngrok config file
ngrok start --config=build-scripts/ngrok.yml api
```

#### **Issue**: ngrok connection timeout
```bash
# Check network connectivity
ping ngrok.com

# Check firewall
sudo ufw status

# Try different ngrok region
ngrok http --region=us 3003
```

### **CORS Issues**

#### **Issue**: CORS error in browser
```bash
# Check CORS configuration
curl -H "Origin: http://localhost:8080" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS http://localhost:3003/auth/login

# Update CORS origins
# Edit servers/local_api_server/.env
ALLOWED_ORIGINS=http://localhost:8080,https://your-ngrok-url.ngrok.app
```

#### **Issue**: Mobile app CORS errors
```bash
# Check mobile origins in server.js
# Mobile apps often have no Origin header
# CORS should allow requests with no origin
```

## 🔐 **Authentication Issues**

### **Login Problems**

#### **Issue**: "Invalid credentials" error
```bash
# Check user in database
mongosh --eval "
use soc_chat_app;
db.users.findOne({email: 'user@example.com'});
"

# Check password hash
mongosh --eval "
use soc_chat_app;
db.users.findOne({email: 'user@example.com'}, {password: 1});
"
```

#### **Issue**: JWT token expired
```bash
# Check JWT secret
echo $JWT_SECRET

# Check token expiration
node -e "
const jwt = require('jsonwebtoken');
const token = 'your-jwt-token';
try {
  const decoded = jwt.verify(token, 'your-jwt-secret');
  console.log('Token valid:', decoded);
} catch (error) {
  console.log('Token error:', error.message);
}
"
```

#### **Issue**: Session not persisting
```bash
# Check session storage
# Android: SharedPreferences
# iOS: UserDefaults
# Web: localStorage

# Check token storage
adb shell run-as com.faroukahmed74.socchatapp ls -la /data/data/com.faroukahmed74.socchatapp/shared_prefs/
```

### **Registration Problems**

#### **Issue**: "User already exists" error
```bash
# Check existing user
mongosh --eval "
use soc_chat_app;
db.users.findOne({email: 'user@example.com'});
"

# Delete user if needed
mongosh --eval "
use soc_chat_app;
db.users.deleteOne({email: 'user@example.com'});
"
```

#### **Issue**: Password validation failed
```bash
# Check password requirements
# Minimum 8 characters
# At least one uppercase, lowercase, number, special character

# Test password validation
node -e "
const password = 'TestPassword123!';
const regex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/;
console.log('Password valid:', regex.test(password));
"
```

## ⚡ **Performance Issues**

### **Slow App Performance**

#### **Issue**: App launch slow
```bash
# Check app bundle size
flutter build apk --analyze-size

# Check for unused dependencies
flutter pub deps

# Optimize images
flutter packages pub run flutter_launcher_icons:main
```

#### **Issue**: API responses slow
```bash
# Check database indexes
npm run db:indexes:list

# Check MongoDB slow queries
mongosh --eval "db.system.profile.find().sort({ts: -1}).limit(10)"

# Enable Redis caching
# Edit .env file
REDIS_HOST=localhost
REDIS_PORT=6379
```

#### **Issue**: High memory usage
```bash
# Check memory usage
pm2 monit

# Check for memory leaks
node --inspect server.js

# Restart application
pm2 restart soc-chat-api
```

### **Database Performance**

#### **Issue**: Slow queries
```bash
# Check query execution plans
mongosh --eval "
use soc_chat_app;
db.messages.find({chatId: ObjectId('...')}).explain('executionStats');
"

# Create missing indexes
npm run db:indexes
```

#### **Issue**: High database CPU usage
```bash
# Check MongoDB stats
mongosh --eval "db.serverStatus().metrics"

# Check active connections
mongosh --eval "db.serverStatus().connections"

# Optimize queries
mongosh --eval "db.runCommand({profile: 2, slowms: 100})"
```

## 🔒 **Security Issues**

### **Authentication Security**

#### **Issue**: Weak JWT secret
```bash
# Generate strong JWT secret
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Update JWT secret
# Edit .env file
JWT_SECRET=your-new-strong-secret-key
```

#### **Issue**: Token not expiring
```bash
# Check token expiration
node -e "
const jwt = require('jsonwebtoken');
const token = 'your-token';
const decoded = jwt.decode(token);
console.log('Expires:', new Date(decoded.exp * 1000));
"
```

### **Input Validation Issues**

#### **Issue**: SQL injection attempts
```bash
# Check validation middleware
# Ensure all inputs are validated
# Check routes use validation middleware

# Test input validation
curl -X POST http://localhost:3003/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com<script>","password":"password"}'
```

#### **Issue**: File upload vulnerabilities
```bash
# Check file upload validation
# Ensure file type validation
# Check file size limits
# Verify file content scanning

# Test file upload
curl -X POST http://localhost:3003/api/media/upload \
  -H "Authorization: Bearer your-token" \
  -F "file=@test.jpg" \
  -F "chatId=test" \
  -F "type=image"
```

## 🚨 **Emergency Procedures**

### **Server Down**

#### **Immediate Actions**
```bash
# Check server status
pm2 status

# Check system resources
htop
df -h

# Check logs
pm2 logs soc-chat-api --lines 100

# Restart server
pm2 restart soc-chat-api
```

#### **If PM2 fails**
```bash
# Start server directly
cd servers/local_api_server
node server.js

# Check for port conflicts
sudo lsof -i :3003

# Kill conflicting processes
sudo kill -9 <PID>
```

### **Database Corruption**

#### **Immediate Actions**
```bash
# Stop application
pm2 stop soc-chat-api

# Check database integrity
mongosh --eval "db.runCommand({dbStats: 1})"

# Repair database
mongosh --eval "db.repairDatabase()"
```

#### **Restore from Backup**
```bash
# List available backups
ls -la /backup/soc-chat-app/

# Restore latest backup
mongorestore --uri="mongodb://socchat:SecurePassword123!@localhost:27017/soc_chat_app?authSource=soc_chat_app" \
  /backup/soc-chat-app/soc_chat_app_backup_20240101_120000
```

### **Security Breach**

#### **Immediate Actions**
```bash
# Change all passwords
# JWT secret, database passwords, API keys

# Revoke all sessions
mongosh --eval "
use soc_chat_app;
db.sessions.deleteMany({});
"

# Check access logs
sudo tail -f /var/log/nginx/access.log | grep -i "401\|403\|500"
```

#### **Investigation**
```bash
# Check failed login attempts
mongosh --eval "
use soc_chat_app;
db.users.find({lastLoginAttempt: {\$gte: new Date(Date.now() - 3600000)}});
"

# Check suspicious activity
pm2 logs soc-chat-api | grep -i "error\|failed\|unauthorized"
```

## 📞 **Support Contacts**

### **Emergency Contacts**
- **System Administrator**: [Your Contact]
- **Database Administrator**: [Your Contact]
- **Application Developer**: [Your Contact]
- **Security Team**: [Your Contact]

### **Escalation Procedures**
1. **Level 1**: Check logs and restart services
2. **Level 2**: Contact system administrator
3. **Level 3**: Contact application developer
4. **Level 4**: Contact security team

## 📊 **Monitoring & Alerts**

### **Key Metrics to Monitor**
- Server uptime and response time
- Database connection status
- Memory and CPU usage
- Error rates and types
- User authentication success rate
- API endpoint performance

### **Alert Thresholds**
- Server response time > 5 seconds
- Memory usage > 80%
- CPU usage > 90%
- Error rate > 5%
- Database connection failures
- SSL certificate expiry < 30 days

### **Monitoring Tools**
```bash
# PM2 monitoring
pm2 monit

# System monitoring
htop
iotop
nethogs

# Network monitoring
netstat -tulpn
ss -tulpn

# Log monitoring
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## 🔄 **Recovery Procedures**

### **Application Recovery**
```bash
# Full application restart
pm2 stop all
pm2 start servers/ecosystem.config.js --env production

# Database recovery
mongosh --eval "db.repairDatabase()"

# Cache recovery
redis-cli FLUSHALL
```

### **Data Recovery**
```bash
# Restore from backup
./build-scripts/backup_database.sh --restore /backup/soc-chat-app/backup_name

# Partial data recovery
mongorestore --uri="mongodb://..." --collection=users /backup/users.bson
```

## 📚 **Additional Resources**

### **Documentation**
- [PM2 Documentation](https://pm2.keymetrics.io/docs/)
- [MongoDB Troubleshooting](https://docs.mongodb.com/manual/tutorial/troubleshoot-replica-sets/)
- [Nginx Troubleshooting](https://nginx.org/en/docs/http/ngx_http_core_module.html)
- [Flutter Troubleshooting](https://flutter.dev/docs/testing/debugging)

### **Tools**
- [MongoDB Compass](https://www.mongodb.com/products/compass)
- [Redis Commander](https://github.com/joeferner/redis-commander)
- [Postman](https://www.postman.com/)
- [ngrok Dashboard](https://dashboard.ngrok.com/)

---

**Last Updated**: $(date)
**Version**: 1.0.0
**Maintained by**: SOC Chat App Team
