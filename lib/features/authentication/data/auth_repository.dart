import 'package:tajer/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../domain/app_user.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String> _getDeviceId() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      String? webId = prefs.getString('web_device_id');
      if (webId == null) {
        webId = const Uuid().v4();
        await prefs.setString('web_device_id', webId);
      }
      return webId;
    }
    
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique ID for Android device
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? const Uuid().v4(); // Unique ID for iOS device
    }
    return const Uuid().v4();
  }

  Future<AppUser> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user == null) {
        throw Exception("فشل تسجيل الدخول كمجهول");
      }

      // Check if user exists in Firestore, if not create them
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        final deviceId = await _getDeviceId();
        
        // Anti-Abuse: Check if this device was already used by another free account
        final deviceRegistryRef = _firestore.collection('device_registry').doc(deviceId);
        final deviceDoc = await deviceRegistryRef.get();
        
        String assignedPlan = 'guest';
        
        if (deviceDoc.exists) {
          // Device has been used before, prevent new free account from getting limits
          assignedPlan = 'banned_device';
        } else {
          // Register this device
          await deviceRegistryRef.set({
            'firstUsedBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final appUser = AppUser(
          id: user.uid,
          createdAt: DateTime.now(),
          isAnonymous: true,
          plan: assignedPlan,
          deviceId: deviceId,
        );
        await docRef.set(appUser.toJson());
        return appUser;
      } else {
        return AppUser.fromJson(docSnap.data()!);
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء المصادقة: $e");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> linkWithGoogle() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (kIsWeb) {
        // Use Firebase Auth's built-in Web popup for Google Sign-In
        final googleProvider = GoogleAuthProvider();
        
        if (currentUser.isAnonymous) {
          try {
            await currentUser.linkWithPopup(googleProvider);
            // Successfully linked! Update Firestore user document
            await _firestore.collection('users').doc(currentUser.uid).update({
              'isAnonymous': false,
              'email': _auth.currentUser?.email,
              'name': _auth.currentUser?.displayName,
            });
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use') {
              // The Google account is already linked. Sign in with it.
              final anonUid = currentUser.uid;
              await _auth.signInWithPopup(googleProvider);
              await _firestore.collection('users').doc(anonUid).delete();
            } else {
              rethrow;
            }
          }
        } else {
          await _auth.signInWithPopup(googleProvider);
        }
      } else {
        // Native platforms (Android/iOS)
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return; // User canceled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        if (currentUser.isAnonymous) {
          try {
            await currentUser.linkWithCredential(credential);
            // Successfully linked! Update Firestore user document
            await _firestore.collection('users').doc(currentUser.uid).update({
              'isAnonymous': false,
              'email': googleUser.email,
              'name': googleUser.displayName,
            });
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use') {
              final anonUid = currentUser.uid;
              await _auth.signInWithCredential(credential);
              await _firestore.collection('users').doc(anonUid).delete();
            } else {
              rethrow;
            }
          }
        } else {
          // If not anonymous, just sign in
          await _auth.signInWithCredential(credential);
        }
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء الربط بحساب جوجل: $e");
    }
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);
}

@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

@riverpod
Stream<AppUser?> appUser(AppUserRef ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      return AppUser.fromJson(snapshot.data()!);
    }
    return null;
  });
}
