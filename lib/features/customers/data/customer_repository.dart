import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../orders/domain/order.dart';
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
            data['branchId'] =
                data['branchId']?.toString().trim().isNotEmpty == true
                    ? data['branchId'].toString()
                    : 'main';
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

  /// Returns the complete merchant-wide order history for one customer.
  ///
  /// Customer balances are merchant-wide in Tajer, so customer statements must
  /// never be built from the branch-scoped order stream. Legacy orders without
  /// branchId remain readable through AppOrder's main-branch fallback.
  Future<List<AppOrder>> getCustomerOrdersAcrossBranches({
    required String merchantId,
    required String customerId,
    String? branchId,
  }) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .where('customerId', isEqualTo: customerId)
        .get(const GetOptions(source: Source.serverAndCache));

    final orders = snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
          data['customerId'] = data['customerId']?.toString() ?? customerId;
          data['customerName'] = data['customerName']?.toString() ?? '';
          data['total'] = (data['total'] as num?)?.toDouble() ?? 0.0;
          data['paidAmount'] = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
          data['isCredit'] = data['isCredit'] as bool? ?? false;
          data['status'] = data['status']?.toString() ?? 'pending';

          if (data['items'] == null && data['productId'] != null) {
            data['items'] = [
              {
                'productId': data['productId']?.toString() ?? '',
                'productName': data['productName']?.toString() ?? '',
                'quantity': (data['quantity'] as num?)?.toInt() ?? 0,
                'price': (data['price'] as num?)?.toDouble() ?? 0.0,
                'total': (data['total'] as num?)?.toDouble() ?? 0.0,
              }
            ];
          } else if (data['items'] != null) {
            data['items'] = List<Map<String, dynamic>>.from(
              (data['items'] as List).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            );
          } else {
            data['items'] = <Map<String, dynamic>>[];
          }

          return AppOrder.fromJson(data);
        })
        .where((order) => branchId == null || order.branchId == branchId)
        .toList();

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<void> deleteCustomer(String customerId) async {
    final docRef = _firestore.collection('customers').doc(customerId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final data = snapshot.data();
      final totalDebt = (data?['totalDebt'] as num?)?.toDouble() ?? 0.0;

      if (totalDebt.abs() > 0.01) {
        throw Exception(
            'لا يمكن حذف العميل لأن عليه مبلغاً مستحقاً قدره $totalDebt ر.س. يرجى تسوية المبلغ أولاً.');
      }

      final merchantId = data?['merchantId'] as String?;
      final branchId = data?['branchId']?.toString() ?? 'main';

      final unpaidOrders = await _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: merchantId)
          .where('customerId', isEqualTo: customerId)
          .get();

      bool hasUnpaid = unpaidOrders.docs.any((doc) {
        final orderData = doc.data();
        final paymentMethod = orderData['paymentMethod'] as String?;
        final status = orderData['status'] as String?;
        final orderBranchId = orderData['branchId']?.toString() ?? 'main';

        if (paymentMethod != 'credit' ||
            status == 'cancelled' ||
            orderBranchId != branchId) {
          return false;
        }

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

  Future<void> moveCustomersToFolder(
      List<String> customerIds, String? folderName) async {
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
  final branchId = ref.watch(selectedBranchIdProvider);
  return repository
      .queryCustomers(currentEffectiveMerchantId(appUser))
      .snapshots()
      .map(
    (snapshot) {
      final customers = snapshot.docs
          .map((doc) => doc.data())
          .where((customer) => customer.branchId == branchId)
          .toList();
      customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return customers;
    },
  );
}
