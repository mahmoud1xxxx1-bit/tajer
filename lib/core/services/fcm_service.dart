import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static bool _initialized = false;
  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;

  static Future<void> initialize({
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        onForegroundMessage?.call(message);
      });

      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onNotificationTap?.call(message);
      });

      _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
        unawaited(saveTokenToDatabase(token));
      });

      // Keep notification identity synchronized whenever authentication changes.
      // This covers first login/sign-up as well as an already-authenticated user.
      _authSubscription = _auth.authStateChanges().listen((user) {
        if (user != null && !user.isAnonymous) {
          unawaited(syncForCurrentUser());
        }
      });

      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Last-seen must not depend on notification permission or token retrieval.
      await _updateLastSeen();

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _syncToken();
      }

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        onNotificationTap?.call(initialMessage);
      }
    } catch (e) {
      // FCM is an optional service and must never block or crash app startup.
      if (kDebugMode) {
        print('Error initializing FCM: $e');
      }
    }
  }

  static Future<void> syncForCurrentUser() async {
    try {
      await _updateLastSeen();

      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _syncToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing FCM user state: $e');
      }
    }
  }

  static Future<void> _syncToken() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await saveTokenToDatabase(token);
    }
  }

  static Future<void> _updateLastSeen() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('Error updating last seen: $e');
      }
    }
  }

  static Future<void> saveTokenToDatabase(String token) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }
}
