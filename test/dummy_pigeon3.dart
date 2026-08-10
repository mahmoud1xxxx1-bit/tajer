import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class MockFirebaseCore extends FirebaseCorePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FirebaseAppPlatform(
      name: name ?? '[DEFAULT]',
      options: options ?? const FirebaseOptions(
        apiKey: '123',
        appId: '123',
        messagingSenderId: '123',
        projectId: '123',
      ),
    );
  }

  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) {
    return FirebaseAppPlatform(
      name: name,
      options: const FirebaseOptions(
        apiKey: '123',
        appId: '123',
        messagingSenderId: '123',
        projectId: '123',
      ),
    );
  }
}

void main() {
  test('Mock core', () async {
    WidgetsFlutterBinding.ensureInitialized();
    FirebaseCorePlatform.instance = MockFirebaseCore();
    await Firebase.initializeApp();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print(uid);
  });
}
