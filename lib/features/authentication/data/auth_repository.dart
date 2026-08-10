import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/app_failure.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../domain/app_user.dart';
import '../../../core/services/data_migration_service.dart';
import '../../../core/providers/effective_merchant.dart';

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
        webId = Uuid().v4();
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
      return iosInfo.identifierForVendor ??
          Uuid().v4(); // Unique ID for iOS device
    }
    return Uuid().v4();
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
        final deviceRegistryRef =
            _firestore.collection('device_registry').doc(deviceId);
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
        if (data['createdAt'] != null) {
          data['createdAt'] =
              safeParseDate(data['createdAt']).toIso8601String();
        }
        return AppUser.fromJson(data);
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء المصادقة: $e");
    }
  }

  Future<void> signOut() async {
    final oldUid = _auth.currentUser?.uid;
    debugPrint('LOGOUT oldUid=$oldUid');
    _pendingCredential = null;
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('LOGOUT googleSignOutError=${e.runtimeType}');
    }
    await _auth.signOut();
    debugPrint('LOGOUT firebaseUidAfterLogout=${_auth.currentUser?.uid}');
  }

  Future<void> _ensureUserDocument(User user,
      {String? email, String? name}) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      final deviceId = await _getDeviceId();
      final appUser = AppUser(
        id: user.uid,
        createdAt: DateTime.now(),
        isAnonymous: false,
        plan: 'merchant',
        deviceId: deviceId,
        email: email,
        name: name,
      );
      await docRef.set(appUser.toJson());
    } else {
      // Just update email and name if needed
      await docRef.update({
        'isAnonymous': false,
        'email': email ?? docSnap.data()?['email'],
        'name': name ?? docSnap.data()?['name'],
      });
    }
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
            if (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use') {
              // We need to fetch the credential from the popup, but it's tricky on web if it throws.
              // However, on web linkWithPopup throws but might attach credential in error.
              // For simplicity, we just throw requires-merge-decision. We will handle web merge differently or prompt them.
              throw Exception('requires-merge-decision-web');
            } else {
              rethrow;
            }
          }
        } else {
          final userCred = await _auth.signInWithPopup(googleProvider);
          if (userCred.user != null) {
            await _ensureUserDocument(userCred.user!,
                email: userCred.user!.email, name: userCred.user!.displayName);
          }
        }
      } else {
        // Native platforms (Android/iOS)
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (currentUser?.isAnonymous != true) {
          try {
            await googleSignIn.signOut();
          } catch (e) {
            debugPrint('GOOGLE_LOGIN providerSignOutError=${e.runtimeType}');
          }
        }
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return; // User canceled

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
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
            if (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use') {
              _pendingCredential = credential;
              throw Exception('requires-merge-decision');
            } else {
              throw Exception(e.message ?? "حدث خطأ غير معروف");
            }
          }
        } else {
          // If not anonymous, just sign in directly
          final userCred = await _auth.signInWithCredential(credential);
          final providerIds = userCred.user?.providerData
                  .map((info) => info.providerId)
                  .join(',') ??
              '';
          debugPrint(
              'GOOGLE_AUTH_RESULT googleEmail=${googleUser.email} firebaseUid=${userCred.user?.uid} providerIds=$providerIds');
          if (userCred.user != null) {
            await _ensureUserDocument(userCred.user!,
                email: googleUser.email, name: googleUser.displayName);
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('requires-merge-decision')) rethrow;
      throw Exception("حدث خطأ أثناء المصادقة بحساب جوجل: $e");
    }
  }

  Future<void> resolveMerge(
      bool merge, DataMigrationService migrationService) async {
    if (_pendingCredential == null)
      throw Exception("لا توجد بيانات اعتماد معلقة");

    final anonUid = _auth.currentUser?.uid;

    // Sign in with the pending credential
    final userCred = await _auth.signInWithCredential(_pendingCredential!);
    if (userCred.user != null) {
      await _ensureUserDocument(userCred.user!,
          email: userCred.user!.email, name: userCred.user!.displayName);
    }
    _pendingCredential = null;

    if (merge && anonUid != null && userCred.user != null) {
      final newUid = userCred.user!.uid;
      await migrationService.migrateData(anonUid, newUid);
    }
  }

  Future<void> resolveMergeWeb(
      bool merge, DataMigrationService migrationService) async {
    final anonUid = _auth.currentUser?.uid;
    final googleProvider = GoogleAuthProvider();
    final userCred = await _auth.signInWithPopup(googleProvider);
    if (userCred.user != null) {
      await _ensureUserDocument(userCred.user!,
          email: userCred.user!.email, name: userCred.user!.displayName);
    }

    if (merge && anonUid != null && userCred.user != null) {
      final newUid = userCred.user!.uid;
      await migrationService.migrateData(anonUid, newUid);
    }
  }

  String _generateEmployeeEmail(String merchantEmail, String pin) {
    // Generate a unique hidden email for Firebase Auth
    // E.g. 123456_dotk_at_gmail.com@tajer.employee.local
    final cleanEmail =
        merchantEmail.trim().toLowerCase().replaceAll('@', '_at_');
    return "${pin}_${cleanEmail}@tajer.employee.local";
  }

  List<String> _readAssignedBranchIds(Map<String, dynamic> data) {
    final raw = data['assignedBranchIds'];
    if (raw is! List) return const [];
    final branches = raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return branches;
  }

  Future<void> _syncEmployeeRootDocument({
    required String employeeUid,
    required String merchantUid,
  }) async {
    final employeeRef = _firestore
        .collection('users')
        .doc(merchantUid)
        .collection('employees')
        .doc(employeeUid);
    final employeeDoc = await employeeRef.get();
    final employeeData = employeeDoc.data();
    if (!employeeDoc.exists || employeeData == null) {
      throw const EmployeeLoginFailure(AppFailureKind.employeeDeleted);
    }

    final updates = <String, dynamic>{
      'permissions':
          Map<String, dynamic>.from(employeeData['permissions'] ?? const {}),
      'assignedBranchIds': _readAssignedBranchIds(employeeData),
    };
    if (employeeData.containsKey('name')) {
      updates['name'] = employeeData['name']?.toString() ?? 'Employee';
    }
    await _firestore.collection('users').doc(employeeUid).set(
          updates,
          SetOptions(merge: true),
        );
  }

  Future<void> signInAsEmployee(String merchantEmail, String pin) async {
    try {
      final hiddenEmail = _generateEmployeeEmail(merchantEmail, pin);
      final userCred = await _auth.signInWithEmailAndPassword(
          email: hiddenEmail, password: pin);

      final uid = userCred.user?.uid;
      if (uid != null) {
        final docSnap = await _firestore.collection('users').doc(uid).get();
        if (!docSnap.exists) {
          final merchantQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: merchantEmail.trim().toLowerCase())
              .limit(1)
              .get();

          String? merchantUid;
          if (merchantQuery.docs.isNotEmpty) {
            merchantUid = merchantQuery.docs.first.id;
          }

          Map<String, dynamic> permissions = {};
          List<String> assignedBranchIds = const [];
          String empName = 'موظف';
          if (merchantUid != null) {
            final empDoc = await _firestore
                .collection('users')
                .doc(merchantUid)
                .collection('employees')
                .doc(uid)
                .get();
            if (empDoc.exists && empDoc.data() != null) {
              final data = empDoc.data()!;
              if (data.containsKey('permissions')) {
                permissions = Map<String, dynamic>.from(data['permissions']);
              }
              assignedBranchIds = _readAssignedBranchIds(data);
              if (data.containsKey('name')) {
                empName = data['name']?.toString() ?? 'موظف';
              }
            } else {
              throw const EmployeeLoginFailure(AppFailureKind.employeeDeleted);
            }
          } else {
            throw const EmployeeLoginFailure(AppFailureKind.merchantNotFound);
          }

          await _firestore.collection('users').doc(uid).set({
            'id': uid,
            'isAnonymous': false,
            'plan': 'employee',
            'role': 'employee',
            'merchantId': merchantUid ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'name': empName,
            'email': hiddenEmail,
            'deviceId': await _getDeviceId(),
            'permissions': permissions,
            'assignedBranchIds': assignedBranchIds,
          });
        }

        // Enforce subscription check for the merchant
        final empDoc = await _firestore.collection('users').doc(uid).get();
        final mId = empDoc.data()?['merchantId'];
        if (mId != null && mId.toString().isNotEmpty) {
          await _syncEmployeeRootDocument(
            employeeUid: uid,
            merchantUid: mId.toString(),
          );
          final mDoc = await _firestore.collection('users').doc(mId).get();
          final plan = mDoc.data()?['plan'] ?? 'merchant';
          final email = mDoc.data()?['email'] as String?;
          if (plan != 'premium' &&
              email?.trim().toLowerCase() != 'love.dotk@gmail.com') {
            await _auth.signOut();
            throw const EmployeeLoginFailure(
                AppFailureKind.subscriptionInactive);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw const EmployeeLoginFailure(AppFailureKind.invalidCredentials);
      }
      if (e.code == 'network-request-failed') {
        throw EmployeeLoginFailure(AppFailureKind.network, cause: e);
      }
      throw EmployeeLoginFailure(AppFailureKind.unknown, cause: e);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw EmployeeLoginFailure(AppFailureKind.unknown, cause: e);
    }
  }

  Future<void> createEmployee(String merchantEmail, String name, String pin,
      {Map<String, dynamic> permissions = const {}}) async {
    try {
      final merchantUid = _auth.currentUser?.uid;
      if (merchantUid == null)
        throw Exception("يجب أن تكون مسجلاً الدخول لإضافة موظف");

      // Enforce subscription check
      final merchantDoc =
          await _firestore.collection('users').doc(merchantUid).get();
      final plan = merchantDoc.data()?['plan'] ?? 'merchant';
      final email = merchantDoc.data()?['email'] as String?;
      if (plan != 'premium' &&
          email?.trim().toLowerCase() != 'love.dotk@gmail.com') {
        throw Exception("لا يمكنك إضافة موظفين بدون تفعيل الباقة الشهرية.");
      }

      // Check current employee count
      final empSnapshot = await _firestore
          .collection('users')
          .doc(merchantUid)
          .collection('employees')
          .get();
      if (empSnapshot.docs.length >= 3) {
        throw Exception("لقد وصلت للحد الأقصى (3 موظفين)");
      }

      final hiddenEmail = _generateEmployeeEmail(merchantEmail, pin);

      // We must create the user without logging out the current merchant.
      final tempApp = await Firebase.initializeApp(
        name: 'EmployeeCreatorApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      try {
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final userCred = await tempAuth.createUserWithEmailAndPassword(
            email: hiddenEmail, password: pin);

        final employeeUid = userCred.user?.uid;
        if (employeeUid != null) {
          // Save employee info in merchant's document
          await _firestore
              .collection('users')
              .doc(merchantUid)
              .collection('employees')
              .doc(employeeUid)
              .set({
            'name': name,
            'pin': pin,
            'permissions': permissions,
            'createdAt': FieldValue.serverTimestamp(),
            'merchantUid': merchantUid,
            'assignedBranchIds': const ['main'],
          });

          // Create root user document for the employee so appUserProvider works
          await _firestore.collection('users').doc(employeeUid).set({
            'id': employeeUid,
            'isAnonymous': false,
            'plan': 'employee',
            'role': 'employee',
            'merchantId': merchantUid,
            'createdAt': FieldValue.serverTimestamp(),
            'name': name,
            'email': hiddenEmail,
            'deviceId': await _getDeviceId(),
            'permissions': permissions,
            'assignedBranchIds': const ['main'],
          });
        }
      } finally {
        await tempApp.delete(); // Always clean up
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(
            "رمز الدخول (PIN) هذا مستخدم بالفعل لموظف آخر، يرجى اختيار رمز مختلف.");
      }
      throw Exception(e.message ?? "حدث خطأ أثناء إنشاء الموظف");
    } catch (e) {
      throw Exception("حدث خطأ غير معروف: $e");
    }
  }

  Future<void> deleteEmployee(String employeeUid) async {
    try {
      final merchantUid = _auth.currentUser?.uid;
      if (merchantUid == null) throw Exception("يجب أن تكون مسجل الدخول");

      final batch = _firestore.batch();
      batch.delete(_firestore
          .collection('users')
          .doc(merchantUid)
          .collection('employees')
          .doc(employeeUid));
      batch.delete(_firestore.collection('users').doc(employeeUid));
      await batch.commit();
    } catch (e) {
      throw Exception("حدث خطأ أثناء حذف الموظف: $e");
    }
  }

  Future<void> updateEmployeePermissions(
      String employeeUid, Map<String, dynamic> permissions) async {
    try {
      final merchantUid = _auth.currentUser?.uid;
      if (merchantUid == null) throw Exception("يجب أن تكون مسجل الدخول");

      // Security Check: Verify caller is not an employee
      final currentUserDoc =
          await _firestore.collection('users').doc(merchantUid).get();
      if (currentUserDoc.data()?['role'] == 'employee') {
        throw Exception("غير مصرح لك بتعديل الصلاحيات");
      }

      // Update in subcollection
      await _firestore
          .collection('users')
          .doc(merchantUid)
          .collection('employees')
          .doc(employeeUid)
          .update({
        'permissions': permissions,
      });
      // Update in root document
      await _firestore.collection('users').doc(employeeUid).update({
        'permissions': permissions,
      });
    } catch (e) {
      throw Exception("حدث خطأ أثناء تحديث الصلاحيات: $e");
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
  return ref
      .watch(authRepositoryProvider)
      .authStateChanges()
      .asyncExpand((user) {
    if (user == null) return Stream<AppUser?>.value(null);
    return (() async* {
      yield null;
      yield* FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          if (data['createdAt'] != null) {
            data['createdAt'] =
                safeParseDate(data['createdAt']).toIso8601String();
          }
          if (data['email'] == 'love.dotk@gmail.com') {
            data['plan'] = 'premium';
          }
          final appUser = AppUser.fromJson(data);
          debugPrint(
              'APP_USER_RESOLUTION authenticatedUid=${user.uid} loadedUserPath=users/${user.uid} role=${appUser.role} effectiveMerchantId=${currentEffectiveMerchantId(appUser)}');
          return appUser;
        }
        return null;
      });
    })();
  });
}
