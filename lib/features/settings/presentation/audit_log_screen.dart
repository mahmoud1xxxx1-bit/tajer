import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_details_screen.dart';
import '../../../core/providers/settings_provider.dart';

class AuditLogItem {
  final String id;
  final String title;
  final String subtitle;
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

  IconData _getIcon(String type) {
    if (type.contains('مبيعات') || type.toLowerCase().contains('sale') || type.toLowerCase().contains('order')) return Icons.point_of_sale;
    if (type.contains('مخزون') || type.toLowerCase().contains('inventory') || type.contains('منتج') || type.contains('بضاعة')) return Icons.inventory_2_outlined;
    if (type.contains('عميل') || type.toLowerCase().contains('customer')) return Icons.person_add_outlined;
    if (type.contains('مصروف') || type.toLowerCase().contains('expense')) return Icons.money_off;
    if (type.contains('حذف') || type.contains('إلغاء') || type.toLowerCase().contains('delete') || type.toLowerCase().contains('cancel')) return Icons.delete_forever;
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

    if (!isMerchant) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'سجل الحركة الشامل (المراجعة)' : 'Centralized Audit Log', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                isAr ? 'هذه الصفحة מخصصة للتاجر (صاحب المتجر) فقط' : 'This page is restricted to the merchant/admin only.',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold),
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
                if (snapshot.connectionState == ConnectionState.waiting || ordersAsync.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<AuditLogItem> items = [];

                // 1. Add All Orders (Active and Cancelled)
                final orders = ordersAsync.value ?? [];
                for (final o in orders) {
                  final statusStr = o.status == 'cancelled' ? (isAr ? ' [ملغى]' : ' [Cancelled]') : '';
                  items.add(
                    AuditLogItem(
                      id: o.id,
                      title: (isAr ? 'طلب مبيعات #' : 'Order #') + (o.queueNumber?.toString() ?? (o.id.length > 6 ? o.id.substring(0, 6) : o.id)) + statusStr,
                      subtitle: isAr ? 'العميل: ${o.customerName} | الدفع: ${o.paymentMethod}' : 'Customer: ${o.customerName} | Pay: ${o.paymentMethod}',
                      timestamp: o.createdAt,
                      performedBy: o.creatorName ?? (isAr ? 'التاجر' : 'Merchant'),
                      type: 'مبيعات',
                      amount: o.total,
                      order: o,
                      badgeColor: o.status == 'cancelled' ? Colors.red : Colors.green,
                    ),
                  );
                }

                // 2. Add Activity & Inventory Logs from Firestore
                if (snapshot.hasData && snapshot.data != null) {
                  for (final doc in snapshot.data!.docs) {
                    if (doc.id == 'store_profile_doc' || doc.id.startsWith('counter_')) continue;
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    
                    if (doc.id.startsWith('act_')) {
                      // Activity log
                      final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final action = data['actionType']?.toString() ?? (isAr ? 'عملية' : 'Action');
                      items.add(
                        AuditLogItem(
                          id: doc.id,
                          title: action,
                          subtitle: data['description']?.toString() ?? '',
                          timestamp: ts,
                          performedBy: data['employeeName']?.toString() ?? (isAr ? 'التاجر' : 'Merchant'),
                          type: action,
                          amount: (data['amount'] as num? ?? 0.0).toDouble(),
                          badgeColor: action.contains('حذف') || action.contains('إلغاء') ? Colors.redAccent : Colors.blueAccent,
                        ),
                      );
                    } else {
                      // Inventory change log
                      final ts = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final pName = data['productName']?.toString() ?? (isAr ? 'منتج' : 'Product');
                      final change = (data['changeQuantity'] ?? 0) as int;
                      final reason = data['reason']?.toString() ?? '';
                      final userEmail = data['userEmail']?.toString() ?? (isAr ? 'التاجر' : 'Merchant');
                      
                      items.add(
                        AuditLogItem(
                          id: doc.id,
                          title: isAr ? 'حركة مخزون: $pName (${change > 0 ? "+$change" : "$change"})' : 'Inventory: $pName (${change > 0 ? "+$change" : "$change"})',
                          subtitle: isAr ? 'السبب: $reason | من ${data['previousQuantity'] ?? 0} إلى ${data['newQuantity'] ?? 0}' : 'Reason: $reason | From ${data['previousQuantity'] ?? 0} to ${data['newQuantity'] ?? 0}',
                          timestamp: ts,
                          performedBy: userEmail,
                          type: 'مخزون',
                          badgeColor: change > 0 ? Colors.teal : Colors.amber,
                        ),
                      );
                    }
                  }
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu_outlined, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          isAr ? 'لا توجد حركات مسجلة في المتجر حتى الآن' : 'No activity recorded in the store yet',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, color: Colors.grey[400]),
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          collapsedBackgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 20),
                          ),
                          title: Text(
                            '${isAr ? "تاريخ:" : "Date:"} $day',
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            '${isAr ? "إجمالي الحركات:" : "Total Actions:"} ${dayItems.length}',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey[400]),
                          ),
                          children: dayItems.map((item) {
                            final icon = _getIcon(item.type);

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: item.badgeColor.withOpacity(0.15),
                                  child: Icon(icon, color: item.badgeColor, size: 20),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    if (item.amount > 0 && item.order != null)
                                      Text(
                                        '${item.amount.toStringAsFixed(2)} ${currency.code}',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontWeight: FontWeight.bold,
                                          color: item.badgeColor,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.subtitle.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                                        child: Text(
                                          item.subtitle,
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey[300]),
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTime(item.timestamp, isAr),
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey[500]),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '👤 ${item.performedBy}',
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.blueAccent[100], fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: item.order != null ? Icon(Icons.chevron_right, color: Colors.blue[300]) : null,
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
