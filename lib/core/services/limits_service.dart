import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/authentication/domain/app_user.dart';

part 'limits_service.g.dart';

class LimitsService {
  final FirebaseFirestore _firestore;

  LimitsService(this._firestore);

  static const int freeMaxCustomers = 10;
  static const int freeMaxOrders = 20;
  static const int freeMaxProducts = 10;
  static const int freeMaxExpenses = 10;
  static const int freeMaxCategories = 5;
  static const int freeMaxSuppliers = 5;
  static const int freeMaxEmployees = 0; // Employees locked for free users (must subscribe)

  static const int guestMaxCustomers = 5;
  static const int guestMaxOrders = 10;
  static const int guestMaxProducts = 5;
  static const int guestMaxExpenses = 5;
  static const int guestMaxCategories = 3;
  static const int guestMaxSuppliers = 2;
  static const int guestMaxEmployees = 0; // Employees locked for guest users

  Future<bool> canAddCustomer(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxCustomers : freeMaxCustomers;
    return _canAdd(user, 'customers', limit);
  }

  Future<bool> canAddOrder(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxOrders : freeMaxOrders;
    return _canAdd(user, 'orders', limit);
  }

  Future<bool> canAddProduct(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxProducts : freeMaxProducts;
    return _canAdd(user, 'products', limit);
  }

  Future<bool> canAddExpense(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxExpenses : freeMaxExpenses;
    return _canAdd(user, 'expenses', limit);
  }

  Future<bool> canAddCategory(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxCategories : freeMaxCategories;
    return _canAdd(user, 'categories', limit);
  }

  Future<bool> canAddSupplier(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxSuppliers : freeMaxSuppliers;
    return _canAdd(user, 'suppliers', limit);
  }

  Future<bool> canAddEmployee(AppUser user) async {
    final limit = user.isAnonymous ? guestMaxEmployees : freeMaxEmployees;
    return _canAdd(user, 'employees', limit);
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
