import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import '../../orders/domain/order.dart';
import '../domain/customer.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/utils/date_parser.dart';

part 'customer_statement_provider.g.dart';

enum StatementItemType {
  initialBalance,
  creditInvoice,
  payment,
  cancelledInvoice,
}

class CustomerStatementItem {
  final StatementItemType type;
  final double amount; // Positive means debt increase, Negative means debt decrease (payment)
  final double runningBalance;
  final DateTime date;
  final String? referenceId;
  final String? paymentMethod;

  CustomerStatementItem({
    required this.type,
    required this.amount,
    required this.runningBalance,
    required this.date,
    this.referenceId,
    this.paymentMethod,
  });
}

@riverpod
Stream<List<CustomerStatementItem>> customerStatement(CustomerStatementRef ref, Customer customer) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final merchantId = appUser.merchantId ?? appUser.id;
  final firestore = FirebaseFirestore.instance;

  final ordersStream = firestore
      .collection('orders')
      .where('merchantId', isEqualTo: merchantId)
      .where('customerId', isEqualTo: customer.id)
      .where('isCredit', isEqualTo: true)
      .snapshots();

  final paymentsStream = firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('payments')
      .where('customerId', isEqualTo: customer.id)
      .snapshots();

  return CombineLatestStream.combine2(
    ordersStream,
    paymentsStream,
    (QuerySnapshot ordersSnap, QuerySnapshot paymentsSnap) {
      List<CustomerStatementItem> items = [];

      if (customer.initialDebt != null && customer.initialDebt! > 0) {
        items.add(
          CustomerStatementItem(
            type: StatementItemType.initialBalance,
            amount: customer.initialDebt!,
            runningBalance: 0,
            date: customer.createdAt,
          ),
        );
      }

      for (var doc in ordersSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final order = AppOrder.fromJson(data);
        
        final debtAdded = order.total - (order.initialPaidAmount ?? order.paidAmount);
        
        if (order.status == 'cancelled') {
          items.add(
            CustomerStatementItem(
              type: StatementItemType.creditInvoice,
              amount: debtAdded,
              runningBalance: 0,
              date: order.createdAt,
              referenceId: order.id,
              paymentMethod: order.paymentMethod,
            ),
          );
          
          items.add(
            CustomerStatementItem(
              type: StatementItemType.cancelledInvoice,
              amount: -debtAdded,
              runningBalance: 0,
              date: order.createdAt.add(const Duration(seconds: 1)),
              referenceId: order.id,
              paymentMethod: order.paymentMethod,
            ),
          );
        } else {
          items.add(
            CustomerStatementItem(
              type: StatementItemType.creditInvoice,
              amount: debtAdded,
              runningBalance: 0,
              date: order.createdAt,
              referenceId: order.id,
              paymentMethod: order.paymentMethod,
            ),
          );
        }
      }

      for (var doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final date = safeParseDate(data['createdAt']);
        final paymentMethod = data['paymentMethod'] as String?;
        
        items.add(
          CustomerStatementItem(
            type: StatementItemType.payment,
            amount: -amount,
            runningBalance: 0,
            date: date,
            referenceId: doc.id,
            paymentMethod: paymentMethod,
          ),
        );
      }

      items.sort((a, b) => a.date.compareTo(b.date));

      double currentBalance = 0.0;
      List<CustomerStatementItem> computedItems = [];
      
      for (var item in items) {
        if (item.amount == 0 && item.type != StatementItemType.initialBalance) continue; // Skip zero-effect items if any
        currentBalance += item.amount;
        computedItems.add(
          CustomerStatementItem(
            type: item.type,
            amount: item.amount,
            runningBalance: currentBalance,
            date: item.date,
            referenceId: item.referenceId,
            paymentMethod: item.paymentMethod,
          ),
        );
      }

      return computedItems.reversed.toList();
    },
  );
}
