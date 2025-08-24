import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebAutoRefreshService {
  static final WebAutoRefreshService _instance = WebAutoRefreshService._internal();
  factory WebAutoRefreshService() => _instance;
  WebAutoRefreshService._internal();

  Timer? _refreshTimer;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentChatId;

  // Initialize the auto-refresh service
  void initialize() {
    if (!kIsWeb || _isInitialized) return;
    
    print('WebAutoRefreshService: Initializing auto-refresh for web...');
    
    // Set up periodic refresh timer (every 5 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _performAutoRefresh();
    });

    // Listen for user authentication changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUserId = user.uid;
        _setupRealTimeListeners();
      } else {
        _currentUserId = null;
        _cleanupRealTimeListeners();
      }
    });

    // Set up visibility change listener for better performance
    html.document.addEventListener('visibilitychange', (event) {
      if (html.document.visibilityState == 'visible') {
        print('WebAutoRefreshService: Page became visible, refreshing...');
        _performAutoRefresh();
      }
    });

    // Set up focus listener for when user returns to tab
    html.window.addEventListener('focus', (event) {
      print('WebAutoRefreshService: Tab focused, refreshing...');
      _performAutoRefresh();
    });

    _isInitialized = true;
    print('WebAutoRefreshService: Auto-refresh initialized successfully');
  }

  // Set current chat ID for targeted refresh
  void setCurrentChat(String chatId) {
    _currentChatId = chatId;
    print('WebAutoRefreshService: Current chat set to: $chatId');
  }

  // Set up real-time listeners for various collections
  void _setupRealTimeListeners() {
    if (_currentUserId == null) return;

    print('WebAutoRefreshService: Setting up real-time listeners...');

    // Listen for new messages in all user's chats
    _chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      print('WebAutoRefreshService: Chats updated, triggering refresh...');
      _triggerRefresh();
    });

    // Listen for new users (for admin panel and user lists)
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      print('WebAutoRefreshService: Users updated, triggering refresh...');
      _triggerRefresh();
    });

    // Listen for new notifications
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
      print('WebAutoRefreshService: Notifications updated, triggering refresh...');
      _triggerRefresh();
    });
  }

  // Clean up real-time listeners
  void _cleanupRealTimeListeners() {
    _messagesSubscription?.cancel();
    _usersSubscription?.cancel();
    _chatsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    
    _messagesSubscription = null;
    _usersSubscription = null;
    _chatsSubscription = null;
    _notificationsSubscription = null;
    
    print('WebAutoRefreshService: Real-time listeners cleaned up');
  }

  // Perform the actual auto-refresh
  void _performAutoRefresh() {
    if (!kIsWeb) return;
    
    try {
      // Force a rebuild of the current page
      _triggerRefresh();
      
      // Update last seen timestamp
      if (_currentUserId != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }
      
      print('WebAutoRefreshService: Auto-refresh completed successfully');
    } catch (e) {
      print('WebAutoRefreshService: Error during auto-refresh: $e');
    }
  }

  // Trigger a refresh by dispatching a custom event
  void _triggerRefresh() {
    if (!kIsWeb) return;
    
    // Dispatch a custom event that Flutter can listen to
    final event = html.CustomEvent('flutterRefresh');
    html.document.dispatchEvent(event);
    
    print('WebAutoRefreshService: Refresh event dispatched');
  }

  // Manual refresh trigger
  void manualRefresh() {
    print('WebAutoRefreshService: Manual refresh triggered');
    _performAutoRefresh();
  }

  // Get refresh status
  bool get isInitialized => _isInitialized;
  bool get isActive => _refreshTimer != null && _refreshTimer!.isActive;

  // Dispose the service
  void dispose() {
    _refreshTimer?.cancel();
    _cleanupRealTimeListeners();
    _isInitialized = false;
    print('WebAutoRefreshService: Service disposed');
  }
}

