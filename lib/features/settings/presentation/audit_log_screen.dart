import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/date_parser.dart';
import '../../authentication/data/auth_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_details_screen.dart';

class AuditLogItem {
  final String id;
  final String title;
  final String subtitle;
  final String details;
  final DateTime timestamp;
  final String performedBy;
  final String type;
  final double amount;
  final AppOrder? order;
  final Color badgeColor;

  AuditLogItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.details = '',
    required this.timestamp,
    required this.performedBy,
    required this.type,
    this.amount = 0.0,
    this.order,
    required this.badgeColor,
  });
}

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  int _limit = 50;
  int _refreshTick = 0;

  Future<List<AuditLogItem>> _loadItems({
    required String merchantId,
    required bool isAr,
  }) async {
    final orderRepository = ref.read(orderRepositoryProvider);
    final expenseRepository = ref.read(expenseRepositoryProvider);
    final firestore = FirebaseFirestore.instance;

    final ordersFuture = orderRepository
        .queryOrders(merchantId: merchantId)
        .limit(_limit)
        .get();

    final expensesFuture = expenseRepository == null
        ? Future<QuerySnapshot<dynamic>?>.value(null)
        : expenseRepository
            .queryExpenses(includeCancelled: true)
            .limit(_limit)
            .get();

    final activityFuture = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('inventory_logs')
        .orderBy('timestamp', descending: true)
        .limit(_limit)
        .get();

    final inventoryFuture = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('inventory_logs')
        .orderBy('date', descending: true)
        .limit(_limit)
        .get();

    final results = await Future.wait<dynamic>([
      ordersFuture,
      expensesFuture,
      activityFuture,
      inventoryFuture,
    ]);

    final items = <AuditLogItem>[];

    final orderSnapshot = results[0] as QuerySnapshot<AppOrder>;
    for (final doc in orderSnapshot.docs) {
      try {
        final order = doc.data();
        final isCancelled = order.status == 'cancelled';
        final refNum = order.queueNumber != null
            ? '#${order.queueNumber}'
            : (order.id.length >= 6
                ? '#${order.id.substring(0, 6).toUpperCase()}'
                : '#${order.id.toUpperCase()}');
        final payment = _getPaymentName(order.paymentMethod, isAr);
        final itemsSummary = order.items
            .map((item) => '${item.productName} (${item.quantity}x)')
            .join('، ');

        items.add(
          AuditLogItem(
            id: order.id,
            title: isAr
                ? '🛒 فاتورة مبيعات $refNum ${isCancelled ? "[ملغى]" : ""}'
                : '🛒 Sales Order $refNum ${isCancelled ? "[Cancelled]" : ""}',
            subtitle: isAr
                ? '🤝 العميل: ${order.customerName} | 💵 الدفع: $payment'
                : '🤝 Customer: ${order.customerName} | 💵 Payment: $payment',
            details: isAr
                ? '📦 الأصناف: $itemsSummary'
                : '📦 Items: $itemsSummary',
            timestamp: order.createdAt,
            performedBy:
                order.creatorName != null && order.creatorName!.isNotEmpty
                    ? order.creatorName!
                    : (isAr ? 'التاجر' : 'Merchant'),
            type: 'مبيعات',
            amount: isCancelled ? 0.0 : order.total,
            order: order,
            badgeColor: isCancelled ? Colors.redAccent : Colors.green,
          ),
        );
      } catch (_) {}
    }

    final expenseSnapshot = results[1];
    if (expenseSnapshot != null) {
      for (final doc in expenseSnapshot.docs) {
        try {
          final expense = doc.data();
          final category = expense.category != null && expense.category!.isNotEmpty
              ? '[${expense.category}] '
              : '';
          final notes = expense.notes ?? '';
          items.add(
            AuditLogItem(
              id: expense.id,
              title: isAr
                  ? '💸 مصروف: ${expense.title}'
                  : '💸 Expense: ${expense.title}',
              subtitle: isAr
                  ? '📝 البيان: $category$notes'
                  : '📝 Note: $category$notes',
              timestamp: expense.date,
              performedBy: expense.creatorName != null &&
                      expense.creatorName!.isNotEmpty
                  ? expense.creatorName!
                  : (isAr ? 'التاجر' : 'Merchant'),
              type: 'مصروفات',
              amount: -expense.amount,
              badgeColor: Colors.orangeAccent,
            ),
          );
        } catch (_) {}
      }
    }

    final activitySnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
    for (final doc in activitySnapshot.docs) {
      try {
        final data = doc.data();
        if (data['isActivityLog'] != true && !doc.id.startsWith('act_')) {
          continue;
        }
        final timestamp = safeParseDate(data['timestamp']);
        final action = data['actionType']?.toString() ??
            (isAr ? 'عملية' : 'Action');
        final description = data['description']?.toString() ?? '';
        final employeeName = data['employeeName']?.toString() ??
            (isAr ? 'التاجر' : 'Merchant');
        final amount = (data['amount'] as num? ?? 0.0).toDouble();

        items.add(
          AuditLogItem(
            id: doc.id,
            title: '⚙️ $action',
            subtitle: description,
            timestamp: timestamp,
            performedBy: employeeName,
            type: action,
            amount: amount,
            badgeColor: action.contains('حذف') || action.contains('إلغاء')
                ? Colors.redAccent
                : Colors.blueAccent,
          ),
        );
      } catch (_) {}
    }

    final inventorySnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
    for (final doc in inventorySnapshot.docs) {
      try {
        if (doc.id == 'store_profile_doc' ||
            doc.id.startsWith('counter_') ||
            doc.id.startsWith('act_')) {
          continue;
        }
        final data = doc.data();
        if (data['isActivityLog'] == true) continue;

        final timestamp = safeParseDate(data['date']);
        final productName = data['productName']?.toString() ??
            (isAr ? 'صنف/منتج' : 'Product');
        final change = (data['changeQuantity'] as num? ?? 0).toDouble();
        final previous = (data['previousQuantity'] as num? ?? 0).toDouble();
        final next = (data['newQuantity'] as num? ?? 0).toDouble();
        final reason = data['reason']?.toString() ??
            (isAr ? 'تعديل أو حركة في المخزون' : 'Inventory movement');
        final userName = data['userName']?.toString() ??
            data['employeeName']?.toString() ??
            '';
        final changeText = change > 0 ? '+${_qty(change)}' : _qty(change);

        items.add(
          AuditLogItem(
            id: doc.id,
            title: isAr
                ? '📦 مخزون: $productName ($changeText)'
                : '📦 Inventory: $productName ($changeText)',
            subtitle: isAr
                ? '🔄 من (${_qty(previous)}) إلى (${_qty(next)}) | 📝 السبب: $reason'
                : '🔄 From (${_qty(previous)}) to (${_qty(next)}) | 📝 Reason: $reason',
            timestamp: timestamp,
            performedBy: userName,
            type: 'مخزون',
            badgeColor: change > 0 ? Colors.teal : Colors.amber,
          ),
        );
      } catch (_) {}
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(_limit).toList();
  }

  String _qty(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Widget _buildLogItem(
    AuditLogItem item,
    ThemeData theme,
    AppCurrency currency,
    bool isAr,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item.badgeColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getIcon(item.type), color: item.badgeColor),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.subtitle,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
            ),
            if (item.details.isNotEmpty)
              Text(
                item.details,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            if (item.performedBy.isNotEmpty)
              Text(
                item.performedBy,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  color: Colors.teal,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (item.amount != 0)
              Text(
                '${item.amount.toStringAsFixed(2)} ${currency.code}',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: item.badgeColor,
                ),
              ),
            Text(
              _formatTime(item.timestamp, isAr),
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10),
            ),
          ],
        ),
        onTap: item.order == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OrderDetailsScreen(order: item.order!),
                  ),
                );
              },
      ),
    );
  }

  String _formatTime(DateTime date, bool isAr) {
    var hour = date.hour;
    final period = isAr
        ? (hour >= 12 ? 'م' : 'ص')
        : (hour >= 12 ? 'PM' : 'AM');
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _getPaymentName(String? method, bool isAr) {
    if (method == 'cash') return isAr ? 'نقداً (كاش)' : 'Cash';
    if (method == 'card' || method == 'mada' || method == 'apple_pay') {
      return isAr ? 'بطاقة شبكة' : 'Card';
    }
    if (method == 'debt') {
      return isAr ? 'آجل / ذمم على العميل' : 'Credit / Debt';
    }
    return method ?? (isAr ? 'نقدي' : 'Cash');
  }

  IconData _getIcon(String type) {
    final lower = type.toLowerCase();
    if (type.contains('مبيعات') || lower.contains('sale')) {
      return Icons.point_of_sale;
    }
    if (type.contains('مخزون') ||
        lower.contains('inventory') ||
        type.contains('منتج')) {
      return Icons.inventory_2_outlined;
    }
    if (type.contains('مصروف') || lower.contains('expense')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (type.contains('عميل') || lower.contains('customer')) {
      return Icons.person_add_alt_1_outlined;
    }
    if (type.contains('حذف') ||
        type.contains('إلغاء') ||
        lower.contains('delete') ||
        lower.contains('cancel')) {
      return Icons.delete_forever_outlined;
    }
    return Icons.manage_history_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final isMerchant =
        appUser?.role == 'admin' || appUser?.role != 'employee';
    final merchantId = appUser?.role == 'employee'
        ? appUser?.merchantId
        : appUser?.id;

    if (!isMerchant) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            isAr ? 'سجل الحركة الشامل (المراجعة)' : 'Centralized Audit Log',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                isAr
                    ? 'هذه الصفحة مخصصة للتاجر (صاحب المتجر) فقط'
                    : 'This page is restricted to the merchant/admin only.',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'سجل الحركة الشامل (المراجعة)' : 'Centralized Audit Log',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isAr ? 'تحديث' : 'Refresh',
            onPressed: () => setState(() => _refreshTick++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: merchantId == null || merchantId.isEmpty
          ? Center(
              child: Text(
                isAr ? 'لا يوجد تصريح' : 'No authorization',
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
            )
          : FutureBuilder<List<AuditLogItem>>(
              key: ValueKey('$merchantId-$_limit-$_refreshTick'),
              future: _loadItems(merchantId: merchantId, isAr: isAr),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isAr
                            ? 'تعذر تحميل سجل المراجعة. حاول التحديث مرة أخرى.'
                            : 'Could not load the audit log. Please refresh and try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? const <AuditLogItem>[];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_edu_outlined,
                          size: 80,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isAr
                              ? 'لا توجد حركات أو مبيعات مسجلة في المتجر حتى الآن'
                              : 'No store actions or sales recorded yet',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final grouped = <String, List<AuditLogItem>>{};
                for (final item in items) {
                  final day =
                      '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')}';
                  grouped.putIfAbsent(day, () => []).add(item);
                }
                final days = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: days.length + 1,
                  itemBuilder: (context, index) {
                    if (index == days.length) {
                      if (items.length < _limit) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              isAr
                                  ? 'تم الوصول إلى أقدم الحركات المتاحة'
                                  : 'You reached the oldest available activities',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _limit += 50),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            isAr
                                ? 'تحميل 50 حركة أقدم'
                                : 'Load 50 older activities',
                            style: const TextStyle(fontFamily: 'Tajawal'),
                          ),
                        ),
                      );
                    }

                    final day = days[index];
                    final dayItems = grouped[day]!;
                    final dailySales = dayItems
                        .where((item) =>
                            item.type == 'مبيعات' && item.amount > 0)
                        .fold<double>(0, (sum, item) => sum + item.amount);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          backgroundColor: theme.colorScheme.primary
                              .withValues(alpha: 0.08),
                          collapsedBackgroundColor: theme.colorScheme.primary
                              .withValues(alpha: 0.04),
                          leading:
                              const Icon(Icons.calendar_month_outlined),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${isAr ? "تاريخ:" : "Date:"} $day',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (dailySales > 0)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 8),
                                  child: Text(
                                    '${dailySales.toStringAsFixed(2)} ${currency.code}',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${isAr ? "إجمالي الحركات والأنشطة في هذا اليوم:" : "Total activities today:"} ${dayItems.length}',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          children: dayItems
                              .map((item) => _buildLogItem(
                                    item,
                                    theme,
                                    currency,
                                    isAr,
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
