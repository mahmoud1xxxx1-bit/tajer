import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCYLpEIYZU1uuKZXxKBz7sa0Xk-cicnQ7Y',
    appId: '1:88663100884:web:0913563caf37cfd6a09a41',
    messagingSenderId: '88663100884',
    projectId: 'tajer-19289',
    authDomain: 'tajer-19289.firebaseapp.com',
    storageBucket: 'tajer-19289.firebasestorage.app',
    measurementId: 'G-N08GHPYTXV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB-h92OvXNt-sAalPSSIcjHKlU72hZX3O4',
    appId: '1:88663100884:android:a6b808c88855fb2ea09a41',
    messagingSenderId: '88663100884',
    projectId: 'tajer-19289',
    storageBucket: 'tajer-19289.firebasestorage.app',
  );
}
