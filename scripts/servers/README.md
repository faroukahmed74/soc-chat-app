# 🖥️ Servers Directory

This directory contains server-side components for the SOC Chat App, including Firebase Cloud Messaging (FCM) server, Node.js dependencies, and server utilities.

## 📁 Server Components

### 🔔 FCM Server

#### `fcm_server.js`
- **Purpose**: Firebase Cloud Messaging server for push notifications
- **Features**: Send notifications to users, broadcast messages, admin notifications
- **Use Case**: Server-side notification management
- **Dependencies**: Firebase Admin SDK, Node.js

#### `test_fcm.js`
- **Purpose**: Test FCM server functionality
- **Features**: Test notification sending, verify server connectivity
- **Use Case**: FCM server testing and validation
- **Dependencies**: Firebase Admin SDK

### 📦 Package Management

#### `package.json`
- **Purpose**: Node.js dependencies and scripts
- **Contains**: Server dependencies, build scripts, project metadata
- **Use Case**: Server dependency management
- **Dependencies**: Node.js package manager

#### `package-lock.json`
- **Purpose**: Locked dependency versions
- **Contains**: Exact dependency versions for reproducible builds
- **Use Case**: Dependency version consistency
- **Dependencies**: npm

#### `node_modules/`
- **Purpose**: Installed Node.js packages
- **Contains**: All server dependencies and their sub-dependencies
- **Use Case**: Runtime dependency resolution
- **Dependencies**: npm install

## 🚀 Server Setup

### Prerequisites
- Node.js (v16 or higher)
- npm or yarn package manager
- Firebase project with FCM enabled
- Firebase Admin SDK service account key

### Installation

#### 1. Install Dependencies
```bash
cd servers
npm install
```

#### 2. Configure Firebase
1. Download service account key from Firebase Console
2. Place in `assets/service-account/` directory
3. Update FCM server configuration

#### 3. Environment Configuration
```bash
# Create .env file
cp .env.example .env

# Configure environment variables
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email
```

### FCM Server Configuration

#### Service Account Setup
```javascript
// fcm_server.js
const admin = require('firebase-admin');
const serviceAccount = require('./assets/service-account/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID
});
```

#### Notification Configuration
```javascript
// fcm_server.js
const message = {
  notification: {
    title: 'New Message',
    body: 'You have a new message from John'
  },
  data: {
    type: 'message',
    senderId: 'user123',
    chatId: 'chat456'
  },
  token: 'user-fcm-token'
};
```

## 🔔 FCM Server Usage

### Starting the Server
```bash
# Start FCM server
node fcm_server.js

# Start with environment variables
FIREBASE_PROJECT_ID=your-project node fcm_server.js
```

### Sending Notifications

#### Individual User Notification
```javascript
// Send to specific user
const sendToUser = async (userId, notification) => {
  try {
    const userToken = await getUserFCMToken(userId);
    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      token: userToken
    };
    
    const response = await admin.messaging().send(message);
    console.log('Notification sent:', response);
  } catch (error) {
    console.error('Error sending notification:', error);
  }
};
```

#### Broadcast Notification
```javascript
// Send to all users
const broadcastToAllUsers = async (notification) => {
  try {
    const allTokens = await getAllUserTokens();
    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      tokens: allTokens
    };
    
    const response = await admin.messaging().sendMulticast(message);
    console.log('Broadcast sent:', response);
  } catch (error) {
    console.error('Error broadcasting:', error);
  }
};
```

#### Topic-Based Notification
```javascript
// Send to topic subscribers
const sendToTopic = async (topic, notification) => {
  try {
    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      topic: topic
    };
    
    const response = await admin.messaging().send(message);
    console.log('Topic notification sent:', response);
  } catch (error) {
    console.error('Error sending topic notification:', error);
  }
};
```

## 🧪 Testing FCM Server

### Running Tests
```bash
# Test FCM server functionality
node test_fcm.js

# Test with specific configuration
FIREBASE_PROJECT_ID=test-project node test_fcm.js
```

### Test Scenarios

#### 1. Server Connectivity Test
```javascript
// test_fcm.js
const testServerConnectivity = async () => {
  try {
    const app = admin.app();
    console.log('✅ FCM server connected successfully');
    return true;
  } catch (error) {
    console.error('❌ FCM server connection failed:', error);
    return false;
  }
};
```

#### 2. Notification Sending Test
```javascript
// test_fcm.js
const testNotificationSending = async () => {
  try {
    const testToken = 'test-fcm-token';
    const message = {
      notification: {
        title: 'Test Notification',
        body: 'This is a test notification'
      },
      token: testToken
    };
    
    const response = await admin.messaging().send(message);
    console.log('✅ Test notification sent:', response);
    return true;
  } catch (error) {
    console.error('❌ Test notification failed:', error);
    return false;
  }
};
```

#### 3. Broadcast Test
```javascript
// test_fcm.js
const testBroadcast = async () => {
  try {
    const testTokens = ['token1', 'token2', 'token3'];
    const message = {
      notification: {
        title: 'Test Broadcast',
        body: 'This is a test broadcast'
      },
      tokens: testTokens
    };
    
    const response = await admin.messaging().sendMulticast(message);
    console.log('✅ Test broadcast sent:', response);
    return true;
  } catch (error) {
    console.error('❌ Test broadcast failed:', error);
    return false;
  }
};
```

## 🔧 Server Configuration

### Environment Variables
```bash
# .env file
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
FCM_SERVER_PORT=3000
NODE_ENV=production
```

### Firebase Configuration
```javascript
// firebase.config.js
module.exports = {
  type: "service_account",
  project_id: process.env.FIREBASE_PROJECT_ID,
  private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
  private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  client_email: process.env.FIREBASE_CLIENT_EMAIL,
  client_id: process.env.FIREBASE_CLIENT_ID,
  auth_uri: "https://accounts.google.com/o/oauth2/auth",
  token_uri: "https://oauth2.googleapis.com/token",
  auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
  client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${process.env.FIREBASE_CLIENT_EMAIL}`
};
```

## 🚀 Deployment

### Local Development
```bash
# Start development server
npm run dev

# Start with nodemon for auto-restart
npm run dev:watch
```

### Production Deployment
```bash
# Build for production
npm run build

# Start production server
npm start

# Use PM2 for process management
pm2 start fcm_server.js --name "fcm-server"
```

### Docker Deployment
```dockerfile
# Dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "fcm_server.js"]
```

## 🔐 Security Considerations

### Service Account Security
1. **Never commit service account keys** to version control
2. **Use environment variables** for sensitive data
3. **Restrict service account permissions** to minimum required
4. **Rotate keys regularly** for production environments

### API Security
```javascript
// Add authentication middleware
const authenticateRequest = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== process.env.API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

// Apply to routes
app.use('/api/notifications', authenticateRequest);
```

### Rate Limiting
```javascript
// Add rate limiting
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

## 📊 Monitoring & Logging

### Logging Configuration
```javascript
// Add structured logging
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Use in FCM server
logger.info('FCM server started', { timestamp: new Date() });
```

### Health Checks
```javascript
// Add health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date(),
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});
```

## 🐛 Troubleshooting

### Common Issues

#### FCM Server Won't Start
1. Check Firebase credentials
2. Verify service account key format
3. Check environment variables
4. Verify Firebase project ID

#### Notifications Not Sending
1. Check FCM token validity
2. Verify notification payload format
3. Check Firebase project configuration
4. Verify service account permissions

#### High Memory Usage
1. Monitor memory usage with `process.memoryUsage()`
2. Implement garbage collection
3. Check for memory leaks
4. Optimize notification batching

### Debug Mode
```bash
# Enable debug logging
DEBUG=firebase-admin node fcm_server.js

# Enable verbose logging
NODE_ENV=development node fcm_server.js
```

## 📋 Maintenance

### Regular Tasks
1. **Update dependencies**: `npm update`
2. **Check Firebase quotas**: Monitor usage in Firebase Console
3. **Review logs**: Check for errors and performance issues
4. **Backup configuration**: Keep configuration backups

### Performance Optimization
1. **Batch notifications**: Send multiple notifications together
2. **Use topics**: Reduce individual token management
3. **Implement caching**: Cache frequently accessed data
4. **Monitor metrics**: Track notification delivery rates

## 🔗 Related Documentation

- **[FCM Setup Guide](../docs/FCM_SETUP_GUIDE.md)** - Complete FCM setup guide
- **[FCM Server README](../docs/FCM_SERVER_README.md)** - FCM server documentation
- **[Notification System](../docs/NOTIFICATION_SYSTEM_STATUS.md)** - Notification system status
- **[Firebase Integration](../docs/FIREBASE_INTEGRATION_COMPLETE.md)** - Firebase setup guide

## 📞 Support

For server issues:
1. Check the troubleshooting section above
2. Review [FCM Setup Guide](../docs/FCM_SETUP_GUIDE.md)
3. Check [FCM Server README](../docs/FCM_SERVER_README.md)
4. Create an issue in the repository

---

**Note**: Always test FCM server changes in development before deploying to production.
