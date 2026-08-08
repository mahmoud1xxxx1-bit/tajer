import 'package:tajer/features/authentication/domain/app_user.dart';
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
    final docRef = _firestore.collection('customers').doc(customerId);
    final snapshot = await docRef.get();
    
    if (snapshot.exists) {
      final data = snapshot.data();
      final totalDebt = (data?['totalDebt'] as num?)?.toDouble() ?? 0.0;
      
      if (totalDebt.abs() > 0.01) {
        throw Exception('لا يمكن حذف العميل لأن عليه مبلغاً مستحقاً قدره $totalDebt ر.س. يرجى تسوية المبلغ أولاً.');
      }

      final merchantId = data?['merchantId'] as String?;

      final unpaidOrders = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: merchantId)
          .where('customerId', isEqualTo: customerId)
          .where('paymentMethod', isEqualTo: 'credit')
          .where('status', isNotEqualTo: 'cancelled')
          .get();
          
      bool hasUnpaid = unpaidOrders.docs.any((doc) {
        final orderData = doc.data();
        final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
        final paidAmount = (orderData['paidAmount'] as num?)?.toDouble() ?? 0.0;
        return (total - paidAmount) > 0.01;
      });

      if (hasUnpaid) {
        throw Exception('لا يمكن حذف العميل لوجود فواتير آجلة غير مسددة.');
      }

      await docRef.delete();
    }
  }

  Future<void> moveCustomersToFolder(List<String> customerIds, String? folderName) async {
    final batch = _firestore.batch();
    for (final id in customerIds) {
      final docRef = _firestore.collection('customers').doc(id);
      batch.update(docRef, {'folderName': folderName});
    }
    await batch.commit();
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


