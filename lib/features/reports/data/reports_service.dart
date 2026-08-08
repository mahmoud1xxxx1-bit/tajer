import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/store_profile_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../../customers/data/customer_debt_payment_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/customer_debt_payment.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/supplier.dart';
import 'report_cashflow_ledger.dart';

enum ReportsScope {
  branch,
  merchant,
}

ReportsScope resolveReportsScope({
  required String? role,
  required ReportsScope requested,
}) {
  return role == 'merchant' ? requested : ReportsScope.branch;
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
  final double defaultTaxPercentage;
  final bool defaultIsTaxInclusive;

  ReportsService(
    this.orders,
    this.products,
    this.expenses,
    this.customers,
    this.suppliers, {
    this.debtPayments = const [],
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

    return ReportsService(
      filteredOrders,
      products,
      filteredExpenses,
      customers,
      suppliers,
      debtPayments: filteredDebtPayments,
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

  double get totalCOGS => orders
      .where((order) =>
          order.status != 'cancelled' && order.status != 'debt_repayment')
      .fold(0.0, (sum, order) {
    return sum +
        order.items.fold(
          0.0,
          (itemSum, item) =>
              itemSum + ((item.costPrice ?? 0.0) * item.quantity),
        );
  });

  double get totalTaxCollected => orders
      .where((order) =>
          order.status != 'cancelled' && order.status != 'debt_repayment')
      .fold(0.0, (sum, order) {
    double orderTax = 0.0;
    for (final item in order.items) {
      final itemTax = item.taxPercentage ?? defaultTaxPercentage;
      if (itemTax <= 0) continue;

      final isInclusive = item.isTaxInclusive ?? defaultIsTaxInclusive;
      if (isInclusive) {
        orderTax += item.total - (item.total / (1 + (itemTax / 100)));
      } else {
        orderTax += item.total * (itemTax / 100);
      }
    }
    return sum + orderTax;
  });

  double get netProfit =>
      totalRevenue - totalTaxCollected - totalCOGS - totalExpenses;

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

    final result = dailyMap.entries.map((entry) {
      final parts = entry.key.split('-');
      final date =
          DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return SalesData(date, entry.value);
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

    final List<ProductSales> bestSellers = [];
    for (final product in products) {
      if (!qtyMap.containsKey(product.id)) continue;
      bestSellers.add(
        ProductSales(
          product,
          qtyMap[product.id]!,
          revenueMap[product.id]!,
        ),
      );
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

/// Branch-scoped report used by the normal report screen.
/// Permission is enforced here as well as in the UI so a hidden tab is never
/// the only barrier protecting financial report aggregation.
final reportsServiceProvider = Provider<ReportsService?>((ref) {
  if (!_canViewReports(ref)) return null;

  final ordersState = ref.watch(ordersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(expensesStreamProvider);
  final customersState = ref.watch(customersStreamProvider);
  final suppliersState = ref.watch(suppliersStreamProvider);
  final debtPaymentsState = ref.watch(branchCustomerDebtPaymentsProvider);
  final storeProfileState = ref.watch(storeProfileProvider);

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null ||
      debtPaymentsState.value == null) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    debtPayments: debtPaymentsState.value!,
    defaultTaxPercentage:
        storeProfileState.value?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive:
        storeProfileState.value?.defaultIsTaxInclusive ?? true,
  );
});

/// Merchant-wide orders are owner/admin-only even if this provider is invoked
/// directly by another screen in the future.
final merchantWideOrdersStreamProvider = StreamProvider<List<AppOrder>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null ||
      (appUser.role != 'merchant' && appUser.role != 'admin')) {
    return Stream.value(const <AppOrder>[]);
  }

  final merchantId = appUser.merchantId ?? appUser.id;
  final repository = OrderRepository(FirebaseFirestore.instance);
  return repository.queryOrders(merchantId).snapshots().map((snapshot) {
    final values = snapshot.docs.map((doc) => doc.data()).toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  });
});

/// Merchant-wide expense source for consolidated reports is owner/admin-only.
final merchantWideExpensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null ||
      (appUser.role != 'merchant' && appUser.role != 'admin')) {
    return Stream.value(const <Expense>[]);
  }

  final merchantId = appUser.merchantId ?? appUser.id;
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

/// Consolidated merchant report: all branches for sales, expenses, and debt
/// collections. It is never constructed for an employee account.
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

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null ||
      debtPaymentsState.value == null) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    debtPayments: debtPaymentsState.value!,
    defaultTaxPercentage:
        storeProfileState.value?.defaultTaxPercentage ?? 0.0,
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
