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
  final double amount;
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
Stream<List<CustomerStatementItem>> customerStatement(
  CustomerStatementRef ref,
  Customer customer,
  int limit,
) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return const Stream.empty();

  final merchantId = appUser.merchantId ?? appUser.id;
  final firestore = FirebaseFirestore.instance;
  final safeLimit = limit < 50 ? 50 : limit;

  // Read only the newest documents needed for the visible statement page.
  // Each source is independently limited, then both are merged and trimmed to
  // the requested combined size. Historical documents stay in Firestore.
  final ordersStream = firestore
      .collection('orders')
      .where('merchantId', isEqualTo: merchantId)
      .where('customerId', isEqualTo: customer.id)
      .where('isCredit', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(safeLimit)
      .snapshots();

  final paymentsStream = firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('payments')
      .where('customerId', isEqualTo: customer.id)
      .orderBy('createdAt', descending: true)
      .limit(safeLimit)
      .snapshots();

  return CombineLatestStream.combine2(
    ordersStream,
    paymentsStream,
    (QuerySnapshot ordersSnap, QuerySnapshot paymentsSnap) {
      final items = <CustomerStatementItem>[];

      for (final doc in ordersSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final order = AppOrder.fromJson(data);
        final debtAdded = order.total - (order.initialPaidAmount ?? order.paidAmount);

        if (debtAdded.abs() <= 0.001) continue;

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

        if (order.status == 'cancelled') {
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
        }
      }

      for (final doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount.abs() <= 0.001) continue;

        items.add(
          CustomerStatementItem(
            type: StatementItemType.payment,
            amount: -amount,
            runningBalance: 0,
            date: safeParseDate(data['createdAt']),
            referenceId: doc.id,
            paymentMethod: data['paymentMethod'] as String?,
          ),
        );
      }

      items.sort((a, b) => b.date.compareTo(a.date));
      final visible = items.take(safeLimit).toList();

      // The customer document is the authoritative current debt. Computing
      // backwards lets us show correct running balances without reading years
      // of historical invoices/payments just to open the statement.
      var balanceAfterItem = customer.totalDebt;
      final computed = <CustomerStatementItem>[];
      for (final item in visible) {
        computed.add(
          CustomerStatementItem(
            type: item.type,
            amount: item.amount,
            runningBalance: balanceAfterItem,
            date: item.date,
            referenceId: item.referenceId,
            paymentMethod: item.paymentMethod,
          ),
        );
        balanceAfterItem -= item.amount;
      }

      return computed;
    },
  );
}
