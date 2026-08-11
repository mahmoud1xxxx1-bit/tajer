import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan_tier.dart';
import '../models/subscription_policy.dart';
import '../models/branch_mode.dart';

class QuotaRequirement {
  final DocumentReference<Map<String, dynamic>> ref;
  final int limit;
  final String branchId;
  final String resourceType;
  final String periodKey;

  const QuotaRequirement({
    required this.ref,
    required this.limit,
    required this.branchId,
    required this.resourceType,
    required this.periodKey,
  });
}

class QuotaConsumption {
  final List<MapEntry<QuotaRequirement, int>> _nextCounts;

  const QuotaConsumption(this._nextCounts);

  void apply(Transaction transaction) {
    for (final entry in _nextCounts) {
      final requirement = entry.key;
      transaction.set(requirement.ref, {
        'count': entry.value,
        'branchId': requirement.branchId,
        'resourceType': requirement.resourceType,
        'periodKey': requirement.periodKey,
      }, SetOptions(merge: true));
    }
  }
}

class QuotaReservation {
  final List<QuotaRequirement> requirements;

  const QuotaReservation(this.requirements);

  bool get isUnlimited => requirements.isEmpty;

  Future<QuotaConsumption> validate(Transaction transaction) async {
    if (requirements.isEmpty) {
      return const QuotaConsumption([]);
    }

    final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final requirement in requirements) {
      snapshots.add(await transaction.get(requirement.ref));
    }

    final nextCounts = <MapEntry<QuotaRequirement, int>>[];
    for (var i = 0; i < requirements.length; i++) {
      final requirement = requirements[i];
      final current = (snapshots[i].data()?['count'] as num?)?.toInt() ?? 0;
      if (current >= requirement.limit) {
        throw Exception('limit_reached_for_plan');
      }
      nextCounts.add(MapEntry(requirement, current + 1));
    }

    return QuotaConsumption(nextCounts);
  }
}

class EntitlementIntegration {
  static PlanTier? _testInjectedTier;

  static void injectTestTier(PlanTier tier) => _testInjectedTier = tier;
  static void clearTestTier() => _testInjectedTier = null;

  static PlanTier resolveEffectiveTier(String? plan) {
    if (_testInjectedTier != null) return _testInjectedTier!;
    return SubscriptionPolicy.resolveLegacyPlan(plan);
  }

  static Future<int> getBranchPosition(
    FirebaseFirestore firestore,
    String merchantId,
    String branchId,
  ) async {
    List<QueryDocumentSnapshot> docs = [];
    try {
      final snap = await firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('branches')
          .orderBy('createdAt')
          .get();
      docs = snap.docs;
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('offline') ||
          e.toString().contains('failed-precondition')) {
        try {
          final snap = await firestore
              .collection('merchants')
              .doc(merchantId)
              .collection('branches')
              .orderBy('createdAt')
              .get(const GetOptions(source: Source.cache));
          docs = snap.docs;
        } catch (_) {}
      }
    }

    final index = docs.indexWhere((d) => d.id == branchId);
    return index != -1 ? index + 1 : 1;
  }

  static Future<String?> _getPlan(
    FirebaseFirestore firestore,
    String merchantId,
  ) async {
    try {
      final mDoc = await firestore
          .collection('merchants')
          .doc(merchantId)
          .get(const GetOptions(source: Source.cache));
      final plan = mDoc.data()?['plan']?.toString();
      if (plan != null && plan.isNotEmpty) return plan;
    } catch (_) {}

    try {
      final mDoc = await firestore
          .collection('merchants')
          .doc(merchantId)
          .get();
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
      final globalUsage = await _getCurrentUsage(
        firestore,
        merchantId,
        'global',
        'orders',
        'lifetime',
      );
      if (globalUsage >= globalLimit) return false;

      final branchPosition = await getBranchPosition(
        firestore,
        merchantId,
        branchId,
      );
      final branchMode = SubscriptionPolicy.getBranchMode(
        tier,
        branchPosition - 1,
      );

      if (branchMode == BranchMode.trial) {
        final branchLimit =
            SubscriptionPolicy.trialBranchLimits.ordersLifetime!;
        final branchUsage = await _getCurrentUsage(
          firestore,
          merchantId,
          branchId,
          'orders',
          'lifetime',
        );
        if (branchUsage >= branchLimit) return false;
      }
      return true;
    }

    final limitData = await _getLimitAndPeriod(
      firestore,
      merchantId,
      branchId,
      resourceType,
      plan,
    );
    if (limitData == null) return true;

    final currentUsage = await _getCurrentUsage(
      firestore,
      merchantId,
      branchId,
      resourceType,
      limitData['periodKey'],
    );
    return currentUsage < (limitData['limit'] as int);
  }

  /// Builds every usage document that must be checked for a single resource
  /// mutation. The returned reservation performs no writes by itself, which
  /// lets repositories validate quota early in their own transaction and
  /// apply the quota writes only after all transaction reads are complete.
  static Future<QuotaReservation> prepareQuotaReservation({
    required FirebaseFirestore firestore,
    required String merchantId,
    required String branchId,
    required String resourceType,
    String? plan,
  }) async {
    plan ??= await _getPlan(firestore, merchantId);
    final tier = resolveEffectiveTier(plan);
    final usageCollection = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('entitlement_usage');

    if (tier == PlanTier.free && resourceType == 'orders') {
      final requirements = <QuotaRequirement>[
        QuotaRequirement(
          ref: usageCollection.doc('global_orders_lifetime'),
          limit: SubscriptionPolicy.freeMainLimits.ordersLifetime!,
          branchId: 'global',
          resourceType: 'orders',
          periodKey: 'lifetime',
        ),
      ];

      final branchPosition = await getBranchPosition(
        firestore,
        merchantId,
        branchId,
      );
      final branchMode = SubscriptionPolicy.getBranchMode(
        tier,
        branchPosition - 1,
      );
      if (branchMode == BranchMode.trial) {
        requirements.add(
          QuotaRequirement(
            ref: usageCollection.doc('${branchId}_orders_lifetime'),
            limit: SubscriptionPolicy.trialBranchLimits.ordersLifetime!,
            branchId: branchId,
            resourceType: 'orders',
            periodKey: 'lifetime',
          ),
        );
      }
      return QuotaReservation(requirements);
    }

    final limitData = await _getLimitAndPeriod(
      firestore,
      merchantId,
      branchId,
      resourceType,
      plan,
    );
    if (limitData == null) return const QuotaReservation([]);

    final periodKey = limitData['periodKey'] as String;
    return QuotaReservation([
      QuotaRequirement(
        ref: usageCollection.doc('${branchId}_${resourceType}_$periodKey'),
        limit: limitData['limit'] as int,
        branchId: branchId,
        resourceType: resourceType,
        periodKey: periodKey,
      ),
    ]);
  }

  static Future<void> checkAndConsumeQuota({
    required FirebaseFirestore firestore,
    required String merchantId,
    required String branchId,
    required String resourceType,
    String? plan,
    WriteBatch? batch,
  }) async {
    final reservation = await prepareQuotaReservation(
      firestore: firestore,
      merchantId: merchantId,
      branchId: branchId,
      resourceType: resourceType,
      plan: plan,
    );
    if (reservation.isUnlimited) return;

    // A WriteBatch cannot make a prior quota read atomic. Always reserve the
    // slot in a transaction. Repositories that require all-or-nothing coupling
    // with their business write should use prepareQuotaReservation(),
    // validate() and apply() inside their existing transaction instead.
    await firestore.runTransaction<void>((transaction) async {
      final consumption = await reservation.validate(transaction);
      consumption.apply(transaction);
    });
  }

  static Future<Map<String, dynamic>?> _getLimitAndPeriod(
    FirebaseFirestore firestore,
    String merchantId,
    String branchId,
    String resourceType,
    String? plan,
  ) async {
    final tier = resolveEffectiveTier(plan);
    final branchPosition = await getBranchPosition(
      firestore,
      merchantId,
      branchId,
    );
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
      case 'products':
        limit = limits.products == -1 ? null : limits.products;
        break;
      case 'categories':
        limit = limits.categories == -1 ? null : limits.categories;
        break;
      case 'customers':
        limit = limits.customers == -1 ? null : limits.customers;
        break;
      case 'suppliers':
        limit = limits.suppliers == -1 ? null : limits.suppliers;
        break;
      case 'raw_materials':
        limit = limits.rawMaterials == -1 ? null : limits.rawMaterials;
        break;
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

  static Future<int> _getCurrentUsage(
    FirebaseFirestore firestore,
    String merchantId,
    String branchId,
    String resourceType,
    String periodKey,
  ) async {
    final usageRef = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('entitlement_usage')
        .doc('${branchId}_${resourceType}_$periodKey');

    try {
      final snap = await usageRef.get();
      return (snap.data()?['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('offline') ||
          e.toString().contains('failed-precondition')) {
        try {
          final snap = await usageRef.get(
            const GetOptions(source: Source.cache),
          );
          return (snap.data()?['count'] as num?)?.toInt() ?? 0;
        } catch (_) {}
      } else {
        rethrow;
      }
    }
    return 0;
  }
}
