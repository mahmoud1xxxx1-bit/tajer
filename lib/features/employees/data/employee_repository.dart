import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/employee.dart';

class EmployeeRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  EmployeeRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('users').doc(_merchantId).collection('employees');

  Stream<List<Employee>> watchEmployees() {
    return _employeesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] ??= doc.id;
        return Employee.fromJson(data);
      }).toList();
    });
  }

  Future<void> addEmployee(Employee employee, String password) async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'Secondary_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final userCred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: employee.email, password: password);
      final newUid = userCred.user!.uid;
      final branches = employee.assignedBranchIds.isEmpty
          ? const <String>['main']
          : employee.assignedBranchIds;
      final newEmployee = Employee(
        id: newUid,
        name: employee.name,
        email: employee.email,
        role: employee.role,
        createdAt: employee.createdAt,
        assignedBranchIds: branches,
      );

      final batch = _firestore.batch();
      batch.set(_employeesRef.doc(newUid), newEmployee.toJson());
      batch.set(_firestore.collection('users').doc(newUid), {
        'id': newUid,
        'name': newEmployee.name,
        'email': newEmployee.email,
        'role': newEmployee.role,
        'merchantId': _merchantId,
        'isAnonymous': false,
        'createdAt': FieldValue.serverTimestamp(),
        'assignedBranchIds': branches,
      });
      await batch.commit();
      await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    final branches = employee.assignedBranchIds.isEmpty
        ? const <String>['main']
        : employee.assignedBranchIds;
    final employeeData = employee.toJson()..['assignedBranchIds'] = branches;
    final batch = _firestore.batch();
    batch.update(_employeesRef.doc(employee.id), employeeData);
    batch.update(_firestore.collection('users').doc(employee.id), {
      'name': employee.name,
      'role': employee.role,
      'assignedBranchIds': branches,
    });
    await batch.commit();
  }

  Future<void> updateAssignedBranches(
    String employeeId,
    List<String> branchIds,
  ) async {
    final normalized = branchIds.toSet().where((id) => id.isNotEmpty).toList();
    if (normalized.isEmpty) {
      throw ArgumentError('An employee must be assigned to at least one branch');
    }
    final batch = _firestore.batch();
    batch.update(_employeesRef.doc(employeeId), {'assignedBranchIds': normalized});
    batch.update(_firestore.collection('users').doc(employeeId), {
      'assignedBranchIds': normalized,
    });
    await batch.commit();
  }

  Future<void> deleteEmployee(String employeeId) async {
    final batch = _firestore.batch();
    batch.delete(_employeesRef.doc(employeeId));
    batch.delete(_firestore.collection('users').doc(employeeId));
    await batch.commit();
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return EmployeeRepository(
    FirebaseFirestore.instance,
    appUser.merchantId ?? appUser.id,
  );
});

final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  final repository = ref.watch(employeeRepositoryProvider);
  if (repository == null) return Stream.value(const <Employee>[]);
  return repository.watchEmployees();
});
