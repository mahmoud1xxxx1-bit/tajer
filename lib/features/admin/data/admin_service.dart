import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminService {
  final FirebaseFirestore _firestore;

  AdminService(this._firestore);

  /// Checks if a given email is listed in the 'admins' collection.
  Future<bool> isUserAdmin(String? email) async {
    if (email == null || email.isEmpty) return false;
    try {
      final docRef = _firestore.collection('admins').doc(email.toLowerCase());
      final doc = await docRef.get();
      
      if (doc.exists) return true;

      // Bootstrap logic: If the admins collection is completely empty,
      // make the first user who logs in an admin.
      final adminsSnapshot = await _firestore.collection('admins').limit(1).get();
      if (adminsSnapshot.docs.isEmpty) {
        await docRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'grantedAutomatically': true,
        });
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(FirebaseFirestore.instance);
});

final isAdminStreamProvider = StreamProvider<bool>((ref) {
  final authStream = FirebaseAuth.instance.authStateChanges();
  
  return authStream.asyncMap((user) async {
    if (user == null || user.email == null) return false;
    final adminService = ref.read(adminServiceProvider);
    return await adminService.isUserAdmin(user.email);
  });
});
