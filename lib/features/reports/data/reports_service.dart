import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/store_profile_provider.dart';
import '../../authentication/data/auth_repository.dart';
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
import '../../orders/domain/order.dart';
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
  final Map<String, double> protectedOrderCosts;
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
    this.protectedOrderCosts = const {},
    this.canViewCost = true,
    this.defaultTaxPercentage = 0.0,
    this.defaultIsTaxInclusive = true,
  });

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
    final filteredIds = filteredOrders.map((order) => order.id).toSet();
    final filteredProtectedCosts = <String, double>{
      for (final entry in protectedOrderCosts.entries)
        if (filteredIds.contains(entry.key)) entry.key: entry.value,
    };

    return ReportsService(
      filteredOrders,
      products,
      filteredExpenses,
      customers,
      suppliers,
      debtPayments: filteredDebtPayments,
      protectedOrderCosts: filteredProtectedCosts,
      canViewCost: canViewCost,
      defaultTaxPercentage: defaultTaxPercentage,
      defaultIsTaxInclusive: defaultIsTaxInclusive,
    );
  }

  double get totalRevenue => orders
      .where((order) =>
          order.status != 'cancelled' && order.status != 'debt_repayment')
      .fold(0.0, (sum, order) => sum + order.total);

  double get netSalesRevenue => totalRevenue - totalTaxCollected;

  double get totalDebt => orders
      .where((order) => order.status != 'cancelled' && order.isCredit)
      .fold(0.0, (sum, order) => sum + (order.total - order.paidAmount));

  double get totalExpenses => expenses
      .where((expense) => !expense.isSupplierPayment && !expense.isCancelled)
      .fold(0.0, (sum, expense) => sum + expense.amount);

  /// Cost is never inferred from current product prices. A protected historical
  /// snapshot wins. Legacy in-memory item cost is accepted only as a v107
  /// compatibility fallback until the merchant migration has copied it into the
  /// protected collection.
  double get totalCOGS {
    if (!canViewCost) return 0.0;
    return orders
        .where((order) =>
            order.status != 'cancelled' && order.status != 'debt_repayment')
        .fold(0.0, (sum, order) {
      final protected = protectedOrderCosts[order.id];
      if (protected != null) return sum + protected;
      final legacy = order.items.fold<double>(
        0.0,
        (itemSum, item) => itemSum + ((item.costPrice ?? 0.0) * item.quantity),
      );
      return sum + legacy;
    });
  }

  /// True only when every non-cancelled sale has an auditable historical cost
  /// source. Callers can use this to avoid presenting a misleading profit.
  bool get isCOGSComplete {
    if (!canViewCost) return false;
    for (final order in orders.where((order) =>
        order.status != 'cancelled' && order.status != 'debt_repayment')) {
      if (protectedOrderCosts.containsKey(order.id)) continue;
      if (order.items.isNotEmpty &&
          order.items.every((item) => item.costPrice != null)) continue;
      return false;
    }
    return true;
  }

  double get totalTaxCollected => orders
          .where((order) =>
              order.status != 'cancelled' && order.status != 'debt_repayment')
          .fold(0.0, (sum, order) {
        double orderTax = 0.0;
        for (final item in order.items) {
          final itemTax = item.taxPercentage ?? defaultTaxPercentage;
          if (itemTax <= 0) continue;
          final isInclusive = item.isTaxInclusive ?? defaultIsTaxInclusive;
          orderTax += isInclusive
              ? item.total - (item.total / (1 + (itemTax / 100)))
              : item.total * (itemTax / 100);
        }
        return sum + orderTax;
      });

  double get netProfit =>
      totalRevenue - totalTaxCollected - totalCOGS - totalExpenses;

  List<SalesData> getDailySales() {
    final Map<String, double> dailyMap = {};
    for (final order in orders) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment')
        continue;
      final dateStr =
          '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap[dateStr] = (dailyMap[dateStr] ?? 0.0) + order.total;
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
      if (order.status == 'cancelled' || order.status == 'debt_repayment')
        continue;
      for (final item in order.items) {
        qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
        revenueMap[item.productId] =
            (revenueMap[item.productId] ?? 0.0) + item.total;
      }
    }
    final List<ProductSales> bestSellers = [];
    for (final product in products) {
      if (!qtyMap.containsKey(product.id)) continue;
      bestSellers.add(ProductSales(
        product,
        qtyMap[product.id]!,
        revenueMap[product.id]!,
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

  Map<String, double> get paymentMethodsBreakdown =>
      ReportCashflowLedger.paymentMethods(
        orders: orders,
        debtPayments: debtPayments,
      );
}

bool _canViewReports(ref) {
  final appUser = ref.watch(appUserProvider).value;
  return appUser != null && appUser.hasPermission('can_view_reports');
}

final branchOrderCostsProvider = StreamProvider<Map<String, double>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null ||
      !appUser.hasPermission('can_view_reports') ||
      !appUser.hasPermission('can_view_cost')) {
    return Stream.value(const <String, double>{});
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  final branchId = ref.watch(selectedBranchIdProvider);
  return OrderCostSnapshotRepository(FirebaseFirestore.instance)
      .watchBranchOrderCosts(merchantId, branchId);
});

final merchantOrderCostsProvider = StreamProvider<Map<String, double>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null ||
      (appUser.role != 'merchant' && appUser.role != 'admin') ||
      !appUser.hasPermission('can_view_reports') ||
      !appUser.hasPermission('can_view_cost')) {
    return Stream.value(const <String, double>{});
  }
  final merchantId = currentEffectiveMerchantId(appUser);
  return OrderCostSnapshotRepository(FirebaseFirestore.instance)
      .watchOrderCosts(merchantId);
});

final reportsServiceProvider = Provider<ReportsService?>((ref) {
  if (!_canViewReports(ref)) return null;
  final appUser = ref.watch(appUserProvider).value!;
  final ordersState = ref.watch(ordersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(expensesStreamProvider);
  final customersState = ref.watch(customersStreamProvider);
  final suppliersState = ref.watch(suppliersStreamProvider);
  final debtPaymentsState = ref.watch(branchCustomerDebtPaymentsProvider);
  final storeProfileState = ref.watch(storeProfileProvider);
  final costsState = ref.watch(branchOrderCostsProvider);
  final canViewCost = appUser.hasPermission('can_view_cost');

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null ||
      debtPaymentsState.value == null ||
      (canViewCost && costsState.value == null)) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    debtPayments: debtPaymentsState.value!,
    protectedOrderCosts: costsState.value ?? const {},
    canViewCost: canViewCost,
    defaultTaxPercentage: storeProfileState.value?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive:
        storeProfileState.value?.defaultIsTaxInclusive ?? true,
  );
});

final merchantWideOrdersStreamProvider = StreamProvider<List<AppOrder>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null ||
      (appUser.role != 'merchant' && appUser.role != 'admin')) {
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
  if (appUser == null ||
      (appUser.role != 'merchant' && appUser.role != 'admin')) {
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
  if (appUser == null ||
      (appUser.role != 'merchant' && appUser.role != 'admin') ||
      !appUser.hasPermission('can_view_reports')) {
    return null;
  }

  final ordersState = ref.watch(merchantWideOrdersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(merchantWideExpensesStreamProvider);
  final customersState = ref.watch(customersStreamProvider);
  final suppliersState = ref.watch(suppliersStreamProvider);
  final debtPaymentsState = ref.watch(merchantCustomerDebtPaymentsProvider);
  final storeProfileState = ref.watch(storeProfileProvider);
  final costsState = ref.watch(merchantOrderCostsProvider);
  final canViewCost = appUser.hasPermission('can_view_cost');

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null ||
      debtPaymentsState.value == null ||
      (canViewCost && costsState.value == null)) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    debtPayments: debtPaymentsState.value!,
    protectedOrderCosts: costsState.value ?? const {},
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
