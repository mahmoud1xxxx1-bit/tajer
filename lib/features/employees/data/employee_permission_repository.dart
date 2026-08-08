import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/employee_permission_catalog.dart';

class EmployeePermissionRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  EmployeePermissionRepository(this.firestore, this.auth);

  Future<void> updatePermissions({
    required String employeeId,
    required Map<String, bool> permissions,
  }) async {
    final merchantUid = auth.currentUser?.uid;
    if (merchantUid == null || merchantUid.isEmpty) {
      throw StateError('Merchant authentication is required');
    }

    if (permissions.keys.toSet().difference(EmployeePermissionKeys.all).isNotEmpty) {
      throw ArgumentError('Unknown employee permission key');
    }

    final normalized = <String, bool>{
      for (final key in EmployeePermissionKeys.all)
        key: permissions[key] ?? EmployeePermissionCatalog.leastPrivilegeDefaults[key] ?? false,
    };

    final merchantRef = firestore.collection('users').doc(merchantUid);
    final employeeRef = merchantRef.collection('employees').doc(employeeId);
    final rootEmployeeRef = firestore.collection('users').doc(employeeId);

    await firestore.runTransaction<void>((tx) async {
      final merchantSnapshot = await tx.get(merchantRef);
      if (!merchantSnapshot.exists) {
        throw StateError('Merchant account not found');
      }
      final merchantData = merchantSnapshot.data() ?? const <String, dynamic>{};
      if (merchantData['role'] == 'employee') {
        throw StateError('Employees cannot change permissions');
      }

      final employeeSnapshot = await tx.get(employeeRef);
      if (!employeeSnapshot.exists) {
        throw StateError('Employee not found');
      }

      final rootSnapshot = await tx.get(rootEmployeeRef);
      if (!rootSnapshot.exists) {
        throw StateError('Employee account not found');
      }
      final rootData = rootSnapshot.data() ?? const <String, dynamic>{};
      if (rootData['merchantId']?.toString() != merchantUid) {
        throw StateError('Employee does not belong to this merchant');
      }

      tx.update(employeeRef, {
        'permissions': normalized,
        'permissionsUpdatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(rootEmployeeRef, {
        'permissions': normalized,
        'permissionsUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

final employeePermissionRepositoryProvider = Provider<EmployeePermissionRepository>((ref) {
  return EmployeePermissionRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});
