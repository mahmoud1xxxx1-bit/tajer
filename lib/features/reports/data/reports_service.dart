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

  ReportsService(this.orders, this.products, this.expenses, this.customers, this.suppliers, {this.defaultTaxPercentage = 0.0, this.defaultIsTaxInclusive = true});

  ReportsService filterByDate(DateTime start, DateTime end) {
    final filteredOrders = orders.where((o) => o.createdAt.isAfter(start) && o.createdAt.isBefore(end)).toList();
    final filteredExpenses = expenses.where((e) => e.date.isAfter(start) && e.date.isBefore(end)).toList();
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

  double get totalRevenue => orders.where((o) => o.status != 'cancelled' && o.status != 'debt_repayment').fold(0.0, (sum, order) => sum + order.total);
  
  double get netSalesRevenue => totalRevenue - totalTaxCollected;

  double get totalDebt => orders.where((o) => o.status != 'cancelled' && o.isCredit).fold(0.0, (sum, order) => sum + (order.total - order.paidAmount));

  double get totalExpenses => expenses.where((e) => !e.isSupplierPayment && !e.isCancelled).fold(0.0, (sum, expense) => sum + expense.amount);

  double get totalCOGS => orders.where((o) => o.status != 'cancelled' && o.status != 'debt_repayment').fold(0.0, (sum, order) {
    return sum + order.items.fold(0.0, (itemSum, item) => itemSum + ((item.costPrice ?? 0.0) * item.quantity));
  });

  double get totalTaxCollected => orders.where((o) => o.status != 'cancelled' && o.status != 'debt_repayment').fold(0.0, (sum, order) {
    double orderTax = 0.0;
    for (final item in order.items) {
      final itemTax = item.taxPercentage ?? defaultTaxPercentage;
      if (itemTax > 0) {
        final isInclusive = item.isTaxInclusive ?? defaultIsTaxInclusive;
        if (isInclusive) {
          orderTax += item.total - (item.total / (1 + (itemTax / 100)));
        } else {
          orderTax += item.total * (itemTax / 100);
        }
      }
    }
    return sum + orderTax;
  });

  double get netProfit => totalRevenue - totalTaxCollected - totalCOGS - totalExpenses;

  List<SalesData> getDailySales() {
    final Map<String, double> dailyMap = {};
    for (var order in orders) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment') continue;
      final dateStr = '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}';
      dailyMap[dateStr] = (dailyMap[dateStr] ?? 0.0) + order.total;
    }
    
    final result = dailyMap.entries.map((e) {
      final parts = e.key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return SalesData(date, e.value);
    }).toList();
    
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<ProductSales> getBestSellers() {
    final Map<String, int> qtyMap = {};
    final Map<String, double> revenueMap = {};
    
    for (var order in orders) {
      if (order.status == 'cancelled' || order.status == 'debt_repayment') continue;
      
      for (var item in order.items) {
        qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
        revenueMap[item.productId] = (revenueMap[item.productId] ?? 0.0) + (item.quantity * item.price);
      }
    }

    final List<ProductSales> bestSellers = [];
    for (var product in products) {
      if (qtyMap.containsKey(product.id)) {
        bestSellers.add(
          ProductSales(product, qtyMap[product.id]!, revenueMap[product.id]!),
        );
      }
    }
    
    // Sort by quantity sold descending
    bestSellers.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    return bestSellers;
  }

  Map<String, double> getExpensesByCategory() {
    final Map<String, double> expensesByCategory = {};
    for (var expense in expenses) {
      if (expense.isCancelled || expense.isSupplierPayment) continue;
      final categoryName = expense.category ?? 'أخرى';
      expensesByCategory[categoryName] = (expensesByCategory[categoryName] ?? 0.0) + expense.amount;
    }
    return expensesByCategory;
  }

  Map<String, double> get paymentMethodsBreakdown {
    final Map<String, double> breakdown = {};
    for (var order in orders) {
      if (order.status == 'cancelled') continue;
      
      String method = order.paymentMethod ?? 'cash';
      
      if (order.status == 'debt_repayment' || order.isCredit) {
         // Credit orders paid amount goes to their respective payment methods later, 
         // but for simplicity, we can categorize the paidAmount of credit orders or debt repayments.
         // Wait, to keep it accurate for the simple merchant:
         // The actual cash/card currently in the drawer is the order.paidAmount (if it's a credit order).
      }
      
      // Let's strictly use order.total for regular orders, and order.paidAmount for credit.
      // Wait, if it's debt_repayment, it uses order.paidAmount (which is the repayment amount).
      double amount = order.total;
      if (order.isCredit) {
        amount = order.paidAmount; // Only what they paid upfront goes into the drawer/bank
      }
      if (order.status == 'debt_repayment') {
        amount = order.paidAmount;
      }
      
      breakdown[method] = (breakdown[method] ?? 0.0) + amount;
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

  if (ordersState.value == null || productsState.value == null || expensesState.value == null || customersState.value == null || suppliersState.value == null) {
    return null; // Still loading
  }

  return ReportsService(
    ordersState.value!,
    productsState.value!,
    expensesState.value!,
    customersState.value!,
    suppliersState.value!,
    defaultTaxPercentage: storeProfileState.value?.defaultTaxPercentage ?? 0.0,
    defaultIsTaxInclusive: storeProfileState.value?.defaultIsTaxInclusive ?? true,
  );
});
