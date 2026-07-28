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
              final cred = await _auth.signInWithPopup(googleProvider);
              if (cred.user != null) {
                await _migrateMerchantData(anonUid, cred.user!.uid);
              }
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
              final cred = await _auth.signInWithCredential(credential);
              if (cred.user != null) {
                await _migrateMerchantData(anonUid, cred.user!.uid);
              }
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

  Future<void> _migrateMerchantData(String oldUid, String newUid) async {
    // 0. Migrate User Plan (Subscription)
    final oldUserDoc = await _firestore.collection('users').doc(oldUid).get();
    if (oldUserDoc.exists) {
      final oldData = oldUserDoc.data();
      if (oldData != null && oldData.containsKey('plan')) {
        await _firestore.collection('users').doc(newUid).set({
          'plan': oldData['plan'],
        }, SetOptions(merge: true));
      }
    }

    // 1. Root collections with 'merchantId'
    final rootCollections = ['products', 'orders', 'customers'];
    for (final collection in rootCollections) {
      final snapshot = await _firestore.collection(collection).where('merchantId', isEqualTo: oldUid).get();
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'merchantId': newUid});
        }
        await batch.commit();
      }
    }

    // 2. Subcollections under merchants/oldUid
    final subcollections = ['categories', 'expenses', 'inventory_logs', 'suppliers'];
    for (final sub in subcollections) {
      final snapshot = await _firestore.collection('merchants').doc(oldUid).collection(sub).get();
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          final newRef = _firestore.collection('merchants').doc(newUid).collection(sub).doc(doc.id);
          batch.set(newRef, doc.data());
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
  }

  Future<void> signUpWithEmail(String email, String password, String name) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception("No user logged in");
      
      if (currentUser.isAnonymous) {
        final anonUid = currentUser.uid;
        
        // Capture old user document before creating new user
        final oldUserDoc = await _firestore.collection('users').doc(anonUid).get();
        
        // This creates the user and signs them in automatically
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        final newUser = cred.user;
        
        if (newUser != null) {
          await newUser.updateDisplayName(name);
          await newUser.sendEmailVerification();
          
          // Migrate root collections
          await _migrateMerchantData(anonUid, newUser.uid);
          
          // Create the new user doc preserving the old data
          Map<String, dynamic> newUserData = {
            'isAnonymous': false,
            'email': email,
            'name': name,
            'id': newUser.uid,
            'createdAt': DateTime.now(),
          };
          
          if (oldUserDoc.exists && oldUserDoc.data() != null) {
            newUserData['plan'] = oldUserDoc.data()!['plan'];
            newUserData['deviceId'] = oldUserDoc.data()!['deviceId'];
            // Merge any other fields if necessary
          }
          
          await _firestore.collection('users').doc(newUser.uid).set(newUserData, SetOptions(merge: true));
          
          // Delete anon user doc
          await _firestore.collection('users').doc(anonUid).delete();
        }
      } else {
        throw Exception("أنت مسجل الدخول بالفعل");
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء إنشاء الحساب: $e");
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      final currentUser = _auth.currentUser;
      String? anonUid;
      
      if (currentUser != null && currentUser.isAnonymous) {
        anonUid = currentUser.uid;
      }
      
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (anonUid != null && cred.user != null) {
        await _migrateMerchantData(anonUid, cred.user!.uid);
        await _firestore.collection('users').doc(anonUid).delete();
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء تسجيل الدخول: $e");
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
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
      return AppUser.fromJson(snapshot.data()!);
    }
    return null;
  });
}
