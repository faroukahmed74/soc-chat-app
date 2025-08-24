# SOC Chat App

A comprehensive, cross-platform chat application built with Flutter that supports web, Android, and iOS platforms.

## 🌟 Features

### Core Functionality
- **Real-time Chat**: Instant messaging with real-time updates
- **Group Chats**: Create and manage group conversations
- **Media Sharing**: Send images, documents, and voice messages
- **User Management**: User profiles, friend requests, and blocking
- **Cross-platform**: Works on web, Android, and iOS

### Advanced Features
- **Account Locking**: Admin-controlled user account management
- **Message Encryption**: Secure group chat encryption
- **Admin Panel**: Comprehensive administrative tools
- **Theme Support**: Light and dark mode
- **Multi-language**: English and Arabic support
- **Responsive Design**: Adapts to all screen sizes

### Platform Support
- **Web**: Full functionality with web APIs
- **Android**: Native mobile experience (API 23+)
- **iOS**: Native mobile experience (iOS 13.0+)

## 🏗️ Architecture

### Service Layer
- **UnifiedMediaService**: Cross-platform media handling
- **ThemeService**: Theme and language management
- **LocalizationService**: Internationalization support
- **AdminGroupService**: Administrative functions
- **PresenceService**: Online/offline status tracking

### Data Layer
- **Firebase Authentication**: User management
- **Cloud Firestore**: Real-time database
- **Firebase Storage**: Media file storage
- **Firebase Messaging**: Push notifications

### UI Layer
- **Responsive Design**: Adapts to all screen sizes
- **Material Design 3**: Modern UI components
- **Theme Switching**: Dynamic theme changes
- **Localization**: RTL support for Arabic

## 📱 Screens

### Authentication
- **LoginScreen**: User authentication with account locking detection
- **RegisterScreen**: New user registration with profile picture upload

### Main App
- **ChatListScreen**: List of all conversations with search
- **ChatScreen**: Individual chat interface with media support
- **ProfileScreen**: User profile management
- **SettingsScreen**: App configuration and preferences

### Admin Features
- **AdminPanelScreen**: Comprehensive administrative interface
- **UserSearchScreen**: Find and interact with users
- **CreateGroupScreen**: Group creation and management

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Firebase project setup
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd soc_chat_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Download `firebase_options.dart`
   - Enable Authentication, Firestore, and Storage

4. **Run the app**
   ```bash
   # Web
   flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
   
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   ```

## 🔧 Configuration

### Web Configuration
The web app includes:
- Custom favicon and app icons
- Progressive Web App (PWA) support
- Responsive design for all screen sizes
- Web-specific media handling

### Mobile Configuration
Mobile apps include:
- Native permissions handling
- Platform-specific media services
- Push notification support
- Background service management

### Environment Variables
Create a `.env` file with:
```
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
```

## 📊 Admin Features

### User Management
- View all users
- Lock/unlock accounts
- Delete user accounts
- Monitor user activity

### System Monitoring
- Real-time statistics
- System health checks
- Performance metrics
- Error logging

### Content Moderation
- Message monitoring
- User reporting
- Content filtering
- Automated moderation

## 🌐 Web Features

### Progressive Web App
- Installable on desktop and mobile
- Offline functionality
- Push notifications
- App-like experience

### Responsive Design
- Mobile-first approach
- Adaptive layouts
- Touch-friendly interface
- Cross-browser compatibility

### Media Handling
- Web camera access
- File upload support
- Image processing
- Audio recording

## 📱 Mobile Features

### Native Integration
- Camera and gallery access
- Push notifications
- Background processing
- Device-specific optimizations

### Permissions
- Camera access
- Photo library access
- Microphone access
- Notification permissions

## 🎨 Theming

### Light Theme
- Clean, modern design
- Blue accent colors
- High contrast text
- Subtle shadows

### Dark Theme
- Dark backgrounds
- Consistent color scheme
- Reduced eye strain
- Modern aesthetics

### Language Support
- English (LTR)
- Arabic (RTL)
- Dynamic switching
- Localized content

## 🔒 Security

### Authentication
- Firebase Authentication
- Email/password login
- Account locking
- Session management

### Data Protection
- Group chat encryption
- Secure file storage
- User privacy controls
- Admin oversight

## 📈 Performance

### Optimization
- Lazy loading
- Image compression
- Efficient queries
- Background processing

### Monitoring
- Performance metrics
- Error tracking
- User analytics
- System health

## 🧪 Testing

### Platform Testing
- Web browser testing
- Android device testing
- iOS device testing
- Cross-platform validation

### Feature Testing
- Authentication flow
- Chat functionality
- Media handling
- Admin features

## 🚀 Deployment

### Web Deployment
1. Build the web app
   ```bash
   flutter build web
   ```
2. Deploy to hosting service
3. Configure custom domain
4. Set up SSL certificate

### Mobile Deployment
1. Build release versions
   ```bash
   flutter build apk --release
   flutter build ios --release
   ```
2. Upload to app stores
3. Configure app signing
4. Set up distribution

## 📚 Documentation

### Code Structure
- Comprehensive comments
- Function documentation
- Architecture overview
- Service descriptions

### API Reference
- Service interfaces
- Method signatures
- Parameter descriptions
- Return values

### User Guide
- Feature explanations
- Usage instructions
- Troubleshooting
- FAQ section

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create feature branch
3. Make changes
4. Add tests
5. Submit pull request

### Code Standards
- Follow Flutter conventions
- Add comprehensive comments
- Include error handling
- Write unit tests

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Community contributors
- Beta testers and users

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Contact the development team
- Check the documentation
- Review the FAQ section

## 🔄 Version History

### v1.0.0
- Initial release
- Core chat functionality
- Cross-platform support
- Basic admin features

### v1.1.0
- Enhanced admin panel
- Account locking system
- Theme and language support
- Responsive design improvements

### v1.2.0
- Advanced media handling
- Improved security
- Performance optimizations
- Enhanced user experience

---

**SOC Chat App** - Secure, cross-platform messaging for everyone.
