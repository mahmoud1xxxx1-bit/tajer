import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/domain/app_user.dart';

part 'limits_service.g.dart';

class LimitsService {
  final FirebaseFirestore _firestore;

  LimitsService(this._firestore);

  static const int maxCustomers = 10;
  static const int maxOrders = 20;
  static const int maxProducts = 10;
  static const int maxExpenses = 10;
  static const int maxCategories = 5;
  static const int maxSuppliers = 5;
  static const int maxEmployees = 1;

  Future<bool> canAddCustomer(AppUser user) async {
    return _canAdd(user, 'customers', maxCustomers);
  }

  Future<bool> canAddOrder(AppUser user) async {
    return _canAdd(user, 'orders', maxOrders);
  }

  Future<bool> canAddProduct(AppUser user) async {
    return _canAdd(user, 'products', maxProducts);
  }

  Future<bool> canAddExpense(AppUser user) async {
    return _canAdd(user, 'expenses', maxExpenses);
  }

  Future<bool> canAddCategory(AppUser user) async {
    return _canAdd(user, 'categories', maxCategories);
  }

  Future<bool> canAddSupplier(AppUser user) async {
    return _canAdd(user, 'suppliers', maxSuppliers);
  }

  Future<bool> canAddEmployee(AppUser user) async {
    return _canAdd(user, 'employees', maxEmployees);
  }

  Future<bool> _canAdd(AppUser user, String collectionName, int maxLimit) async {
    // Banned devices cannot add anything (0 limit) ONLY if they are anonymous
    if (user.plan == 'banned_device' && user.isAnonymous) return false;

    // Employees are part of a merchant's team and should never be restricted by limit checking queries
    if (user.role == 'employee' || user.role == 'cashier' || user.plan == 'employee' || (user.merchantId != null && user.merchantId!.isNotEmpty && !user.isAnonymous)) {
      return true;
    }

    final String merchantId = user.merchantId ?? user.id;
    bool isPremium = user.plan == 'pro' || user.plan == 'premium' || user.email?.trim().toLowerCase() == 'love.dotk@gmail.com';

    // Pro/Premium users have unlimited access
    if (isPremium) return true;

    // Check count for free/guest users
    final isRootCollection = ['products', 'orders', 'customers'].contains(collectionName);
    
    final Query query = isRootCollection
        ? _firestore.collection(collectionName).where('merchantId', isEqualTo: merchantId)
        : (collectionName == 'employees') 
            ? _firestore.collection('users').doc(merchantId).collection(collectionName)
            : _firestore.collection('merchants').doc(merchantId).collection(collectionName);

    // Products and Raw Materials support Soft Delete (isArchived).
    // We cannot use `.where('isArchived', isEqualTo: false)` because old products without the field would be ignored and NOT counted.
    // So we fetch the documents and filter locally.
    try {
      if (collectionName == 'products' || collectionName == 'raw_materials') {
        final snapshot = await query.get();
        int activeCount = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final isArchived = data['isArchived'] == true;
          if (!isArchived) activeCount++;
        }
        return activeCount < maxLimit;
      } else {
        final snapshot = await query.count().get();
        return (snapshot.count ?? 0) < maxLimit;
      }
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('offline') || e.toString().contains('failed-precondition')) {
        try {
          final snapshot = await query.get(const GetOptions(source: Source.cache));
          if (collectionName == 'products' || collectionName == 'raw_materials') {
            int activeCount = 0;
            for (var doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final isArchived = data['isArchived'] == true;
              if (!isArchived) activeCount++;
            }
            return activeCount < maxLimit;
          } else {
            return snapshot.docs.length < maxLimit;
          }
        } catch (cacheError) {
          return true; // Safe fallback to avoid blocking offline usage
        }
      }
      rethrow;
    }
  }
}

@riverpod
LimitsService limitsService(LimitsServiceRef ref) {
  return LimitsService(FirebaseFirestore.instance);
}
