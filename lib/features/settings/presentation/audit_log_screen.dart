import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_details_screen.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../../core/providers/settings_provider.dart';

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
  String _formatTime(DateTime dt, bool isAr) {
    int hour = dt.hour;
    String period = isAr ? (hour >= 12 ? 'م' : 'ص') : (hour >= 12 ? 'PM' : 'AM');
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    String min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String _getPaymentName(String? method, bool isAr) {
    if (method == 'cash') return isAr ? 'نقداً (كاش)' : 'Cash';
    if (method == 'card') return isAr ? 'بطاقة شبكة' : 'Card';
    if (method == 'debt') return isAr ? 'آجل / ذمم على العميل' : 'Credit / Debt';
    return method ?? (isAr ? 'نقدي' : 'Cash');
  }

  IconData _getIcon(String type) {
    if (type.contains('مبيعات') || type.toLowerCase().contains('sale')) return Icons.point_of_sale;
    if (type.contains('مخزون') || type.toLowerCase().contains('inventory') || type.contains('منتج')) return Icons.inventory_2_outlined;
    if (type.contains('مصروف') || type.toLowerCase().contains('expense')) return Icons.account_balance_wallet_outlined;
    if (type.contains('عميل') || type.toLowerCase().contains('customer')) return Icons.person_add_alt_1_outlined;
    if (type.contains('حذف') || type.contains('إلغاء') || type.toLowerCase().contains('delete') || type.toLowerCase().contains('cancel')) return Icons.delete_forever_outlined;
    return Icons.manage_history_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final isMerchant = appUser?.role == 'admin' || appUser?.role != 'employee';
    final merchantId = appUser?.role == 'employee' ? appUser?.merchantId : appUser?.id;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    if (!isMerchant) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'سجل الحركة الشامل (المراجعة)' : 'Centralized Audit Log', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                isAr ? 'هذه الصفحة مخصصة للتاجر (صاحب المتجر) فقط' : 'This page is restricted to the merchant/admin only.',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold),
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
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: (merchantId == null || merchantId.isEmpty)
          ? Center(child: Text(isAr ? 'لا يوجد تصريح' : 'No authorization', style: const TextStyle(fontFamily: 'Tajawal')))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('merchants')
                  .doc(merchantId)
                  .collection('inventory_logs')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && ordersAsync.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<AuditLogItem> items = [];

                // 1. Add All Orders (Active and Cancelled)
                final orders = ordersAsync.value ?? [];
                for (final o in orders) {
                  try {
                    final isCancelled = o.status == 'cancelled';
                    final refNum = o.queueNumber != null ? '#${o.queueNumber}' : (o.id.length >= 6 ? '#${o.id.substring(0, 6).toUpperCase()}' : '#${o.id.toUpperCase()}');
                    final payDesc = _getPaymentName(o.paymentMethod, isAr);
                    final itemsSummary = o.items.map((i) => '${i.productName} (${i.quantity}x)').join('، ');
                    
                    items.add(
                      AuditLogItem(
                        id: o.id,
                        title: isAr ? '🛒 فاتورة مبيعات $refNum ${isCancelled ? "[ملغى]" : ""}' : '🛒 Sales Order $refNum ${isCancelled ? "[Cancelled]" : ""}',
                        subtitle: isAr ? '🤝 العميل: ${o.customerName} | 💵 الدفع: $payDesc' : '🤝 Customer: ${o.customerName} | 💵 Payment: $payDesc',
                        details: isAr ? '📦 الأصناف: $itemsSummary' : '📦 Items: $itemsSummary',
                        timestamp: o.createdAt,
                        performedBy: o.creatorName != null && o.creatorName!.isNotEmpty ? o.creatorName! : (isAr ? 'التاجر' : 'Merchant'),
                        type: 'مبيعات',
                        amount: isCancelled ? 0.0 : o.total,
                        order: o,
                        badgeColor: isCancelled ? Colors.redAccent : Colors.green,
                      ),
                    );
                  } catch (e) {
                    // Safe skip on corrupted order item
                  }
                }

                // 2. Add All Expenses
                final expenses = expensesAsync.value ?? [];
                for (final exp in expenses) {
                  try {
                    final catStr = exp.category != null && exp.category!.isNotEmpty ? '[${exp.category}] ' : '';
                    final noteStr = exp.notes ?? '';
                    items.add(
                      AuditLogItem(
                        id: exp.id,
                        title: isAr ? '💸 مصروف: ${exp.title}' : '💸 Expense: ${exp.title}',
                        subtitle: isAr ? '📝 البيان: $catStr$noteStr' : '📝 Note: $catStr$noteStr',
                        timestamp: exp.date,
                        performedBy: exp.creatorName != null && exp.creatorName!.isNotEmpty ? exp.creatorName! : (isAr ? 'التاجر' : 'Merchant'),
                        type: 'مصروفات',
                        amount: -exp.amount,
                        badgeColor: Colors.orangeAccent,
                      ),
                    );
                  } catch (e) {
                    // Safe skip
                  }
                }

                // 3. Add Activity & Inventory Logs from Firestore
                if (snapshot.hasData && snapshot.data != null) {
                  for (final doc in snapshot.data!.docs) {
                    try {
                      if (doc.id == 'store_profile_doc' || doc.id.startsWith('counter_')) continue;
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      
                      if (doc.id.startsWith('act_')) {
                        final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final action = data['actionType']?.toString() ?? (isAr ? 'عملية' : 'Action');
                        final desc = data['description']?.toString() ?? '';
                        final empName = data['employeeName']?.toString() ?? (isAr ? 'التاجر' : 'Merchant');
                        final amt = (data['amount'] as num? ?? 0.0).toDouble();
                        
                        items.add(
                          AuditLogItem(
                            id: doc.id,
                            title: '⚙️ $action',
                            subtitle: desc,
                            timestamp: ts,
                            performedBy: empName,
                            type: action,
                            amount: amt,
                            badgeColor: action.contains('حذف') || action.contains('إلغاء') ? Colors.redAccent : Colors.blueAccent,
                          ),
                        );
                      } else {
                        // Inventory change log
                        final ts = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final pName = data['productName']?.toString() ?? (isAr ? 'صنف/منتج' : 'Product');
                        final change = (data['changeQuantity'] as num? ?? 0).toInt();
                        final prev = (data['previousQuantity'] as num? ?? 0).toInt();
                        final next = (data['newQuantity'] as num? ?? 0).toInt();
                        final reason = data['reason']?.toString() ?? (isAr ? 'تعديل أو حركة في المخزون' : 'Inventory movement');
                        final userEmail = data['userEmail']?.toString() ?? (isAr ? 'التاجر' : 'Merchant');
                        
                        final changeStr = change > 0 ? '+$change' : '$change';
                        items.add(
                          AuditLogItem(
                            id: doc.id,
                            title: isAr ? '📦 مخزون: $pName ($changeStr)' : '📦 Inventory: $pName ($changeStr)',
                            subtitle: isAr ? '🔄 من ($prev) إلى ($next) | 📝 السبب: $reason' : '🔄 From ($prev) to ($next) | 📝 Reason: $reason',
                            timestamp: ts,
                            performedBy: userEmail,
                            type: 'مخزون',
                            badgeColor: change > 0 ? Colors.teal : Colors.amber,
                          ),
                        );
                      }
                    } catch (e) {
                      // Prevent type casting crash
                    }
                  }
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu_outlined, size: 80, color: Colors.grey[500]),
                        const SizedBox(height: 20),
                        Text(
                          isAr ? 'لا توجد حركات أو مبيعات مسجلة في المتجر حتى الآن' : 'No store actions or sales recorded yet',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, color: Colors.grey[400], fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAr ? 'أي فاتورة، مصروف، أو تعديل مخزون سيظهر هنا بالتفصيل التام' : 'Any order, expense, or inventory change will appear here in detail',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Sort descending by timestamp
                items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                // Group by day YYYY-MM-DD
                final Map<String, List<AuditLogItem>> groupedByDay = {};
                for (final item in items) {
                  final dayStr = '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')}';
                  groupedByDay.putIfAbsent(dayStr, () => []).add(item);
                }

                final days = groupedByDay.keys.toList();
                days.sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final dayItems = groupedByDay[day]!;
                    final dailySales = dayItems.where((i) => i.type == 'مبيعات' && i.amount > 0).fold<double>(0.0, (sum, i) => sum + i.amount);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      color: theme.cardColor,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                          collapsedBackgroundColor: theme.colorScheme.primary.withOpacity(0.04),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.calendar_month_outlined, color: theme.colorScheme.primary, size: 24),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${isAr ? "تاريخ:" : "Date:"} $day',
                                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (dailySales > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    '${isAr ? "المبيعات:" : "Sales:"} ${dailySales.toStringAsFixed(2)} ${currency.code}',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${isAr ? "إجمالي الحركات والأنشطة في هذا اليوم:" : "Total activities today:"} ${dayItems.length}',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey[400]),
                            ),
                          ),
                          children: dayItems.map((item) {
                            final icon = _getIcon(item.type);

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
                              ),
                              child: InkWell(
                                onTap: item.order != null
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OrderDetailsScreen(order: item.order!),
                                          ),
                                        );
                                      }
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: item.badgeColor.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(icon, color: item.badgeColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (item.amount != 0.0)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 8, right: 8),
                                                    child: Text(
                                                      '${item.amount.toStringAsFixed(2)} ${currency.code}',
                                                      style: TextStyle(
                                                        fontFamily: 'Tajawal',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: item.amount > 0 ? Colors.green : Colors.orangeAccent,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            if (item.subtitle.isNotEmpty)
                                              Text(
                                                item.subtitle,
                                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey[300], height: 1.4),
                                              ),
                                            if (item.details.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item.details,
                                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.blue[300], fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatTime(item.timestamp, isAr),
                                                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey[400]),
                                                ),
                                                const SizedBox(width: 16),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '👤 ${item.performedBy}',
                                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.lightBlue, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                if (item.order != null) ...[
                                                  const Spacer(),
                                                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                                                ]
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
