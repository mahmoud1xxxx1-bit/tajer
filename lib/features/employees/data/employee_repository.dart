import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> addEmployee(Employee employee) async {
    await _employeesRef.doc(employee.id).set(employee.toJson());
  }

  Future<void> updateEmployee(Employee employee) async {
    await _employeesRef.doc(employee.id).update(employee.toJson());
  }

  Future<void> deleteEmployee(String employeeId) async {
    await _employeesRef.doc(employeeId).delete();
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository?>((ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return null;
  return EmployeeRepository(FirebaseFirestore.instance, user.uid);
});

final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  final repository = ref.watch(employeeRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchEmployees();
});
