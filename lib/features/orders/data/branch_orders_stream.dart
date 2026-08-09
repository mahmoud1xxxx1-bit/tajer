import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/order.dart';

/// Branch-scoped read model for order lists/reports.
///
/// We intentionally query only by merchantId and filter branchId in memory so
/// rollout does not require a new composite index. Legacy orders that do not
/// contain branchId are parsed by AppOrder as Main Branch.
final branchOrdersStreamProvider =
    StreamProvider.autoDispose<List<AppOrder>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final merchantId = currentEffectiveMerchantId(appUser);
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('orders')
      .where('merchantId', isEqualTo: merchantId)
      .where('branchId', isEqualTo: branchId)
      .snapshots()
      .map((snapshot) {
    var orders = snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
          data['customerId'] = data['customerId']?.toString() ?? '';
          data['customerName'] = data['customerName']?.toString() ?? '';
          data['total'] = (data['total'] as num?)?.toDouble() ?? 0.0;
          data['paidAmount'] = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
          data['isCredit'] = data['isCredit'] as bool? ?? false;
          data['status'] = data['status']?.toString() ?? 'pending';

          // Backward compatibility for pre-items orders from older Tajer builds.
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
              (data['items'] as List)
                  .map((x) => Map<String, dynamic>.from(x as Map)),
            );
          } else {
            data['items'] = <Map<String, dynamic>>[];
          }
          return AppOrder.fromJson(data);
        })
        .where((order) => order.branchId == branchId)
        .toList();

    if (!appUser.hasPermission('can_view_all_orders')) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      orders = orders.where((o) => o.createdAt.isAfter(sevenDaysAgo)).toList();
    }

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  });
});
