# SOC Chat App - MongoDB Edition

A modern, cross-platform chat application built with Flutter and MongoDB. This app provides real-time messaging, group chats, user management, and admin functionality without any Firebase dependencies.

## 🚀 Features

### Core Features
- **Real-time Messaging**: Instant messaging with MongoDB backend
- **Group Chats**: Create and manage group conversations
- **User Search**: Find and connect with other users
- **Admin Panel**: Comprehensive user and system management
- **Cross-Platform**: Works on Web, Android, and iOS
- **Media Sharing**: Send images, videos, and files
- **Offline Support**: Local message storage and sync

### Technical Features
- **MongoDB Backend**: No Firebase/Firestore dependencies
- **JWT Authentication**: Secure token-based authentication
- **RESTful API**: Clean API design with Express.js
- **Rate Limiting**: Built-in protection against abuse
- **CORS Support**: Cross-origin resource sharing
- **Local Network Access**: Works on local networks
- **ngrok Integration**: Public tunnel access for mobile testing

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Express API    │    │    MongoDB      │
│                 │    │                 │    │                 │
│ • Web (8082)    │◄──►│ • REST API      │◄──►│ • User Data     │
│ • Android       │    │ • JWT Auth       │    │ • Chat Data     │
│ • iOS           │    │ • Rate Limiting  │    │ • Messages      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

- **Flutter SDK** (3.0+)
- **Node.js** (16+)
- **MongoDB** (4.4+)
- **Git**
- **ngrok** (for mobile testing)

## 🛠️ Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/soc-chat-app-mongodb.git
cd soc-chat-app-mongodb
```

### 2. Backend Setup

#### Install Dependencies
```bash
cd servers
npm install
```

#### Configure Environment
```bash
cp env.example .env
```

Edit `.env` file:
```env
PORT=3003
MONGO_URI=mongodb://localhost:27017/soc_chat_app
JWT_SECRET=your_jwt_secret_here
```

#### Start MongoDB
```bash
# Windows
mongod --dbpath "C:\data\db"

# macOS/Linux
mongod
```

#### Start API Server
```bash
npm start
```

### 3. Frontend Setup

#### Install Flutter Dependencies
```bash
flutter pub get
```

#### Configure Database Connection
Edit `lib/config/database_config.dart`:
```dart
static const String webServerUrl = 'http://your-server-ip:3003';
static const String mobileServerUrl = 'https://your-ngrok-url.ngrok-free.app';
```

#### Build and Run

**Web:**
```bash
flutter build web --release
cd build/web
python -m http.server 8082 --bind 0.0.0.0
```

**Android:**
```bash
flutter build apk --release
flutter install --device-id=your-device-id
```

**iOS:**
```bash
flutter build ios --release
flutter install --device-id=your-device-id
```

## 🚀 Quick Start

### Using Batch Scripts (Windows)

1. **Start All Services:**
```bash
.\start_all_services.bat
```

2. **Access the App:**
- Web: `http://localhost:8082`
- Mobile: Install APK on device

### Manual Setup

1. **Start MongoDB:**
```bash
mongod
```

2. **Start API Server:**
```bash
cd servers
npm start
```

3. **Start Web Server:**
```bash
flutter build web --release
cd build/web
python -m http.server 8082
```

4. **Access the App:**
- Web: `http://localhost:8082`
- API: `http://localhost:3003`

## 📱 Mobile Testing with ngrok

### Setup ngrok
```bash
# Install ngrok
# Download from https://ngrok.com/

# Start tunnel
ngrok http 3003
```

### Update Mobile Configuration
```dart
// In lib/config/database_config.dart
static const String mobileServerUrl = 'https://your-ngrok-url.ngrok-free.app';
```

### Build Mobile App
```bash
flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://your-ngrok-url.ngrok-free.app
```

## 🔧 Configuration

### Database Configuration
```dart
// lib/config/database_config.dart
class DatabaseConfig {
  static const bool usePhysicalServer = true;
  static const String webServerUrl = 'http://localhost:3003';
  static const String mobileServerUrl = 'https://your-ngrok-url.ngrok-free.app';
}
```

### Server Configuration
```javascript
// servers/server.js
const config = {
  port: process.env.PORT || 3003,
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app',
  jwtSecret: process.env.JWT_SECRET || 'your_jwt_secret_here'
};
```

## 📊 API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `GET /api/auth/verify` - Verify token

### Users
- `GET /api/users` - Get all users (for search)
- `GET /api/users/:id` - Get specific user
- `PUT /api/users/:id/status` - Update user status

### Chats
- `GET /api/chats` - Get user chats
- `POST /api/chats` - Create new chat
- `GET /api/chats/:id/messages` - Get chat messages
- `POST /api/chats/:id/messages` - Send message

### Admin
- `GET /api/admin/users` - Get all users (admin)
- `DELETE /api/admin/users/:id` - Delete user (admin)
- `POST /api/admin/broadcast` - Send broadcast message

## 🗄️ Database Schema

### Users Collection
```javascript
{
  _id: ObjectId,
  email: String,
  password: String, // hashed
  displayName: String,
  username: String,
  role: String, // 'user' or 'admin'
  status: String, // 'online', 'offline', 'away'
  createdAt: Date,
  updatedAt: Date
}
```

### Chats Collection
```javascript
{
  _id: ObjectId,
  type: String, // 'private' or 'group'
  name: String,
  members: [String], // user IDs
  createdBy: String, // user ID
  createdAt: Date,
  updatedAt: Date
}
```

### Messages Collection
```javascript
{
  _id: ObjectId,
  chatId: ObjectId,
  senderId: String, // user ID
  content: String,
  messageType: String, // 'text', 'image', 'video', 'file'
  mediaUrl: String, // optional
  timestamp: Date,
  readBy: [String] // user IDs who read the message
}
```

## 🔒 Security Features

- **JWT Authentication**: Secure token-based authentication
- **Password Hashing**: bcrypt password encryption
- **Rate Limiting**: Protection against abuse
- **CORS Configuration**: Secure cross-origin requests
- **Input Validation**: Sanitized user inputs
- **Error Handling**: Secure error responses

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### API Tests
```bash
cd servers
npm test
```

## 📦 Deployment

### Docker Deployment
```bash
# Build Docker image
docker build -t soc-chat-app .

# Run with Docker Compose
docker-compose up -d
```

### Production Deployment
1. Set up MongoDB cluster
2. Configure environment variables
3. Deploy API server
4. Build and deploy Flutter web app
5. Configure CDN for static assets

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/yourusername/soc-chat-app-mongodb/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/soc-chat-app-mongodb/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/soc-chat-app-mongodb/discussions)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- MongoDB for the database
- Express.js for the API framework
- All contributors and testers

---

**Made with ❤️ using Flutter and MongoDB**
