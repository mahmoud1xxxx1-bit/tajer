import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';

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

  ReportsService(this.orders, this.products, this.expenses);

  double get totalRevenue => orders.where((o) => o.status != 'cancelled').fold(0.0, (sum, order) => sum + order.total);
  
  double get totalDebt => orders.where((o) => o.status != 'cancelled' && o.isCredit).fold(0.0, (sum, order) => sum + (order.total - order.paidAmount));

  double get totalExpenses => expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  double get netProfit => totalRevenue - totalExpenses;

  List<SalesData> getDailySales() {
    final Map<String, double> dailyMap = {};
    for (var order in orders) {
      if (order.status == 'cancelled') continue;
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
      if (order.status == 'cancelled') continue;
      
      qtyMap[order.productId] = (qtyMap[order.productId] ?? 0) + order.quantity;
      revenueMap[order.productId] = (revenueMap[order.productId] ?? 0.0) + order.total;
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
}

final reportsServiceProvider = Provider<ReportsService?>((ref) {
  final ordersState = ref.watch(ordersStreamProvider);
  final productsState = ref.watch(productsStreamProvider);
  final expensesState = ref.watch(expensesStreamProvider);

  if (ordersState.value == null || productsState.value == null || expensesState.value == null) {
    return null; // Still loading
  }

  return ReportsService(ordersState.value!, productsState.value!, expensesState.value!);
});
