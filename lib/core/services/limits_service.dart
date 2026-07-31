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

    final String merchantId = user.merchantId ?? user.id;
    bool isPremium = user.plan == 'pro' || user.plan == 'premium' || user.email == 'love.dotk@gmail.com';
    
    // If the user is an employee, check their merchant's plan
    if (!isPremium && user.merchantId != null && user.merchantId!.isNotEmpty) {
      final merchantDoc = await _firestore.collection('users').doc(merchantId).get();
      final merchantPlan = merchantDoc.data()?['plan'];
      final merchantEmail = merchantDoc.data()?['email'];
      if (merchantPlan == 'pro' || merchantPlan == 'premium' || merchantEmail == 'love.dotk@gmail.com') {
        isPremium = true;
      }
    }

    // Pro/Premium users have unlimited access
    if (isPremium) return true;

    // Check count for free/guest users
    final isRootCollection = ['products', 'orders', 'customers'].contains(collectionName);
    
    final Query query = isRootCollection
        ? _firestore.collection(collectionName).where('merchantId', isEqualTo: merchantId)
        : (collectionName == 'employees') 
            ? _firestore.collection('users').doc(merchantId).collection(collectionName)
            : _firestore.collection('merchants').doc(merchantId).collection(collectionName);

    final snapshot = await query.count().get();

    final currentCount = snapshot.count ?? 0;
    return currentCount < maxLimit;
  }
}

@riverpod
LimitsService limitsService(LimitsServiceRef ref) {
  return LimitsService(FirebaseFirestore.instance);
}
