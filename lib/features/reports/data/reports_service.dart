import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../customers/domain/customer.dart';
import '../../suppliers/domain/supplier.dart';
import '../../customers/data/customer_repository.dart';
import '../../suppliers/data/supplier_repository.dart';

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
  final double defaultTaxPercentage;
  final bool defaultIsTaxInclusive;

  ReportsService(
    this.orders,
    this.products,
    this.expenses,
    this.customers,
    this.suppliers, {
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

    return ReportsService(
      filteredOrders,
      products,
      filteredExpenses,
      customers,
      suppliers,
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

  Map<String, double> get paymentMethodsBreakdown {
    final Map<String, double> breakdown = {};

    void add(String method, double amount) {
      if (amount <= 0) return;
      breakdown[method] = (breakdown[method] ?? 0.0) + amount;
    }

    for (final order in orders) {
      if (order.status == 'cancelled') continue;

      final method = order.paymentMethod ?? 'cash';

      // Split payments must be reported by their actual cash/network portions,
      // never as one synthetic payment-method bucket.
      if (method == 'split' ||
          order.splitCashAmount != null ||
          order.splitNetworkAmount != null) {
        add('cash', order.splitCashAmount ?? 0.0);
        add('card', order.splitNetworkAmount ?? 0.0);
        continue;
      }

      double amount = order.total;
      if (order.isCredit || order.status == 'debt_repayment') {
        amount = order.paidAmount;
      }
      add(method, amount);
    }

    return breakdown;
  }
}

final reportsServiceProvider = Provider<ReportsService?>((ref) {
  final ordersState = ref.watch(ordersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(expensesStreamProvider);
  final customersState = ref.watch(customersStreamProvider);
  final suppliersState = ref.watch(suppliersStreamProvider);
  final storeProfileState = ref.watch(storeProfileProvider);

  if (ordersState.value == null ||
      productsState.value == null ||
      expensesState.value == null ||
      customersState.value == null ||
      suppliersState.value == null) {
    return null;
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    defaultTaxPercentage:
        storeProfileState.value?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive:
        storeProfileState.value?.defaultIsTaxInclusive ?? true,
  );
});