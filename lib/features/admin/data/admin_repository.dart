import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_repository.g.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  // Fetch all users (merchants)
  Future<int> getTotalMerchantsCount() async {
    // Assuming you have a 'users' collection where merchant profiles are stored
    // For now, if we only create users implicitly, we might not have a clean 'users' collection.
    // In a real scenario, you'd track users in a top-level collection.
    return 0; // Placeholder
  }

  // Example: Query to get overall platform stats
  Future<Map<String, dynamic>> getPlatformStats() async {
    final productsSnapshot = await _firestore.collection('products').count().get();
    final ordersSnapshot = await _firestore.collection('orders').count().get();
    final customersSnapshot = await _firestore.collection('customers').count().get();

    return {
      'totalProducts': productsSnapshot.count ?? 0,
      'totalOrders': ordersSnapshot.count ?? 0,
      'totalCustomers': customersSnapshot.count ?? 0,
    };
  }
}

@riverpod
AdminRepository adminRepository(AdminRepositoryRef ref) {
  return AdminRepository(FirebaseFirestore.instance);
}

@riverpod
Future<Map<String, dynamic>> platformStats(PlatformStatsRef ref) {
  return ref.watch(adminRepositoryProvider).getPlatformStats();
}
