# macOS Setup Instructions for iOS Build

After pulling the code from git, follow these steps to set up and build for iOS:

## Step 1: Update Twilio Credentials

The `.env` file is not committed to git for security. You need to set up Twilio credentials:

### Option A: Use the Shell Script (Recommended)
```bash
cd servers/local_api_server
chmod +x SET_TWILIO_CREDENTIALS.sh
./SET_TWILIO_CREDENTIALS.sh
```

### Option B: Manually Create/Update .env File
```bash
cd servers/local_api_server
nano .env  # or use your preferred editor
```

Add these lines:
```
TWILIO_ACCOUNT_SID=ACbd7662379a26ed6cde62bfbc8a9a998e
TWILIO_AUTH_TOKEN=452e23b1ce6dcae1b9eaf4cb92ae3b4a
CLOUD_TURN_ENABLED=true
CLOUD_TURN_USERNAME=ACbd7662379a26ed6cde62bfbc8a9a998e
CLOUD_TURN_PASSWORD=452e23b1ce6dcae1b9eaf4cb92ae3b4a
CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp
```

## Step 2: Install Dependencies

```bash
# Install Flutter dependencies
flutter pub get

# Install Node.js dependencies (if not already installed)
cd servers/local_api_server
npm install
```

## Step 3: Set Up iOS Development

### Prerequisites:
- Xcode installed (from App Store)
- Xcode Command Line Tools: `xcode-select --install`
- CocoaPods installed: `sudo gem install cocoapods`

### Configure iOS:
```bash
# Navigate to iOS directory
cd ios

# Install CocoaPods dependencies
pod install

# Go back to project root
cd ..
```

## Step 4: Configure Signing (Required for Device Testing)

1. Open the project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select the `Runner` project in the left sidebar
   - Select the `Runner` target
   - Go to "Signing & Capabilities" tab
   - Select your Apple Developer Team
   - Xcode will automatically manage signing

## Step 5: Build for iOS

### For Simulator:
```bash
flutter build ios --simulator
```

### For Physical Device (Release):
```bash
flutter build ios --release
```

### For Physical Device (Debug):
```bash
flutter run --release
```

## Step 6: Run the App

### On Simulator:
```bash
flutter run
```

### On Connected iPhone:
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

## Step 7: Start the API Server (Required for App to Work)

```bash
cd servers/local_api_server
node server.js
```

The server will:
- Load Twilio credentials from `.env`
- Start on the configured port (usually 3000)
- Provide TURN configuration for cross-network calls

## Troubleshooting

### If CocoaPods installation fails:
```bash
sudo gem install cocoapods
pod repo update
cd ios && pod install && cd ..
```

### If signing errors occur:
- Make sure you have an Apple Developer account
- Check that your Team is selected in Xcode
- Verify certificates in Keychain Access

### If build fails:
```bash
# Clean build
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios
```

### If TURN server doesn't work:
- Verify `.env` file exists and has correct credentials
- Check server logs for Twilio API errors
- Ensure API server is running before testing calls

## Verification Checklist

- [ ] Twilio credentials set in `.env` file
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] CocoaPods installed and dependencies updated (`pod install`)
- [ ] Xcode signing configured
- [ ] API server running with correct credentials
- [ ] iOS build successful
- [ ] App runs on device/simulator

## Next Steps

1. Test the app on iOS device/simulator
2. Test cross-network calls (one device on WiFi, other on cellular)
3. Verify media streams work correctly
4. Check logs for TURN configuration and RELAY candidates

