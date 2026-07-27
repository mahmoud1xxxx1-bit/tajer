import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/domain/app_user.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  // Fetch all users (merchants)
  Future<List<AppUser>> getAllMerchants() async {
    final snapshot = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => AppUser.fromJson(doc.data())).toList();
  }

  // Example: Query to get overall platform stats
  Future<Map<String, dynamic>> getPlatformStats() async {
    final productsSnapshot = await _firestore.collection('products').count().get();
    final ordersSnapshot = await _firestore.collection('orders').count().get();
    final customersSnapshot = await _firestore.collection('customers').count().get();
    final usersSnapshot = await _firestore.collection('users').count().get();

    return {
      'totalProducts': productsSnapshot.count ?? 0,
      'totalOrders': ordersSnapshot.count ?? 0,
      'totalCustomers': customersSnapshot.count ?? 0,
      'totalMerchants': usersSnapshot.count ?? 0,
    };
  }

  // Change merchant plan
  Future<void> updateMerchantPlan(String userId, String newPlan) async {
    await _firestore.collection('users').doc(userId).update({
      'plan': newPlan,
    });
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

final platformStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).getPlatformStats();
});

final merchantsListProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllMerchants();
});
