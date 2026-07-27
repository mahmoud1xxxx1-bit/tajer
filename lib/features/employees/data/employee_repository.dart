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
      return snapshot.docs.map((doc) => Employee.fromJson(doc.data())).toList();
    });
  }

  Future<void> addEmployee(Employee employee, String password) async {
    
    // 1. Initialize secondary app to create user without signing out merchant
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'Secondary',
      options: Firebase.app().options,
    );
    try {
      UserCredential userCred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: employee.email, password: password);
      
      final newUid = userCred.user!.uid;
      
      final newEmployee = Employee(
        id: newUid,
        name: employee.name,
        email: employee.email,
        role: employee.role,
        createdAt: employee.createdAt,
      );

      // Save to merchant's employees subcollection
      await _employeesRef.doc(newUid).set(newEmployee.toJson());

      // Save to global users collection so they can login normally
      await _firestore.collection('users').doc(newUid).set({
        'id': newUid,
        'name': newEmployee.name,
        'email': newEmployee.email,
        'role': newEmployee.role,
        'merchantId': _merchantId,
        'isAnonymous': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    await _employeesRef.doc(employee.id).update(employee.toJson());
  }

  Future<void> deleteEmployee(String employeeId) async {
    await _employeesRef.doc(employeeId).delete();
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return EmployeeRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  final repository = ref.watch(employeeRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchEmployees();
});
