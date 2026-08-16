import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/customer.dart';
import '../data/customer_statement_provider.dart';
import '../../../core/providers/settings_provider.dart';

class CustomerStatementScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerStatementScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends ConsumerState<CustomerStatementScreen> {
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final statementAsync = ref.watch(customerStatementProvider(widget.customer, _limit));
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'كشف حساب: ${widget.customer.name}' : 'Statement: ${widget.customer.name}',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: statementAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Column(
              children: [
                _buildSummaryCard(context, widget.customer, currency, isAr),
                Expanded(
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد حركات مالية مسجلة.' : 'No financial transactions recorded.',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            );
          }

          final canLoadMore = items.length >= _limit;
          return Column(
            children: [
              _buildSummaryCard(context, widget.customer, currency, isAr),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + (canLoadMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _limit += 50),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            isAr ? 'عرض 50 حركة إضافية' : 'Load 50 more transactions',
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                    return _buildStatementItemCard(context, items[index], currency, isAr);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr ? 'تعذر تحميل كشف الحساب. حاول مرة أخرى.' : 'Could not load the account statement. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Customer customer, String currency, bool isAr) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isAr ? 'الرصيد الحالي' : 'Current Balance', style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Tajawal')),
              const SizedBox(height: 8),
              Text('${customer.totalDebt.toStringAsFixed(2)} $currency', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            ],
          ),
          const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildStatementItemCard(BuildContext context, CustomerStatementItem item, String currency, bool isAr) {
    late final IconData icon;
    late final Color iconColor;
    late String title;

    switch (item.type) {
      case StatementItemType.initialBalance:
        icon = Icons.account_balance;
        iconColor = Colors.blue;
        title = isAr ? 'رصيد افتتاحي' : 'Opening Balance';
        break;
      case StatementItemType.creditInvoice:
        icon = Icons.receipt_long;
        iconColor = Colors.orange;
        title = isAr ? 'فاتورة آجلة' : 'Credit Invoice';
        if (item.referenceId != null) title += ' #${item.referenceId!.substring(0, 5)}';
        break;
      case StatementItemType.payment:
        icon = Icons.payments;
        iconColor = Colors.green;
        title = isAr ? 'سداد' : 'Payment';
        if (item.paymentMethod != null) title += ' (${_getPaymentMethodName(item.paymentMethod!, isAr)})';
        break;
      case StatementItemType.cancelledInvoice:
        icon = Icons.cancel;
        iconColor = Colors.red;
        title = isAr ? 'إلغاء فاتورة' : 'Invoice Cancelled';
        if (item.referenceId != null) title += ' #${item.referenceId!.substring(0, 5)}';
        break;
    }

    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final isPositive = item.amount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(item.date), style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Tajawal')),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${item.amount.toStringAsFixed(2)} $currency',
                  style: TextStyle(color: isPositive ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isAr ? 'رصيد:' : 'Bal:'} ${item.runningBalance.toStringAsFixed(2)} $currency',
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Tajawal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodName(String method, bool isAr) {
    switch (method) {
      case 'cash':
        return isAr ? 'كاش' : 'Cash';
      case 'card':
        return isAr ? 'شبكة' : 'Card';
      case 'transfer':
        return isAr ? 'تحويل' : 'Transfer';
      case 'split':
        return isAr ? 'مقسم' : 'Split';
      default:
        return method;
    }
  }
}
