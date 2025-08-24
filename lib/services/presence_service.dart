import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _setOnline(false);
    }
  }

  void _setOnline(bool online) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    if (online) {
      await ref.update({'isOnline': true});
    } else {
      await ref.update({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()});
    }
  }
} 