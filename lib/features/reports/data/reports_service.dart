import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/store_profile_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/application/access_policy.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../branches/presentation/branch_context.dart';
import '../../customers/data/customer_debt_payment_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/customer_debt_payment.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../orders/data/order_cost_snapshot_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/data/order_return_repository.dart';
import '../../orders/data/return_cost_snapshot_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_return.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/supplier.dart';
import 'report_cashflow_ledger.dart';

enum ReportsScope { branch, merchant }

ReportsScope resolveReportsScope({
  required String? role,
  required ReportsScope requested,
}) {
  return role == 'merchant' || role == 'admin'
      ? requested
      : ReportsScope.branch;
}

final reportsScopeProvider = StateProvider<ReportsScope>((ref) {
  return ReportsScope.branch;
});

final effectiveReportsScopeProvider = Provider<ReportsScope>((ref) {
  final requested = ref.watch(reportsScopeProvider);
  final role = ref.watch(appUserProvider).value?.role;
  return resolveReportsScope(role: role, requested: requested);
});

class SalesData {
  final DateTime date;
  final double amount;
  SalesData(this.date, this.amount);
}

class ProductSales {
  final Product product;
  final int quantitySold;
  final double totalRevenue;
  ProductSales(this.product, this.quantitySold, this.totalRevenue);
}

class ReportsService {
  final List<AppOrder> orders;
  final List<Product> products;
  final List<Expense> expenses;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final List<CustomerDebtPayment> debtPayments;
  final List<OrderReturn> returns;
  final List<OrderReturn> balanceReturns;
  final Map<String, double> protectedOrderCosts;
  final Map<String, double> protectedReturnCosts;
  final bool canViewCost;
  final double defaultTaxPercentage;
  final bool defaultIsTaxInclusive;

  ReportsService(
    this.orders,
    this.products,
    this.expenses,
    this.customers,
    this.suppliers, {
    this.debtPayments = const [],
    this.returns = const [],
    List<OrderReturn>? balanceReturns,
    this.protectedOrderCosts = const {},
    this.protectedReturnCosts = const {},
    this.canViewCost = true,
    this.defaultTaxPercentage = 0.0,
    this.defaultIsTaxInclusive = true,
  }) : balanceReturns = balanceReturns ?? returns;

  ReportsService filterByDate(DateTime start, DateTime end) {
    bool withinRange(DateTime value) =>
        !value.isBefore(start) && !value.isAfter(end);
    final filteredOrders =
        orders.where((order) => withinRange(order.createdAt)).toList();
    final filteredExpenses =
        expenses.where((expense) => withinRange(expense.date)).toList();
    final filteredDebtPayments = debtPayments
        .where((payment) => withinRange(payment.createdAt))
        .toList();
    final filteredReturns =
        returns.where((value) => withinRange(value.createdAt)).toList();
    final filteredIds = filteredOrders.map((order) => order.id).toSet();
    final filteredReturnIds = filteredReturns.map((value) => value.id).toSet();
    final filteredProtectedCosts = <String, double>{
      for (final entry in protectedOrderCosts.entries)
        if (filteredIds.contains(entry.key)) entry.key: entry.value,
    };
    final filteredProtectedReturnCosts = <String, double>{
      for (final entry in protectedReturnCosts.entries)
        if (filteredReturnIds.contains(entry.key)) entry.key: entry.value,
    };

    return ReportsService(
      filteredOrders,
      products,
      filteredExpenses,
      customers,
      suppliers,
      debtPayments: filteredDebtPayments,
      returns: filteredReturns,
      balanceReturns: balanceReturns,
      protectedOrderCosts: filteredProtectedCosts,
      protectedReturnCosts: filteredProtectedReturnCosts,
      canViewCost: canViewCost,
      defaultTaxPercentage: defaultTaxPercentage,
      defaultIsTaxInclusive: defaultIsTaxInclusive,
    );
  }

  /// Gross sale value including tax before any return transactions in scope.
  double get grossRevenue => orders
      .where((order) =>
          order.status != 'cancelled' && order.status != 'debt_repayment')
      .fold(0.0, (sum, order) => sum + order.total);

  /// Return value including tax recorded in the report period.
  double get totalReturns =>
      returns.fold(0.0, (sum, value) => sum + value.returnedTotal);

  /// Net sale value including tax after period returns.
  double get totalRevenue => grossRevenue - totalReturns;

  /// Net sale value before tax after period returns.
  double get netSalesRevenue => totalRevenue - totalTaxCollected;

  /// Current unpaid balance attributable to the credit sales in this report's
  /// order scope. Returns are considered even when they happened after the sale
  /// period so an already-returned item cannot remain as fictitious receivable.
  double get totalDebt {
    final returnedByOrder = <String, double>{};
    for (final value in balanceReturns) {
      returnedByOrder[value.originalOrderId] =
          (returnedByOrder[value.originalOrderId] ?? 0.0) +
              value.returnedTotal;
    }
    final orderOutstanding = orders
        .where((order) => order.status != 'cancelled' && order.isCredit)
        .fold(0.0, (sum, order) {
      final outstanding = order.total -
          order.paidAmount -
          (returnedByOrder[order.id] ?? 0.0);
      return sum + (outstanding > 0 ? outstanding : 0.0);
    });
    final standaloneCollections = debtPayments
        .where((payment) => payment.allocations.isEmpty)
        .fold(0.0, (sum, payment) => sum + payment.amount);
    final reconciled = orderOutstanding - standaloneCollections;
    return reconciled > 0 ? reconciled : 0.0;
  }

  double get totalExpenses => expenses
      .where((expense) => !expense.isSupplierPayment && !expense.isCancelled)
      .fold(0.0, (sum, expense) => sum + expense.amount);

  /// Historical cost of sales before COGS reversals from returns.
  double get grossCOGS {
    if (!canViewCost) return 0.0;
    return orders
        .where((order) =>
            order.status != 'cancelled' && order.status != 'debt_repayment')
        .fold(0.0, (sum, order) {
      final protected = protectedOrderCosts[order.id];
      if (protected != null) return sum + protected;
      final legacy = order.items.fold<double>(
        0.0,
        (itemSum, item) =>
            itemSum + ((item.costPrice ?? 0.0) * item.quantity),
      );
      return sum + legacy;
    });
  }

  double get returnedCOGS {
    if (!canViewCost) return 0.0;
    return returns.fold(
      0.0,
      (sum, value) => sum + (protectedReturnCosts[value.id] ?? 0.0),
    );
  }

  /// Net historical COGS after return reversals in the report period.
  double get totalCOGS => grossCOGS - returnedCOGS;

  /// True only when every sale and every return in scope has an auditable
  /// historical cost source. This prevents presenting a misleading profit while
  /// a trusted return-cost snapshot is still pending.
  bool get isCOGSComplete {
    if (!canViewCost) return false;
    for (final order in orders.where((order) =>
        order.status != 'cancelled' && order.status != 'debt_repayment')) {
      if (protectedOrderCosts.containsKey(order.id)) continue;
      if (order.items.isNotEmpty &&
          order.items.every((item) => item.costPrice != null)) {
        continue;
      }
      return false;
    }
    for (final value in returns) {
      if (!protectedReturnCosts.containsKey(value.id)) return false;
    }
    return true;
  }

  double get grossTaxCollected => orders
          .where((order) =>
              order.status != 'cancelled' && order.status != 'debt_repayment')
          .fold(0.0, (sum, order) {
        double orderTax = 0.0;
        for (final item in order.items) {
          final itemTax = item.getEffectiveTax(defaultTaxPercentage);
          if (itemTax <= 0) continue;
          final isInclusive = item.isTaxInclusive ?? defaultIsTaxInclusive;
          final taxableBase = item.total - item.discountAmount;
          orderTax += isInclusive
              ? taxableBase - (taxableBase / (1 + (itemTax / 100)))
              : taxableBase * (itemTax / 100);
        }
        return sum + orderTax;
      });

  double get returnedTax =>
      returns.fold(0.0, (sum, value) => sum + value.returnedTax);

  double get totalTaxCollected => grossTaxCollected - returnedTax;

  double get netProfit =>
      netSalesRevenue - totalCOGS - totalExpenses;

  List<SalesData> getDailySales() {
    final Map<String, double> dailyMap = {};
    for (final order in orders) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment') {
        continue;
      }
      final dateStr =
          '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap[dateStr] = (dailyMap[dateStr] ?? 0.0) + order.total;
    }
    for (final value in returns) {
      final dateStr =
          '${value.createdAt.year}-${value.createdAt.month.toString().padLeft(2, '0')}-${value.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap[dateStr] =
          (dailyMap[dateStr] ?? 0.0) - value.returnedTotal;
    }
    final result = dailyMap.entries.map((entry) {
      final parts = entry.key.split('-');
      return SalesData(
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        entry.value,
      );
    }).toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<ProductSales> getBestSellers() {
    final Map<String, int> qtyMap = {};
    final Map<String, double> revenueMap = {};
    for (final order in orders) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment') {
        continue;
      }
      for (final item in order.items) {
        qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
        revenueMap[item.productId] =
            (revenueMap[item.productId] ?? 0.0) + item.total;
      }
    }
    for (final value in returns) {
      for (final item in value.returnedItems) {
        qtyMap[item.productId] =
            (qtyMap[item.productId] ?? 0) - item.quantity;
        revenueMap[item.productId] =
            (revenueMap[item.productId] ?? 0.0) - item.total;
      }
    }
    final List<ProductSales> bestSellers = [];
    for (final product in products) {
      if (!qtyMap.containsKey(product.id)) continue;
      final quantity = qtyMap[product.id] ?? 0;
      if (quantity <= 0) continue;
      bestSellers.add(ProductSales(
        product,
        quantity,
        revenueMap[product.id] ?? 0.0,
      ));
    }
    bestSellers.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    return bestSellers;
  }

  Map<String, double> getExpensesByCategory() {
    final Map<String, double> expensesByCategory = {};
    for (final expense in expenses) {
      if (expense.isCancelled || expense.isSupplierPayment) continue;
      final categoryName = expense.category ?? 'أخرى';
      expensesByCategory[categoryName] =
          (expensesByCategory[categoryName] ?? 0.0) + expense.amount;
    }
    return expensesByCategory;
  }

  /// Gross money received. Refunds are intentionally separate cash-out
  /// movements and are not subtracted here.
  Map<String, double> get paymentMethodsBreakdown =>
      ReportCashflowLedger.paymentMethods(
        orders: orders,
        debtPayments: debtPayments,
      );
}

bool _canViewReports(ref) {
  return ref.watch(accessPolicyProvider).canViewReports;
}

final branchOrderCostsProvider = StreamProvider<Map<String, double>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.canViewCosts) {
    return Stream.value(const <String, double>{});
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  final branchId = ref.watch(selectedBranchIdProvider);
  return OrderCostSnapshotRepository(FirebaseFirestore.instance)
      .watchBranchOrderCosts(merchantId, branchId);
});

final merchantOrderCostsProvider = StreamProvider<Map<String, double>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.isOwnerLike || !policy.canViewCosts) {
    return Stream.value(const <String, double>{});
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  return OrderCostSnapshotRepository(FirebaseFirestore.instance)
      .watchOrderCosts(merchantId);
});

final branchReturnCostsProvider = StreamProvider<Map<String, double>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.canViewCosts || !policy.canViewReports) {
    return Stream.value(const <String, double>{});
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  final branchId = ref.watch(selectedBranchIdProvider);
  return ReturnCostSnapshotRepository(FirebaseFirestore.instance)
      .watchBranchReturnCosts(merchantId, branchId);
});

final merchantReturnCostsProvider = StreamProvider<Map<String, double>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null ||
      !policy.isOwnerLike ||
      !policy.canViewCosts ||
      !policy.canViewReports) {
    return Stream.value(const <String, double>{});
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  return ReturnCostSnapshotRepository(FirebaseFirestore.instance)
      .watchReturnCosts(merchantId);
});

final reportsServiceProvider = Provider<ReportsService?>((ref) {
  if (!_canViewReports(ref)) return null;
  final ordersState = ref.watch(ordersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(expensesStreamProvider);
  final customersState = ref.watch(customersStreamProvider);
  final policy = ref.watch(accessPolicyProvider);
  final suppliersState = policy.canManageSuppliers
      ? ref.watch(suppliersStreamProvider)
      : const AsyncValue.data(<Supplier>[]);
  final debtPaymentsState = ref.watch(branchCustomerDebtPaymentsProvider);
  final returnsState = ref.watch(branchOrderReturnsProvider);
  final storeProfileState = ref.watch(storeProfileProvider);
  final costsState = ref.watch(branchOrderCostsProvider);
  final returnCostsState = ref.watch(branchReturnCostsProvider);
  final canViewCost = policy.canViewCosts;

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null ||
      debtPaymentsState.value == null ||
      returnsState.value == null ||
      (canViewCost &&
          (costsState.value == null || returnCostsState.value == null))) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    debtPayments: debtPaymentsState.value!,
    returns: returnsState.value!,
    protectedOrderCosts: costsState.value ?? const {},
    protectedReturnCosts: returnCostsState.value ?? const {},
    canViewCost: canViewCost,
    defaultTaxPercentage: storeProfileState.value?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive:
        storeProfileState.value?.defaultIsTaxInclusive ?? true,
  );
});

final merchantWideOrdersStreamProvider = StreamProvider<List<AppOrder>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.isOwnerLike) {
    return Stream.value(const <AppOrder>[]);
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  final repository = OrderRepository(FirebaseFirestore.instance);
  return repository.queryOrders(merchantId).snapshots().map((snapshot) {
    final values = snapshot.docs.map((doc) => doc.data()).toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  });
});

final merchantWideExpensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.isOwnerLike) {
    return Stream.value(const <Expense>[]);
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  return FirebaseFirestore.instance
      .collection('merchants')
      .doc(merchantId)
      .collection('expenses')
      .snapshots()
      .map((snapshot) {
    final values = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['merchantId'] = data['merchantId']?.toString() ?? merchantId;
      data['branchId'] = data['branchId']?.toString() ?? 'main';
      data['amount'] = (data['amount'] as num?)?.toDouble() ?? 0.0;
      return Expense.fromJson(data);
    }).toList();
    values.sort((a, b) => b.date.compareTo(a.date));
    return values;
  });
});

final consolidatedReportsServiceProvider = Provider<ReportsService?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  final policy = ref.watch(accessPolicyProvider);
  if (appUser == null || !policy.isOwnerLike || !policy.canViewReports) {
    return null;
  }

  final ordersState = ref.watch(merchantWideOrdersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(merchantWideExpensesStreamProvider);
  final customersState = ref.watch(customersStreamProvider);
  final suppliersState = policy.canManageSuppliers
      ? ref.watch(suppliersStreamProvider)
      : const AsyncValue.data(<Supplier>[]);
  final debtPaymentsState = ref.watch(merchantCustomerDebtPaymentsProvider);
  final returnsState = ref.watch(merchantOrderReturnsProvider);
  final storeProfileState = ref.watch(storeProfileProvider);
  final costsState = ref.watch(merchantOrderCostsProvider);
  final returnCostsState = ref.watch(merchantReturnCostsProvider);
  final canViewCost = policy.canViewCosts;

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null ||
      debtPaymentsState.value == null ||
      returnsState.value == null ||
      (canViewCost &&
          (costsState.value == null || returnCostsState.value == null))) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    debtPayments: debtPaymentsState.value!,
    returns: returnsState.value!,
    protectedOrderCosts: costsState.value ?? const {},
    protectedReturnCosts: returnCostsState.value ?? const {},
    canViewCost: canViewCost,
    defaultTaxPercentage: storeProfileState.value?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive:
        storeProfileState.value?.defaultIsTaxInclusive ?? true,
  );
});

final activeReportsServiceProvider = Provider<ReportsService?>((ref) {
  if (!_canViewReports(ref)) return null;
  final scope = ref.watch(effectiveReportsScopeProvider);
  return scope == ReportsScope.merchant
      ? ref.watch(consolidatedReportsServiceProvider)
      : ref.watch(reportsServiceProvider);
});
