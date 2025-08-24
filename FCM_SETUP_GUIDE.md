# 🔔 FCM Setup Guide for Push Notifications

## 🎯 **Overview**
This guide explains how to set up Firebase Cloud Messaging (FCM) to enable push notifications for broadcast messages and chat notifications.

## 🚀 **Step 1: Get FCM Server Key**

### **1. Go to Firebase Console**
- Visit: https://console.firebase.google.com/
- Select your project: `soc-chat-app-ca57e`

### **2. Navigate to Project Settings**
- Click the gear icon ⚙️ next to "Project Overview"
- Select "Project settings"

### **3. Go to Cloud Messaging Tab**
- Click on the "Cloud Messaging" tab
- Look for "Server key" section

### **4. Copy the Server Key**
- You'll see a long string starting with `AAAA...`
- This is your FCM Server Key
- **Copy this key** - you'll need it in the next step

## 🔧 **Step 2: Update the Code**

### **1. Open the Enhanced Notification Service**
- File: `lib/services/enhanced_notification_service.dart`
- Find line: `static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY';`

### **2. Replace the Placeholder**
```dart
// Change this line:
static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY';

// To your actual key:
static const String _fcmServerKey = 'AAAA...your_actual_key_here...';
```

## ✅ **Step 3: Test the System**

### **1. Test Broadcast Notifications**
1. Go to Admin Panel → Broadcast tab
2. Send a test broadcast message
3. Check if other users receive push notifications

### **2. Test Chat Notifications**
1. Send a message in a chat
2. Check if the recipient gets a push notification
3. Verify both individual and group chat notifications

## 🔍 **How It Works**

### **Broadcast Notifications**
1. Admin sends broadcast from admin panel
2. System gets all users with FCM tokens
3. Sends FCM push notification to each user
4. Creates notification document in Firestore
5. User receives push notification on device

### **Chat Notifications**
1. User sends message in chat
2. System identifies all recipients
3. Sends FCM push notification to each recipient
4. Creates notification document in Firestore
5. Recipients receive push notification

## 🚨 **Important Notes**

### **Security**
- **NEVER commit your FCM server key to version control**
- Keep it private and secure
- Consider using environment variables for production

### **Testing**
- Test on real devices (not just emulators)
- Ensure devices have internet connection
- Check notification permissions are granted

### **Platform Support**
- **Android**: Full support with notification channels
- **iOS**: Requires APNS setup (handled automatically)
- **Web**: Limited support (browser notifications)

## 🔧 **Troubleshooting**

### **Notifications Not Working?**
1. Check FCM server key is correct
2. Verify FCM tokens are saved in Firestore
3. Check device notification permissions
4. Ensure internet connection is available

### **Common Issues**
- **"FCM Server Key not configured"**: Update the key in the service
- **"No FCM tokens found"**: Users need to open the app first
- **"Permission denied"**: Check notification permissions on device

## 📱 **Expected Results**

### **After Setup:**
- ✅ Admin broadcasts send push notifications to all users
- ✅ Chat messages send push notifications to recipients
- ✅ Notifications appear on device lock screen
- ✅ Tapping notification opens the app
- ✅ Notification history stored in Firestore

### **User Experience:**
- **Lock Screen**: Notifications appear immediately
- **App Background**: Push notifications received
- **App Foreground**: Local notifications shown
- **Tapping**: Navigates to relevant screen

## 🎉 **Success Indicators**

When working correctly, you should see:
```
[EnhancedNotificationService] FCM notification sent successfully
[EnhancedNotificationService] Broadcast sent: X FCM success, Y notifications created
[EnhancedNotificationService] Chat notification sent to [userId]
```

## 🚀 **Next Steps**

1. **Set up FCM server key** (follow steps above)
2. **Test broadcast notifications** from admin panel
3. **Test chat notifications** by sending messages
4. **Monitor logs** for successful delivery
5. **Customize notification content** as needed

## 📞 **Need Help?**

If you encounter issues:
1. Check the console logs for error messages
2. Verify FCM server key is correct
3. Test on different devices/platforms
4. Check Firebase Console for delivery statistics

---

**Remember**: The FCM server key is the key to unlocking push notifications. Once configured, your users will receive instant notifications for all important messages! 🎯
