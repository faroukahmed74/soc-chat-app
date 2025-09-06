# 🖥️ Windows Server 2022 Database Migration Guide

## 📋 **Overview**

This guide provides step-by-step instructions for setting up your SOC Chat App database on Windows Server 2022. Windows Server offers excellent performance, security, and ease of management for your database needs.

## ✅ **Why Windows Server 2022?**

### **🔧 Advantages**
- **Familiar Windows interface** - Easy to manage and configure
- **Built-in security features** - Windows Defender, Firewall, BitLocker
- **GUI management tools** - Visual database administration
- **PowerShell automation** - Powerful scripting capabilities
- **Active Directory integration** - Enterprise user management
- **Microsoft support** - Professional support and documentation

### **💰 Cost Comparison**
- **Windows Server 2022 Standard**: $500-1000/year (one-time or subscription)
- **SQL Server Standard**: $900-1500/year (one-time or subscription)
- **Hosting**: $50-200/month depending on specs
- **Total**: $600-2500/year (vs $1200-6000/year for Firestore)

## 🛠️ **System Requirements**

### **Minimum Requirements**
- **CPU**: 2 cores (1.4 GHz)
- **RAM**: 4GB
- **Storage**: 50GB SSD
- **Network**: 1Gbps connection
- **OS**: Windows Server 2022 Standard

### **Recommended Requirements**
- **CPU**: 4-8 cores (2.0 GHz+)
- **RAM**: 8-16GB
- **Storage**: 100-200GB SSD
- **Network**: 1Gbps+ connection
- **OS**: Windows Server 2022 Standard/Datacenter

## 📦 **Installation Steps**

### **Step 1: Windows Server Setup**

1. **Install Windows Server 2022**
```powershell
# Download Windows Server 2022 ISO from Microsoft
# Install with Desktop Experience for easier management
```

2. **Configure Windows Features**
```powershell
# Install required Windows features
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name NET-Framework-45-Core
Install-WindowsFeature -Name Web-Mgmt-Tools
```

3. **Configure Windows Firewall**
```powershell
# Allow HTTP and HTTPS traffic
New-NetFirewallRule -DisplayName "HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
New-NetFirewallRule -DisplayName "Database" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow
```

### **Step 2: Database Installation**

#### **Option A: PostgreSQL (Recommended)**

1. **Download PostgreSQL for Windows**
```powershell
# Download PostgreSQL 15+ from https://www.postgresql.org/download/windows/
# Run installer with default settings
```

2. **Configure PostgreSQL**
```powershell
# PostgreSQL will be installed in C:\Program Files\PostgreSQL\[version]
# Default port: 5432
# Default user: postgres
```

3. **Create Database and User**
```sql
-- Connect to PostgreSQL as postgres user
CREATE DATABASE soc_chat_app;
CREATE USER soc_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE soc_chat_app TO soc_user;
```

#### **Option B: SQL Server Express (Free)**

1. **Install SQL Server Express**
```powershell
# Download SQL Server Express from Microsoft
# Install with basic settings
```

2. **Configure SQL Server**
```sql
-- Create database
CREATE DATABASE soc_chat_app;
-- Create login
CREATE LOGIN soc_user WITH PASSWORD = 'your_secure_password';
-- Create user
USE soc_chat_app;
CREATE USER soc_user FOR LOGIN soc_user;
-- Grant permissions
EXEC sp_addrolemember 'db_owner', 'soc_user';
```

### **Step 3: Node.js Installation**

1. **Install Node.js**
```powershell
# Download Node.js 18+ LTS from https://nodejs.org/
# Install with default settings
```

2. **Verify Installation**
```powershell
node --version
npm --version
```

3. **Install PM2 for Process Management**
```powershell
npm install -g pm2
```

### **Step 4: REST API Setup**

1. **Create API Directory**
```powershell
mkdir C:\soc-chat-api
cd C:\soc-chat-api
```

2. **Initialize Node.js Project**
```powershell
npm init -y
```

3. **Install Dependencies**
```powershell
npm install express pg cors helmet express-rate-limit jsonwebtoken bcryptjs
npm install --save-dev nodemon
```

4. **Create API Files**

#### **package.json**
```json
{
  "name": "soc-chat-api",
  "version": "1.0.0",
  "description": "SOC Chat App REST API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "pm2": "pm2 start server.js --name soc-chat-api"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
```

#### **server.js**
```javascript
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');

const app = express();
const port = process.env.PORT || 3000;

// Database connection
const pool = new Pool({
  user: 'soc_user',
  host: 'localhost',
  database: 'soc_chat_app',
  password: 'your_secure_password',
  port: 5432,
  max: 20, // Maximum number of connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Authentication middleware
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.sendStatus(401);
  }
  
  try {
    const user = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret');
    req.user = user;
    next();
  } catch (err) {
    return res.sendStatus(403);
  }
};

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date(),
    server: 'Windows Server 2022',
    database: 'PostgreSQL'
  });
});

// Get user chats
app.get('/api/chats', authenticateToken, async (req, res) => {
  try {
    const query = `
      SELECT c.*, 
             json_agg(json_build_object('id', u.id, 'username', u.username, 'display_name', u.display_name, 'avatar_url', u.avatar_url)) as members
      FROM chats c
      JOIN chat_members cm ON c.id = cm.chat_id
      JOIN users u ON cm.user_id = u.id
      WHERE c.id IN (
        SELECT chat_id FROM chat_members WHERE user_id = $1
      )
      GROUP BY c.id
      ORDER BY c.updated_at DESC
    `;
    
    const result = await pool.query(query, [req.user.id]);
    res.json(result.rows);
  } catch (err) {
    console.error('Error getting chats:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get chat messages
app.get('/api/chats/:chatId/messages', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    
    const query = `
      SELECT m.*, 
             json_build_object('id', u.id, 'username', u.username, 'display_name', u.display_name, 'avatar_url', u.avatar_url) as sender
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.chat_id = $1
      ORDER BY m.timestamp DESC
      LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [chatId, limit, offset]);
    res.json(result.rows.reverse());
  } catch (err) {
    console.error('Error getting messages:', err);
    res.status(500).json({ error: err.message });
  }
});

// Send message
app.post('/api/chats/:chatId/messages', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { content, messageType = 'text', mediaUrl, mediaMetadata } = req.body;
    
    const query = `
      INSERT INTO messages (chat_id, sender_id, content, message_type, media_url, media_metadata)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;
    
    const result = await pool.query(query, [
      chatId, req.user.id, content, messageType, mediaUrl, mediaMetadata
    ]);
    
    // Update chat's updated_at timestamp
    await pool.query('UPDATE chats SET updated_at = NOW() WHERE id = $1', [chatId]);
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error sending message:', err);
    res.status(500).json({ error: err.message });
  }
});

// Start server
app.listen(port, () => {
  console.log(`SOC Chat API running on Windows Server 2022, port ${port}`);
  console.log(`Health check: http://localhost:${port}/api/health`);
});
```

### **Step 5: Database Schema**

#### **PostgreSQL Schema**
```sql
-- Connect to soc_chat_app database
\c soc_chat_app

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    avatar_url TEXT,
    role VARCHAR(20) DEFAULT 'user',
    status VARCHAR(20) DEFAULT 'active',
    fcm_token TEXT,
    last_seen TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Chats table
CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL, -- 'private', 'group', 'broadcast'
    name VARCHAR(255),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Chat members table
CREATE TABLE chat_members (
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member', -- 'admin', 'member'
    joined_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (chat_id, user_id)
);

-- Messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id),
    content TEXT,
    message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'video', 'voice', 'file'
    media_url TEXT,
    media_metadata JSONB,
    is_encrypted BOOLEAN DEFAULT FALSE,
    encrypted_content TEXT,
    timestamp TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_messages_chat_timestamp ON messages(chat_id, timestamp DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_chat_members_user ON chat_members(user_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

### **Step 6: Windows Service Setup**

1. **Install PM2 Windows Service**
```powershell
# Install PM2 globally
npm install -g pm2

# Start the API with PM2
pm2 start server.js --name soc-chat-api

# Save PM2 configuration
pm2 save

# Install PM2 as Windows service
pm2 startup
```

2. **Configure Windows Task Scheduler (Alternative)**
```powershell
# Create a batch file to start the API
echo "cd C:\soc-chat-api && node server.js" > C:\soc-chat-api\start-api.bat

# Create scheduled task to run on startup
schtasks /create /tn "SOC Chat API" /tr "C:\soc-chat-api\start-api.bat" /sc onstart /ru "SYSTEM"
```

### **Step 7: SSL Certificate Setup**

1. **Install IIS for SSL**
```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
```

2. **Generate SSL Certificate**
```powershell
# Using OpenSSL (install from https://slproweb.com/products/Win32OpenSSL.html)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

3. **Configure Reverse Proxy**
```powershell
# Install URL Rewrite and Application Request Routing
# Configure reverse proxy from IIS to Node.js on port 3000
```

### **Step 8: Monitoring and Logging**

1. **Windows Event Logging**
```powershell
# Create custom event log
New-EventLog -LogName "SOC Chat API" -Source "SOC Chat API"
```

2. **Performance Monitoring**
```powershell
# Monitor CPU, Memory, Disk, Network
Get-Counter -Counter "\Processor(_Total)\% Processor Time"
Get-Counter -Counter "\Memory\Available MBytes"
```

3. **Database Monitoring**
```sql
-- PostgreSQL monitoring queries
SELECT * FROM pg_stat_activity;
SELECT * FROM pg_stat_database;
```

## 🔧 **Windows-Specific Optimizations**

### **Performance Tuning**

1. **Windows Performance Settings**
```powershell
# Optimize for performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
```

2. **Database Connection Pooling**
```javascript
// In server.js
const pool = new Pool({
  // ... other settings
  max: 20, // Adjust based on server specs
  min: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

3. **Windows Firewall Optimization**
```powershell
# Allow specific IP ranges
New-NetFirewallRule -DisplayName "SOC Chat API" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
```

### **Security Hardening**

1. **Windows Security Settings**
```powershell
# Enable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false

# Configure Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
```

2. **Database Security**
```sql
-- Restrict database access
REVOKE CONNECT ON DATABASE soc_chat_app FROM PUBLIC;
GRANT CONNECT ON DATABASE soc_chat_app TO soc_user;
```

## 📊 **Cost Comparison: Windows Server vs Firestore**

| Component | Windows Server 2022 | Firestore | Savings |
|-----------|---------------------|-----------|---------|
| **Server License** | $500-1000/year | $0 | -$500-1000 |
| **Database License** | $0 (PostgreSQL) / $900 (SQL Server) | $0 | $0-900 |
| **Hosting** | $50-200/month | $0 | -$600-2400 |
| **Database Operations** | $0 (unlimited) | $0.18/1M operations | **$100-500/month** |
| **Storage** | $0.05-0.10/GB/month | $0.18/GB/month | **50-70% savings** |
| **Data Transfer** | $0 (unlimited) | $0.12/GB | **100% savings** |
| **Total Monthly** | $50-200 | $100-500 | **50-80% savings** |

## 🚀 **Deployment Checklist**

### **Windows Server Setup**
- [ ] Install Windows Server 2022 Standard
- [ ] Configure Windows Features and Firewall
- [ ] Install PostgreSQL or SQL Server
- [ ] Install Node.js and PM2
- [ ] Configure SSL certificates
- [ ] Set up monitoring and logging

### **Database Setup**
- [ ] Create database and user
- [ ] Run schema creation scripts
- [ ] Create indexes for performance
- [ ] Configure connection pooling
- [ ] Set up automated backups

### **API Setup**
- [ ] Deploy REST API
- [ ] Configure environment variables
- [ ] Set up rate limiting
- [ ] Implement authentication
- [ ] Add logging and monitoring

### **Flutter App Changes**
- [ ] Update database configuration
- [ ] Test with Windows Server API
- [ ] Implement error handling
- [ ] Add fallback to Firestore

## 🎯 **Benefits of Windows Server 2022**

### **✅ Advantages**
- **Familiar management** - Windows GUI and PowerShell
- **Built-in security** - Windows Defender, Firewall, BitLocker
- **Enterprise features** - Active Directory, Group Policy
- **Microsoft support** - Professional support and documentation
- **Scalability** - Easy to scale up or down
- **Integration** - Seamless with other Microsoft services

### **❌ Considerations**
- **Licensing costs** - Windows Server and SQL Server licenses
- **Resource overhead** - Windows uses more resources than Linux
- **Learning curve** - If not familiar with Windows Server
- **Updates** - Regular Windows updates and patches

## 🎉 **Conclusion**

**Windows Server 2022** is an excellent choice for hosting your SOC Chat App database! It offers:

- ✅ **Familiar Windows environment**
- ✅ **Enterprise-grade security**
- ✅ **Professional support**
- ✅ **Cost savings** (50-80% vs Firestore)
- ✅ **Full control** over your data and infrastructure

The setup is straightforward, and you'll have a robust, scalable solution that can grow with your app!

Would you like me to help you:
1. **Set up Windows Server 2022** step by step?
2. **Configure PostgreSQL** on Windows?
3. **Deploy the REST API** on Windows Server?
4. **Integrate with your Flutter app**?

