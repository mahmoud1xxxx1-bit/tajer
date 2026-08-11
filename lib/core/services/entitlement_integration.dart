import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan_tier.dart';
import '../models/subscription_policy.dart';
import '../models/branch_mode.dart';
import 'entitlement_evaluator.dart';

class EntitlementIntegration {
  static PlanTier? _testInjectedTier;

  static void injectTestTier(PlanTier tier) => _testInjectedTier = tier;
  static void clearTestTier() => _testInjectedTier = null;

  static PlanTier resolveEffectiveTier(String? plan) {
    if (_testInjectedTier != null) return _testInjectedTier!;
    return SubscriptionPolicy.resolveLegacyPlan(plan);
  }

  static Future<int> getBranchPosition(FirebaseFirestore firestore, String merchantId, String branchId) async {
    List<QueryDocumentSnapshot> docs = [];
    try {
      final snap = await firestore.collection('merchants').doc(merchantId).collection('branches').orderBy('createdAt').get();
      docs = snap.docs;
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('offline') || e.toString().contains('failed-precondition')) {
        try {
          final snap = await firestore.collection('merchants').doc(merchantId).collection('branches').orderBy('createdAt').get(const GetOptions(source: Source.cache));
          docs = snap.docs;
        } catch (_) {}
      }
    }
    
    final index = docs.indexWhere((d) => d.id == branchId);
    return index != -1 ? index + 1 : 1;
  }

  static Future<String?> _getPlan(FirebaseFirestore firestore, String merchantId) async {
    try {
      final mDoc = await firestore.collection('merchants').doc(merchantId).get(const GetOptions(source: Source.cache));
      final plan = mDoc.data()?['plan']?.toString();
      if (plan != null && plan.isNotEmpty) return plan;
    } catch (_) {}
    
    try {
      final mDoc = await firestore.collection('merchants').doc(merchantId).get();
      final plan = mDoc.data()?['plan']?.toString();
      if (plan != null && plan.isNotEmpty) return plan;
    } catch (_) {}

    return null;
  }

  static Future<bool> checkQuota({
    required FirebaseFirestore firestore,
    required String merchantId,
    required String branchId,
    required String resourceType,
    String? plan,
  }) async {
    plan ??= await _getPlan(firestore, merchantId);
    final tier = resolveEffectiveTier(plan);

    if (tier == PlanTier.free && resourceType == 'orders') {
      final globalLimit = SubscriptionPolicy.freeMainLimits.ordersLifetime!;
      final globalUsage = await _getCurrentUsage(firestore, merchantId, 'global', 'orders', 'lifetime');
      if (globalUsage >= globalLimit) return false;

      final branchPosition = await getBranchPosition(firestore, merchantId, branchId);
      final branchMode = SubscriptionPolicy.getBranchMode(tier, branchPosition - 1);
      
      if (branchMode == BranchMode.trial) {
        final branchLimit = SubscriptionPolicy.trialBranchLimits.ordersLifetime!;
        final branchUsage = await _getCurrentUsage(firestore, merchantId, branchId, 'orders', 'lifetime');
        if (branchUsage >= branchLimit) return false;
      }
      return true;
    }

    final limitData = await _getLimitAndPeriod(firestore, merchantId, branchId, resourceType, plan);
    if (limitData == null) return true; // unlimited

    final currentUsage = await _getCurrentUsage(firestore, merchantId, branchId, resourceType, limitData['periodKey']);
    return currentUsage < (limitData['limit'] as int);
  }

  static Future<void> checkAndConsumeQuota({
    required FirebaseFirestore firestore,
    required String merchantId,
    required String branchId,
    required String resourceType,
    String? plan,
    WriteBatch? batch,
  }) async {
    plan ??= await _getPlan(firestore, merchantId);
    final tier = resolveEffectiveTier(plan);

    if (tier == PlanTier.free && resourceType == 'orders') {
      final globalLimit = SubscriptionPolicy.freeMainLimits.ordersLifetime!;
      final globalUsage = await _getCurrentUsage(firestore, merchantId, 'global', 'orders', 'lifetime');
      if (globalUsage >= globalLimit) {
        throw Exception('limit_reached_for_plan');
      }

      final branchPosition = await getBranchPosition(firestore, merchantId, branchId);
      final branchMode = SubscriptionPolicy.getBranchMode(tier, branchPosition - 1);
      
      if (branchMode == BranchMode.trial) {
        final branchLimit = SubscriptionPolicy.trialBranchLimits.ordersLifetime!;
        final branchUsage = await _getCurrentUsage(firestore, merchantId, branchId, 'orders', 'lifetime');
        if (branchUsage >= branchLimit) {
          throw Exception('limit_reached_for_plan');
        }
        
        final branchUsageRef = firestore
            .collection('merchants')
            .doc(merchantId)
            .collection('entitlement_usage')
            .doc('${branchId}_orders_lifetime');
        final branchData = {
          'count': FieldValue.increment(1),
          'branchId': branchId,
          'resourceType': 'orders',
          'periodKey': 'lifetime',
        };
        if (batch != null) {
          batch.set(branchUsageRef, branchData, SetOptions(merge: true));
        } else {
          await branchUsageRef.set(branchData, SetOptions(merge: true));
        }
      }

      final globalUsageRef = firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('entitlement_usage')
          .doc('global_orders_lifetime');
      final globalData = {
        'count': FieldValue.increment(1),
        'branchId': 'global',
        'resourceType': 'orders',
        'periodKey': 'lifetime',
      };
      if (batch != null) {
        batch.set(globalUsageRef, globalData, SetOptions(merge: true));
      } else {
        await globalUsageRef.set(globalData, SetOptions(merge: true));
      }
      return;
    }

    final limitData = await _getLimitAndPeriod(firestore, merchantId, branchId, resourceType, plan);
    if (limitData == null) return; // unlimited

    final currentUsage = await _getCurrentUsage(firestore, merchantId, branchId, resourceType, limitData['periodKey']);
    if (currentUsage >= (limitData['limit'] as int)) {
      throw Exception('limit_reached_for_plan');
    }

    final usageRef = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('entitlement_usage')
        .doc('${branchId}_${resourceType}_${limitData['periodKey']}');

    final data = {
      'count': FieldValue.increment(1),
      'branchId': branchId,
      'resourceType': resourceType,
      'periodKey': limitData['periodKey'],
    };

    if (batch != null) {
      batch.set(usageRef, data, SetOptions(merge: true));
    } else {
      await usageRef.set(data, SetOptions(merge: true));
    }
  }

  static Future<Map<String, dynamic>?> _getLimitAndPeriod(
    FirebaseFirestore firestore, String merchantId, String branchId, String resourceType, String? plan) async {
    
    final tier = resolveEffectiveTier(plan);
    final branchPosition = await getBranchPosition(firestore, merchantId, branchId);
    final limits = SubscriptionPolicy.getBranchLimits(tier, branchPosition - 1);

    int? limit;
    String periodKey = 'lifetime';

    switch (resourceType) {
      case 'orders':
        limit = limits.ordersMonthly ?? limits.ordersLifetime;
        if (limits.ordersMonthly != null) {
          final now = DateTime.now();
          periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        }
        break;
      case 'products': limit = limits.products == -1 ? null : limits.products; break;
      case 'categories': limit = limits.categories == -1 ? null : limits.categories; break;
      case 'customers': limit = limits.customers == -1 ? null : limits.customers; break;
      case 'suppliers': limit = limits.suppliers == -1 ? null : limits.suppliers; break;
      case 'raw_materials': limit = limits.rawMaterials == -1 ? null : limits.rawMaterials; break;
      case 'expenses':
        limit = limits.expensesMonthly ?? limits.expensesLifetime;
        if (limits.expensesMonthly != null) {
          final now = DateTime.now();
          periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        }
        break;
    }

    if (limit == null) return null;
    return {'limit': limit, 'periodKey': periodKey};
  }

  static Future<int> _getCurrentUsage(FirebaseFirestore firestore, String merchantId, String branchId, String resourceType, String periodKey) async {
    final usageRef = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('entitlement_usage')
        .doc('${branchId}_${resourceType}_$periodKey');

    try {
      final snap = await usageRef.get();
      return (snap.data()?['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('offline') || e.toString().contains('failed-precondition')) {
        try {
          final snap = await usageRef.get(const GetOptions(source: Source.cache));
          return (snap.data()?['count'] as num?)?.toInt() ?? 0;
        } catch (_) {}
      } else {
        rethrow;
      }
    }
    return 0;
  }
}
