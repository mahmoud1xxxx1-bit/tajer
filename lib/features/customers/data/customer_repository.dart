import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/customer.dart';

part 'customer_repository.g.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepository(this._firestore);

  Query<Customer> queryCustomers(String merchantId) {
    return _firestore
        .collection('customers')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .withConverter(
          fromFirestore: (snapshot, _) => Customer.fromJson(snapshot.data()!),
          toFirestore: (customer, _) => customer.toJson(),
        );
  }

  Future<void> addCustomer(Customer customer) async {
    final docRef = _firestore.collection('customers').doc(customer.id);
    await docRef.set(customer.toJson());
  }

  Future<void> updateCustomer(Customer customer) async {
    final docRef = _firestore.collection('customers').doc(customer.id);
    await docRef.update(customer.toJson());
  }

  Future<void> deleteCustomer(String customerId) async {
    await _firestore.collection('customers').doc(customerId).delete();
  }

  Future<int> getCustomerCount(String merchantId) async {
    final snapshot = await _firestore
        .collection('customers')
        .where('merchantId', isEqualTo: merchantId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

@riverpod
CustomerRepository customerRepository(CustomerRepositoryRef ref) {
  return CustomerRepository(FirebaseFirestore.instance);
}

@riverpod
Stream<List<Customer>> customersStream(CustomersStreamRef ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return const Stream.empty();

  final repository = ref.watch(customerRepositoryProvider);
  return repository.queryCustomers(user.uid).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
      );
}
