# 🚀 **FCM Server Production Deployment Guide**

## 📋 **Overview**

This guide provides step-by-step instructions for deploying the SOC Chat App FCM Server to production environments. The server handles Firebase Cloud Messaging for push notifications across Android, iOS, and Web platforms.

## 🎯 **Deployment Options**

### **Option 1: Traditional VPS/Server Deployment**
- **Best for**: Full control, custom configurations
- **Platforms**: Ubuntu, CentOS, AWS EC2, Google Compute Engine
- **Complexity**: Medium

### **Option 2: Container Deployment (Docker)**
- **Best for**: Consistent environments, easy scaling
- **Platforms**: Docker, Kubernetes, Docker Swarm
- **Complexity**: Low-Medium

### **Option 3: Cloud Platform Deployment**
- **Best for**: Managed services, auto-scaling
- **Platforms**: Heroku, Google App Engine, AWS Lambda
- **Complexity**: Low

### **Option 4: Serverless Deployment**
- **Best for**: Event-driven, cost-effective
- **Platforms**: AWS Lambda, Google Cloud Functions
- **Complexity**: Medium

## 🛠️ **Prerequisites**

### **Required Tools**
- Node.js 18+ and npm
- Git
- Firebase project with service account
- Domain name (for production)
- SSL certificate

### **Firebase Setup**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `soc-chat-app-ca57e`
3. Go to Project Settings > Service Accounts
4. Generate new private key
5. Download the JSON file

## 🚀 **Option 1: Traditional VPS Deployment**

### **Step 1: Server Setup**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 for process management
sudo npm install -g pm2

# Install Nginx for reverse proxy
sudo apt install nginx -y

# Install Certbot for SSL
sudo apt install certbot python3-certbot-nginx -y
```

### **Step 2: Application Deployment**
```bash
# Clone repository
git clone https://github.com/your-username/soc-chat-app.git
cd soc-chat-app/servers

# Install dependencies
npm install

# Create production environment file
cp env.production.example .env.production
nano .env.production

# Start the application
npm run deploy

# Save PM2 configuration
pm2 save
pm2 startup
```

### **Step 3: Nginx Configuration**
```nginx
# /etc/nginx/sites-available/fcm-server
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### **Step 4: SSL Setup**
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/fcm-server /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

## 🐳 **Option 2: Docker Deployment**

### **Step 1: Build and Run**
```bash
# Build production image
docker build -t soc-chat-fcm-server:latest .

# Run container
docker run -d \
  --name fcm-server \
  -p 3000:3000 \
  --env-file .env.production \
  --restart unless-stopped \
  soc-chat-fcm-server:latest

# Check logs
docker logs fcm-server

# Check status
docker ps
```

### **Step 2: Docker Compose (Recommended)**
```yaml
# docker-compose.yml
version: '3.8'

services:
  fcm-server:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    env_file:
      - .env.production
    restart: unless-stopped
    volumes:
      - ./logs:/app/logs
      - ./uploads:/app/uploads
    networks:
      - fcm-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl
    depends_on:
      - fcm-server
    restart: unless-stopped
    networks:
      - fcm-network

networks:
  fcm-network:
    driver: bridge

volumes:
  logs:
  uploads:
```

### **Step 3: Deploy with Compose**
```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f fcm-server

# Scale if needed
docker-compose up -d --scale fcm-server=3
```

## ☁️ **Option 3: Cloud Platform Deployment**

### **Heroku Deployment**
```bash
# Install Heroku CLI
curl https://cli-assets.heroku.com/install.sh | sh

# Login to Heroku
heroku login

# Create app
heroku create your-fcm-server

# Set environment variables
heroku config:set NODE_ENV=production
heroku config:set FIREBASE_PROJECT_ID=soc-chat-app-ca57e
# ... set other Firebase variables

# Deploy
git push heroku main

# Check logs
heroku logs --tail
```

### **Google App Engine**
```yaml
# app.yaml
runtime: nodejs18
service: fcm-server

env_variables:
  NODE_ENV: production
  PORT: 8080

automatic_scaling:
  target_cpu_utilization: 0.65
  min_instances: 1
  max_instances: 10

resources:
  cpu: 1
  memory_gb: 0.5
  disk_size_gb: 10
```

```bash
# Deploy to App Engine
gcloud app deploy app.yaml

# Check status
gcloud app browse
```

## 🔧 **Environment Configuration**

### **Production Environment Variables**
```bash
# Copy example file
cp env.production.example .env.production

# Edit with your values
nano .env.production
```

### **Required Variables**
```bash
NODE_ENV=production
PORT=3000

# Firebase Configuration
FIREBASE_TYPE=service_account
FIREBASE_PROJECT_ID=soc-chat-app-ca57e
FIREBASE_PRIVATE_KEY_ID=your_private_key_id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour key here\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@soc-chat-app-ca57e.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your_client_id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx%40soc-chat-app-ca57e.iam.gserviceaccount.com
FIREBASE_STORAGE_BUCKET=soc-chat-app-ca57e.appspot.com

# Security
ALLOWED_ORIGINS=https://your-domain.com,https://www.your-domain.com
```

## 📊 **Monitoring and Health Checks**

### **Health Check Endpoints**
```bash
# Basic health check
curl https://your-domain.com/health

# Detailed health check
curl https://your-domain.com/health/detailed

# Server statistics
curl https://your-domain.com/stats
```

### **PM2 Monitoring**
```bash
# Monitor processes
pm2 monit

# View logs
pm2 logs fcm-server

# Check status
pm2 status

# Restart service
pm2 restart fcm-server
```

### **Docker Monitoring**
```bash
# Container stats
docker stats fcm-server

# Resource usage
docker system df

# Log monitoring
docker logs -f fcm-server
```

## 🔒 **Security Best Practices**

### **Firewall Configuration**
```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### **Rate Limiting**
- Default: 100 requests per 15 minutes per IP
- Adjustable via environment variables
- Monitor for abuse patterns

### **SSL/TLS Configuration**
- Use Let's Encrypt for free certificates
- Enable HSTS headers
- Configure secure cipher suites

### **Access Control**
- Restrict CORS origins
- Implement API key authentication if needed
- Monitor access logs

## 📈 **Scaling and Performance**

### **Horizontal Scaling**
```bash
# Scale with PM2
pm2 scale fcm-server 4

# Scale with Docker Compose
docker-compose up -d --scale fcm-server=4

# Load balancer configuration
# Use Nginx or HAProxy for load balancing
```

### **Performance Optimization**
- Enable compression
- Use Redis for caching
- Implement connection pooling
- Monitor memory usage

### **Auto-scaling**
- Cloud platforms: Configure auto-scaling rules
- VPS: Use monitoring tools to trigger scaling
- Docker: Implement health checks and restart policies

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. FCM Token Issues**
```bash
# Check Firebase configuration
curl -X POST https://your-domain.com/send-notification \
  -H "Content-Type: application/json" \
  -d '{"token":"test","title":"Test","body":"Test"}'
```

#### **2. Permission Issues**
```bash
# Check file permissions
ls -la /app
chown -R nodejs:nodejs /app
chmod -R 755 /app
```

#### **3. Memory Issues**
```bash
# Check memory usage
pm2 monit
docker stats fcm-server

# Restart service
pm2 restart fcm-server
docker restart fcm-server
```

### **Log Analysis**
```bash
# View application logs
pm2 logs fcm-server --lines 100
docker logs fcm-server --tail 100

# Check system logs
sudo journalctl -u nginx -f
sudo tail -f /var/log/nginx/error.log
```

## 📋 **Deployment Checklist**

### **Pre-deployment**
- [ ] Firebase service account configured
- [ ] Environment variables set
- [ ] SSL certificate obtained
- [ ] Domain DNS configured
- [ ] Firewall rules configured

### **Deployment**
- [ ] Application deployed successfully
- [ ] Health checks passing
- [ ] SSL certificate working
- [ ] Notifications sending successfully
- [ ] Monitoring configured

### **Post-deployment**
- [ ] Performance monitoring active
- [ ] Log rotation configured
- [ ] Backup strategy implemented
- [ ] Alert system configured
- [ ] Documentation updated

## 🔄 **Maintenance and Updates**

### **Regular Maintenance**
```bash
# Update dependencies
npm update

# Security audit
npm audit

# Restart services
pm2 restart all
docker-compose restart

# Monitor logs
pm2 logs --lines 1000
```

### **Update Deployment**
```bash
# Pull latest code
git pull origin main

# Install dependencies
npm install

# Restart services
pm2 restart fcm-server
docker-compose up -d --build
```

## 📞 **Support and Resources**

### **Useful Commands**
```bash
# Quick health check
curl -s https://your-domain.com/health | jq .

# Test notification
curl -X POST https://your-domain.com/send-notification \
  -H "Content-Type: application/json" \
  -d '{"token":"your_fcm_token","title":"Test","body":"Hello World"}'

# View server stats
curl -s https://your-domain.com/stats | jq .
```

### **Documentation**
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Express.js](https://expressjs.com/)
- [PM2 Documentation](https://pm2.keymetrics.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

### **Monitoring Tools**
- PM2 Monitoring
- Docker Stats
- Nginx Status
- Custom health checks
- External monitoring services

---

**Last Updated**: December 2024  
**Version**: 1.0.0  
**Status**: ✅ **Production Ready**


