# ⚙️ Configuration Directory

This directory contains all configuration files for the SOC Chat App, including Firebase settings, build configurations, and analysis options.

## 📁 Configuration Files

### 🔥 Firebase Configuration

#### `firebase.json`
- **Purpose**: Main Firebase project configuration
- **Contains**: Hosting, functions, and project settings
- **Use Case**: Firebase project deployment and configuration
- **Modification**: Update when changing Firebase services

#### `firestore.rules`
- **Purpose**: Firestore database security rules
- **Contains**: Read/write permissions, user authentication rules
- **Use Case**: Database security and access control
- **Modification**: Update when changing data access policies

#### `firestore.indexes.json`
- **Purpose**: Firestore database indexes configuration
- **Contains**: Query optimization indexes
- **Use Case**: Database performance optimization
- **Modification**: Update when adding new query patterns

#### `.firebaserc`
- **Purpose**: Firebase project alias configuration
- **Contains**: Project ID and alias mappings
- **Use Case**: Firebase CLI project selection
- **Modification**: Update when changing Firebase projects

### 🔍 Analysis Configuration

#### `analysis_options.yaml`
- **Purpose**: Dart code analysis and linting rules
- **Contains**: Code quality rules, error suppression, custom rules
- **Use Case**: Code quality enforcement and consistency
- **Modification**: Update when changing code standards

## 🚀 Configuration Setup

### Firebase Setup

#### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project or select existing
3. Enable required services:
   - Authentication
   - Firestore Database
   - Storage
   - Cloud Messaging

#### 2. Configure Firebase
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in project
firebase init

# Select services and configure
```

#### 3. Update Configuration Files
```json
// firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

### Firestore Rules Configuration

#### Basic Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Messages require authentication
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### Advanced Rules with Role-Based Access
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Admin users have full access
    match /{document=**} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Regular users have limited access
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Analysis Options Configuration

#### Basic Analysis Rules
```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
    prefer_single_quotes: true
```

#### Custom Analysis Rules
```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"
  
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    # Custom rules for the project
    prefer_const_constructors: true
    avoid_unnecessary_containers: true
    sized_box_for_whitespace: true
```

## 🔧 Environment-Specific Configuration

### Development Environment
```bash
# .env.development
FIREBASE_PROJECT_ID=soc-chat-dev
FIREBASE_API_KEY=dev_api_key
FIREBASE_MESSAGING_SENDER_ID=dev_sender_id
```

### Production Environment
```bash
# .env.production
FIREBASE_PROJECT_ID=soc-chat-prod
FIREBASE_API_KEY=prod_api_key
FIREBASE_MESSAGING_SENDER_ID=prod_sender_id
```

### Staging Environment
```bash
# .env.staging
FIREBASE_PROJECT_ID=soc-chat-staging
FIREBASE_API_KEY=staging_api_key
FIREBASE_MESSAGING_SENDER_ID=staging_sender_id
```

## 📱 Platform-Specific Configuration

### Android Configuration
```gradle
// android/app/build.gradle
android {
    defaultConfig {
        applicationId "com.example.soc_chat_app"
        minSdkVersion 23
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.1"
    }
}
```

### iOS Configuration
```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos for chat messages.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to share images in chat.</string>
```

### Web Configuration
```html
<!-- web/index.html -->
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="theme-color" content="#2196F3">
    <link rel="manifest" href="manifest.json">
</head>
```

## 🔐 Security Configuration

### Firebase Security Rules
```javascript
// firestore.rules - Enhanced security
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User authentication check
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // User ownership check
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // Admin role check
    function isAdmin() {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Apply rules
    match /users/{userId} {
      allow read, write: if isAuthenticated() && (isOwner(userId) || isAdmin());
    }
    
    match /messages/{messageId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

### Storage Security Rules
```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can upload their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public read access for shared content
    match /public/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 🚀 Deployment Configuration

### Production Deployment
```bash
# Deploy Firebase configuration
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only hosting

# Deploy functions
firebase deploy --only functions
```

### Environment Switching
```bash
# Switch to production
firebase use production

# Switch to staging
firebase use staging

# Switch to development
firebase use development
```

## 🐛 Troubleshooting

### Common Configuration Issues

#### Firebase Connection Failed
1. Check `firebase.json` configuration
2. Verify `.firebaserc` project ID
3. Ensure Firebase CLI is logged in
4. Check network connectivity

#### Firestore Rules Errors
1. Validate rules syntax: `firebase deploy --only firestore:rules`
2. Check rule logic for circular references
3. Verify user authentication flow
4. Test rules in Firebase Console

#### Analysis Errors
1. Check `analysis_options.yaml` syntax
2. Verify linter rule names
3. Check for conflicting rules
4. Update Flutter SDK if needed

### Configuration Validation
```bash
# Validate Firebase configuration
firebase projects:list
firebase use --add

# Validate Firestore rules
firebase deploy --only firestore:rules --dry-run

# Validate analysis options
flutter analyze
```

## 📋 Configuration Maintenance

### Adding New Services
1. Update `firebase.json` with new service configuration
2. Add corresponding security rules
3. Update environment variables
4. Test configuration locally
5. Deploy to staging environment

### Updating Existing Configuration
1. Backup current configuration
2. Make incremental changes
3. Test in development environment
4. Deploy to staging for validation
5. Deploy to production

## 🔗 Related Documentation

- **[Firebase Integration](../docs/FIREBASE_INTEGRATION_COMPLETE.md)** - Complete Firebase setup guide
- **[Setup Guide](../docs/SETUP_GUIDE.md)** - Project setup instructions
- **[Production Readiness](../docs/PRODUCTION_READINESS.md)** - Production deployment guide
- **[Security Guide](../docs/SECURE_MESSAGE_SYSTEM.md)** - Security implementation details

## 📞 Support

For configuration issues:
1. Check the troubleshooting section above
2. Review [Firebase Integration](../docs/FIREBASE_INTEGRATION_COMPLETE.md)
3. Check [Setup Guide](../docs/SETUP_GUIDE.md)
4. Create an issue in the repository

---

**Note**: Always test configuration changes in development/staging before applying to production.
