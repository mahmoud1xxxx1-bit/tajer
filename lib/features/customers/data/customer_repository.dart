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
        .withConverter(
          fromFirestore: (snapshot, _) {
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            data['merchantId'] = data['merchantId']?.toString() ?? '';
            data['name'] = data['name']?.toString() ?? '';
            data['phone'] = data['phone']?.toString() ?? '';
            data['totalPurchases'] = (data['totalPurchases'] ?? 0.0).toDouble();
            data['orderCount'] = (data['orderCount'] ?? 0).toInt();
            return Customer.fromJson(data);
          },
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
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final repository = ref.watch(customerRepositoryProvider);
  return repository.queryCustomers(appUser.merchantId ?? appUser.id).snapshots().map(
        (snapshot) {
          final customers = snapshot.docs.map((doc) => doc.data()).toList();
          customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return customers;
        },
      );
}

