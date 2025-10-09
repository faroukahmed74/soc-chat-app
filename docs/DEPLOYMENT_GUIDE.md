# 🚀 SOC Chat App - Production Deployment Guide

This comprehensive guide covers deploying the SOC Chat App to production with all security, performance, and reliability features enabled.

## 📋 **Table of Contents**

1. [Prerequisites](#prerequisites)
2. [Server Setup](#server-setup)
3. [Database Setup](#database-setup)
4. [SSL Certificate Setup](#ssl-certificate-setup)
5. [Application Deployment](#application-deployment)
6. [Mobile App Deployment](#mobile-app-deployment)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Security Hardening](#security-hardening)
9. [Performance Optimization](#performance-optimization)
10. [Troubleshooting](#troubleshooting)

## 🔧 **Prerequisites**

### **System Requirements**
- **OS**: Ubuntu 20.04+ / CentOS 8+ / Windows Server 2019+
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: Minimum 50GB SSD
- **CPU**: 2+ cores
- **Network**: Static IP address, domain name

### **Software Requirements**
- **Node.js**: 18.0.0+
- **MongoDB**: 5.0+
- **Redis**: 6.0+ (optional but recommended)
- **PM2**: Latest version
- **Nginx**: 1.18+ (for reverse proxy)
- **Certbot**: For SSL certificates

### **Domain & DNS**
- Domain name pointing to your server
- DNS A record configured
- Optional: Subdomain for API (api.yourdomain.com)

## 🖥️ **Server Setup**

### **1. Initial Server Configuration**

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git nginx certbot python3-certbot-nginx

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org

# Install Redis (optional)
sudo apt install -y redis-server
```

### **2. Firewall Configuration**

```bash
# Configure UFW firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3003/tcp  # API server
sudo ufw allow 3000/tcp  # FCM server (if needed)
```

### **3. Create Application User**

```bash
# Create dedicated user for the application
sudo useradd -m -s /bin/bash socchat
sudo usermod -aG sudo socchat

# Switch to application user
sudo su - socchat
```

## 🗄️ **Database Setup**

### **1. MongoDB Configuration**

```bash
# Start MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod

# Secure MongoDB installation
sudo mongosh
```

```javascript
// In MongoDB shell
use admin
db.createUser({
  user: "admin",
  pwd: "SecurePassword123!",
  roles: [{ role: "userAdminAnyDatabase", db: "admin" }]
})

use soc_chat_app
db.createUser({
  user: "socchat",
  pwd: "SecurePassword123!",
  roles: [{ role: "readWrite", db: "soc_chat_app" }]
})
```

### **2. MongoDB Security Configuration**

```bash
# Edit MongoDB configuration
sudo nano /etc/mongod.conf
```

```yaml
# /etc/mongod.conf
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1  # Only local connections

security:
  authorization: enabled

processManagement:
  timeZoneInfo: /usr/share/zoneinfo
```

```bash
# Restart MongoDB
sudo systemctl restart mongod
```

### **3. Redis Configuration (Optional)**

```bash
# Configure Redis
sudo nano /etc/redis/redis.conf
```

```conf
# /etc/redis/redis.conf
bind 127.0.0.1
port 6379
requirepass SecureRedisPassword123!
maxmemory 256mb
maxmemory-policy allkeys-lru
```

```bash
# Restart Redis
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

## 🔒 **SSL Certificate Setup**

### **1. Let's Encrypt SSL Certificate**

```bash
# Get SSL certificate
sudo certbot certonly --standalone -d yourdomain.com -d api.yourdomain.com

# Test certificate renewal
sudo certbot renew --dry-run
```

### **2. Auto-renewal Setup**

```bash
# Add cron job for auto-renewal
sudo crontab -e
```

```cron
# Add this line to crontab
0 2 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx
```

## 🚀 **Application Deployment**

### **1. Clone and Setup Application**

```bash
# Clone repository
cd /home/socchat
git clone https://github.com/your-username/soc-chat-app.git
cd soc-chat-app

# Install dependencies
cd servers/local_api_server
npm install

# Copy environment configuration
cp ../../servers/env.example .env
```

### **2. Configure Environment Variables**

```bash
# Edit environment file
nano .env
```

```env
# Production Environment Configuration
NODE_ENV=production
PORT=3003
HOST=0.0.0.0

# Database Configuration
MONGO_URI=mongodb://socchat:SecurePassword123!@localhost:27017/soc_chat_app?authSource=soc_chat_app

# Redis Configuration (optional)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=SecureRedisPassword123!

# JWT Configuration
JWT_SECRET=your_very_secure_jwt_secret_key_minimum_32_characters_long

# CORS Configuration
ALLOWED_ORIGINS=https://yourdomain.com,https://api.yourdomain.com

# SSL Configuration
SSL_CERT_PATH=/etc/letsencrypt/live/yourdomain.com/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/yourdomain.com/privkey.pem

# Security Configuration
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=200

# File Upload Configuration
MAX_UPLOAD_MB=50
PUBLIC_BASE_URL=https://api.yourdomain.com

# Logging Configuration
LOG_LEVEL=warn
ENABLE_REQUEST_LOGGING=true
```

### **3. Create Database Indexes**

```bash
# Create database indexes
npm run db:indexes
```

### **4. Setup PM2 Process Management**

```bash
# Start application with PM2
pm2 start ../../servers/ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

# Setup PM2 startup
pm2 startup
```

### **5. Configure Nginx Reverse Proxy**

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/soc-chat-app
```

```nginx
# /etc/nginx/sites-available/soc-chat-app
server {
    listen 80;
    server_name yourdomain.com api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com api.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # API Proxy
    location /api/ {
        proxy_pass http://localhost:3003/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket Proxy
    location /socket.io/ {
        proxy_pass http://localhost:3003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static Files
    location / {
        root /home/socchat/soc-chat-app/build/web;
        try_files $uri $uri/ /index.html;
    }

    # File Upload Size
    client_max_body_size 50M;
}
```

```bash
# Enable site and restart Nginx
sudo ln -s /etc/nginx/sites-available/soc-chat-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 📱 **Mobile App Deployment**

### **1. Setup ngrok for Mobile Access**

```bash
# Install ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# Authenticate ngrok
ngrok config add-authtoken YOUR_NGROK_AUTHTOKEN
```

### **2. Start ngrok Tunnel**

```bash
# Start ngrok tunnel
cd /home/socchat/soc-chat-app
./build-scripts/start_ngrok.sh -p 3003
```

### **3. Build Mobile Apps**

```bash
# Build Android APK
./build-scripts/build_mobile_with_ngrok.sh --platform android --url https://your-ngrok-url.ngrok.app

# Build iOS (on macOS)
./build-scripts/build_mobile_with_ngrok.sh --platform ios --url https://your-ngrok-url.ngrok.app
```

## 📊 **Monitoring & Maintenance**

### **1. Setup Log Rotation**

```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/soc-chat-app
```

```
/home/socchat/soc-chat-app/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 socchat socchat
    postrotate
        pm2 reloadLogs
    endscript
}
```

### **2. Setup Database Backups**

```bash
# Create backup directory
sudo mkdir -p /backup/soc-chat-app
sudo chown socchat:socchat /backup/soc-chat-app

# Add backup cron job
crontab -e
```

```cron
# Daily backup at 3 AM
0 3 * * * /home/socchat/soc-chat-app/build-scripts/backup_database.sh

# Weekly backup cleanup
0 4 * * 0 find /backup/soc-chat-app -name "*.tar.gz" -mtime +30 -delete
```

### **3. Monitor Application**

```bash
# PM2 monitoring
pm2 monit

# Check application status
pm2 status

# View logs
pm2 logs soc-chat-api

# Restart application
pm2 restart soc-chat-api
```

## 🔐 **Security Hardening**

### **1. Server Security**

```bash
# Disable root login
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no

# Change SSH port
# Set: Port 2222

# Restart SSH
sudo systemctl restart ssh
```

### **2. Application Security**

```bash
# Set proper file permissions
chmod 600 /home/socchat/soc-chat-app/servers/local_api_server/.env
chmod 700 /home/socchat/soc-chat-app/servers/local_api_server

# Install security updates
sudo apt update && sudo apt upgrade -y
```

### **3. Database Security**

```bash
# MongoDB security checklist
# ✅ Authentication enabled
# ✅ Bind to localhost only
# ✅ Regular backups
# ✅ Access logging enabled
```

## ⚡ **Performance Optimization**

### **1. System Optimization**

```bash
# Increase file limits
sudo nano /etc/security/limits.conf
```

```
socchat soft nofile 65536
socchat hard nofile 65536
```

### **2. MongoDB Optimization**

```bash
# MongoDB performance tuning
sudo nano /etc/mongod.conf
```

```yaml
# Add to mongod.conf
operationProfiling:
  slowOpThresholdMs: 100
  mode: slowOp

storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2
```

### **3. Nginx Optimization**

```bash
# Nginx performance tuning
sudo nano /etc/nginx/nginx.conf
```

```nginx
# Add to nginx.conf
worker_processes auto;
worker_connections 1024;

gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

## 🔧 **Troubleshooting**

### **Common Issues**

#### **1. Application Won't Start**
```bash
# Check PM2 logs
pm2 logs soc-chat-api

# Check MongoDB connection
mongosh "mongodb://socchat:SecurePassword123!@localhost:27017/soc_chat_app?authSource=soc_chat_app"

# Check Redis connection
redis-cli -a SecureRedisPassword123! ping
```

#### **2. SSL Certificate Issues**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificate manually
sudo certbot renew

# Check Nginx configuration
sudo nginx -t
```

#### **3. Database Connection Issues**
```bash
# Check MongoDB status
sudo systemctl status mongod

# Check MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Test connection
mongosh --host localhost:27017 --authenticationDatabase admin -u admin -p
```

#### **4. Mobile App Connection Issues**
```bash
# Check ngrok status
curl http://localhost:4040/api/tunnels

# Restart ngrok
pkill ngrok
./build-scripts/start_ngrok.sh -p 3003

# Check API health
curl https://your-ngrok-url.ngrok.app/health
```

## 📈 **Performance Monitoring**

### **1. Application Metrics**

```bash
# PM2 monitoring
pm2 monit

# System resources
htop

# Network connections
netstat -tulpn | grep :3003
```

### **2. Database Performance**

```bash
# MongoDB stats
mongosh --eval "db.stats()"

# Slow queries
mongosh --eval "db.setProfilingLevel(2, {slowms: 100})"
```

### **3. Log Analysis**

```bash
# Application logs
tail -f /home/socchat/.pm2/logs/soc-chat-api-out.log

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 🔄 **Updates and Maintenance**

### **1. Application Updates**

```bash
# Pull latest changes
cd /home/socchat/soc-chat-app
git pull origin main

# Install new dependencies
cd servers/local_api_server
npm install

# Restart application
pm2 restart soc-chat-api
```

### **2. Database Maintenance**

```bash
# Create indexes
npm run db:indexes

# Backup database
./build-scripts/backup_database.sh

# Clean old backups
find /backup/soc-chat-app -name "*.tar.gz" -mtime +30 -delete
```

### **3. Security Updates**

```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Node.js updates
sudo npm install -g npm@latest

# PM2 updates
sudo npm install -g pm2@latest
```

## 📞 **Support and Maintenance**

### **Emergency Contacts**
- **System Administrator**: [Your Contact]
- **Database Administrator**: [Your Contact]
- **Application Developer**: [Your Contact]

### **Monitoring Alerts**
- **Server Down**: Email/SMS alerts
- **Database Issues**: Email alerts
- **SSL Certificate Expiry**: Email alerts
- **High Resource Usage**: Email alerts

### **Backup Recovery**
```bash
# Restore from backup
mongorestore --uri="mongodb://socchat:SecurePassword123!@localhost:27017/soc_chat_app?authSource=soc_chat_app" /backup/soc-chat-app/backup_name
```

## ✅ **Deployment Checklist**

### **Pre-Deployment**
- [ ] Server provisioned and configured
- [ ] Domain DNS configured
- [ ] SSL certificates obtained
- [ ] Database installed and secured
- [ ] Redis installed (optional)
- [ ] Firewall configured
- [ ] User accounts created

### **Deployment**
- [ ] Application code deployed
- [ ] Environment variables configured
- [ ] Database indexes created
- [ ] PM2 processes started
- [ ] Nginx configured
- [ ] SSL certificates installed
- [ ] Mobile apps built and tested

### **Post-Deployment**
- [ ] Health checks passing
- [ ] SSL certificate working
- [ ] Mobile apps connecting
- [ ] Monitoring configured
- [ ] Backups scheduled
- [ ] Log rotation configured
- [ ] Security hardening completed

## 🎉 **Deployment Complete!**

Your SOC Chat App is now deployed to production with:
- ✅ **High Availability**: PM2 clustering
- ✅ **Security**: SSL, input validation, CSP headers
- ✅ **Performance**: Caching, compression, indexing
- ✅ **Monitoring**: Health checks, logging, metrics
- ✅ **Backup**: Automated database backups
- ✅ **Mobile Ready**: ngrok integration for global access

## 📚 **Additional Resources**

- [PM2 Documentation](https://pm2.keymetrics.io/docs/)
- [MongoDB Production Notes](https://docs.mongodb.com/manual/administration/production-notes/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Redis Configuration](https://redis.io/documentation)

---

**Last Updated**: $(date)
**Version**: 1.0.0
**Maintained by**: SOC Chat App Team
