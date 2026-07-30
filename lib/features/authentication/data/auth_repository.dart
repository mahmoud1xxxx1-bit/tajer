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
import '../../../core/services/data_migration_service.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  AuthCredential? _pendingCredential;

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
          final data = deviceDoc.data();
          int usageCount = 1;
          if (data != null && data.containsKey('usageCount')) {
            usageCount = (data['usageCount'] as num).toInt();
          }
          
          if (usageCount >= 3) {
            assignedPlan = 'banned_device';
          }
          
          // Update device registry with new usage
          await deviceRegistryRef.update({
            'usageCount': FieldValue.increment(1),
            'users': FieldValue.arrayUnion([user.uid])
          });
        } else {
          // Register this device for the first time
          await deviceRegistryRef.set({
            'usageCount': 1,
            'users': [user.uid],
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
        final data = docSnap.data()!;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return AppUser.fromJson(data);
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء المصادقة: $e");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> signInOrLinkWithGoogle() async {
    try {
      final currentUser = _auth.currentUser;

      if (kIsWeb) {
        // Use Firebase Auth's built-in Web popup for Google Sign-In
        final googleProvider = GoogleAuthProvider();
        
        if (currentUser?.isAnonymous == true) {
          try {
            await currentUser!.linkWithPopup(googleProvider);
            // Successfully linked! Update Firestore user document
            await _firestore.collection('users').doc(currentUser.uid).update({
              'isAnonymous': false,
              'email': _auth.currentUser?.email,
              'name': _auth.currentUser?.displayName,
            });
            } on FirebaseAuthException catch (e) {
              if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
                // We need to fetch the credential from the popup, but it's tricky on web if it throws.
                // However, on web linkWithPopup throws but might attach credential in error.
                // For simplicity, we just throw requires-merge-decision. We will handle web merge differently or prompt them.
                throw Exception('requires-merge-decision-web');
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

        if (currentUser?.isAnonymous == true) {
          try {
            await currentUser!.linkWithCredential(credential);
            // Successfully linked! Update Firestore user document
            await _firestore.collection('users').doc(currentUser.uid).update({
              'isAnonymous': false,
              'email': googleUser.email,
              'name': googleUser.displayName,
            });
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
              _pendingCredential = credential;
              throw Exception('requires-merge-decision');
            } else {
              throw Exception(e.message ?? "حدث خطأ غير معروف");
            }
          }
        } else {
          // If not anonymous, just sign in directly
          await _auth.signInWithCredential(credential);
        }
      }
    } catch (e) {
      if (e.toString().contains('requires-merge-decision')) rethrow;
      throw Exception("حدث خطأ أثناء المصادقة بحساب جوجل: $e");
    }
  }

  Future<void> resolveMerge(bool merge, DataMigrationService migrationService) async {
    if (_pendingCredential == null) throw Exception("لا توجد بيانات اعتماد معلقة");
    
    final anonUid = _auth.currentUser?.uid;
    
    // Sign in with the pending credential
    final userCred = await _auth.signInWithCredential(_pendingCredential!);
    _pendingCredential = null;
    
    if (merge && anonUid != null && userCred.user != null) {
      final newUid = userCred.user!.uid;
      await migrationService.migrateData(anonUid, newUid);
    }
  }

  Future<void> resolveMergeWeb(bool merge, DataMigrationService migrationService) async {
    final anonUid = _auth.currentUser?.uid;
    final googleProvider = GoogleAuthProvider();
    final userCred = await _auth.signInWithPopup(googleProvider);
    
    if (merge && anonUid != null && userCred.user != null) {
      final newUid = userCred.user!.uid;
      await migrationService.migrateData(anonUid, newUid);
    }
  }


  Future<void> signUpWithEmail(String email, String password, String name) async {
    try {
      final processedEmail = email.trim().toLowerCase();
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception("No user logged in");
      
      if (currentUser.isAnonymous) {
        final anonUid = currentUser.uid;
        
        final credential = EmailAuthProvider.credential(email: processedEmail, password: password);
        final userCredential = await currentUser.linkWithCredential(credential);
        final newUser = userCredential.user;
        
        if (newUser != null) {
          await newUser.updateDisplayName(name);
          await newUser.sendEmailVerification();
          
          await _firestore.collection('users').doc(anonUid).set({
            'isAnonymous': false,
            'email': processedEmail,
            'name': name,
          }, SetOptions(merge: true));

          // Force logout so user cannot bypass email verification
          await _auth.signOut();
        }
      } else {
        throw Exception("أنت مسجل الدخول بالفعل");
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        throw Exception("هذا البريد الإلكتروني مستخدم بالفعل، يرجى تسجيل الدخول بدلاً من إنشاء حساب جديد");
      }
      throw Exception(e.message ?? "حدث خطأ غير معروف");
    } catch (e) {
      throw Exception("حدث خطأ أثناء إنشاء الحساب: $e");
    }
  }

  Future<void> signInWithEmail(String email, String password, {bool mergeData = false, DataMigrationService? migrationService}) async {
    try {
      final processedEmail = email.trim().toLowerCase();
      final anonUid = _auth.currentUser?.isAnonymous == true ? _auth.currentUser!.uid : null;
      final userCred = await _auth.signInWithEmailAndPassword(email: processedEmail, password: password);
      
      // Check if email is verified
      if (userCred.user != null && !userCred.user!.emailVerified) {
        await _auth.signOut();
        throw Exception("email-not-verified");
      }

      if (mergeData && anonUid != null && migrationService != null && userCred.user != null) {
        await migrationService.migrateData(anonUid, userCred.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception("البريد الإلكتروني أو كلمة المرور غير صحيحة");
      }
      throw Exception(e.message ?? "حدث خطأ أثناء تسجيل الدخول");
    } catch (e) {
      if (e.toString().contains("email-not-verified")) rethrow;
      throw Exception("حدث خطأ أثناء تسجيل الدخول: $e");
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      final processedEmail = email.trim().toLowerCase();
      final userDoc = await _firestore.collection('users').where('email', isEqualTo: processedEmail).get();
      if (userDoc.docs.isEmpty) {
        throw Exception("هذا البريد الإلكتروني غير مسجل لدينا.");
      }
      await _auth.sendPasswordResetEmail(email: processedEmail);
    } catch (e) {
      if (e.toString().contains("غير مسجل")) rethrow;
      throw Exception("حدث خطأ أثناء إرسال رابط استعادة كلمة المرور: $e");
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw Exception("حدث خطأ أثناء إرسال رابط التفعيل: $e");
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
      final data = snapshot.data()!;
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      return AppUser.fromJson(data);
    }
    return null;
  });
}
