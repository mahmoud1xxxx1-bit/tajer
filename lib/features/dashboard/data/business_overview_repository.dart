import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/domain/order.dart';
import '../../expenses/domain/expense.dart';
import '../../customers/domain/customer_debt_payment.dart';

class BusinessOverviewRepository {
  final FirebaseFirestore _firestore;
  
  BusinessOverviewRepository(this._firestore);
  
  Future<List<AppOrder>> getOrders(String merchantId, DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
        
    return query.docs.map((doc) => AppOrder.fromJson(doc.data())).toList();
  }
  
  Future<List<Expense>> getExpenses(String merchantId, DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();
        
    return query.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return Expense.fromJson(data);
    }).toList();
  }
  
  Future<List<CustomerDebtPayment>> getDebtPayments(String merchantId, DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('customer_debt_payments')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
        
    return query.docs.map((doc) => CustomerDebtPayment.fromJson(doc.data())).toList();
  }
}

final businessOverviewRepositoryProvider = Provider((ref) {
  return BusinessOverviewRepository(FirebaseFirestore.instance);
});
