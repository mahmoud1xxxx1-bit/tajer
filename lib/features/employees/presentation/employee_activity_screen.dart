import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../../core/providers/settings_provider.dart';

class EmployeeActivityItem {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final double amount;
  final bool isSale;
  final String actionType;

  EmployeeActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.amount,
    required this.isSale,
    required this.actionType,
  });
}

class EmployeeActivityScreen extends ConsumerStatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeActivityScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  ConsumerState<EmployeeActivityScreen> createState() => _EmployeeActivityScreenState();
}

class _EmployeeActivityScreenState extends ConsumerState<EmployeeActivityScreen> {
  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    String period = hour >= 12 ? 'م' : 'ص';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    String min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'نقداً';
      case 'card':
        return 'بطاقة';
      case 'debt':
        return 'آجل / ذمم';
      default:
        return method;
    }
  }

  IconData _getIconForAction(String type, bool isSale) {
    if (isSale) return Icons.point_of_sale;
    if (type.contains('عميل') || type.contains('عملاء')) return Icons.person_add_outlined;
    if (type.contains('مصروف') || type.contains('نفقات')) return Icons.money_off;
    if (type.contains('منتج') || type.contains('بضاعة')) return Icons.inventory_2_outlined;
    return Icons.work_history_outlined;
  }

  Color _getColorForAction(String type, bool isSale) {
    if (isSale) return Colors.greenAccent;
    if (type.contains('مصروف')) return Colors.redAccent;
    if (type.contains('عميل')) return Colors.blueAccent;
    return Colors.amberAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final merchantId = appUser?.role == 'employee' ? appUser?.merchantId : appUser?.id;
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('سجلات الموظف: ${widget.employeeName}', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: (merchantId == null || merchantId.isEmpty)
          ? const Center(child: Text('لا يوجد تصريح', style: TextStyle(fontFamily: 'Tajawal')))
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

                final allOrders = ordersAsync.value ?? [];
                final employeeOrders = allOrders.where((o) => 
                  o.creatorId == widget.employeeId || 
                  (o.creatorName == widget.employeeName && widget.employeeName.isNotEmpty)
                ).toList();

                final List<EmployeeActivityItem> items = [];

                // 1. Add Sales Orders
                for (final order in employeeOrders) {
                  items.add(
                    EmployeeActivityItem(
                      title: 'فاتورة مبيعات # ${order.queueNumber ?? (order.id.length > 6 ? order.id.substring(0, 6) : order.id)}',
                      subtitle: 'طريقة الدفع: ${_getPaymentMethodName(order.paymentMethod)} - إجمالي الأصناف: ${order.items.length}',
                      timestamp: order.createdAt,
                      amount: order.total,
                      isSale: true,
                      actionType: 'مبيعات',
                    ),
                  );
                }

                // 2. Add Activity Logs from Firestore
                if (snapshot.hasData && snapshot.data != null) {
                  for (final doc in snapshot.data!.docs) {
                    if (doc.id.startsWith('act_')) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final empId = data['employeeId']?.toString() ?? '';
                      final empName = data['employeeName']?.toString() ?? '';
                      
                      if (empId == widget.employeeId || (empName == widget.employeeName && widget.employeeName.isNotEmpty)) {
                        final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final amount = (data['amount'] as num? ?? 0.0).toDouble();
                        items.add(
                          EmployeeActivityItem(
                            title: data['actionType']?.toString() ?? 'عملية نظام',
                            subtitle: data['description']?.toString() ?? '',
                            timestamp: ts,
                            amount: amount,
                            isSale: false,
                            actionType: data['actionType']?.toString() ?? 'عملية',
                          ),
                        );
                      }
                    }
                  }
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد عمليات مسجلة للموظف (${widget.employeeName}) حتى الآن',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, color: Colors.grey[400]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Sort newest first
                items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                // Group by Day string (YYYY-MM-DD)
                final Map<String, List<EmployeeActivityItem>> groupedByDay = {};
                for (final item in items) {
                  final dayStr = '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')}';
                  groupedByDay.putIfAbsent(dayStr, () => []).add(item);
                }

                final days = groupedByDay.keys.toList();
                // Ensure newest day first
                days.sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final dayItems = groupedByDay[day]!;
                    final dailySales = dayItems.where((i) => i.isSale).fold<double>(0.0, (sum, i) => sum + i.amount);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0, // Automatically open the latest day
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          collapsedBackgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 22),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'تاريخ: $day',
                                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'المبيعات: ${dailySales.toStringAsFixed(2)} ${currency.code}',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'عدد العمليات المنفذة في هذا اليوم: ${dayItems.length}',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey[400]),
                            ),
                          ),
                          children: dayItems.map((item) {
                            final icon = _getIconForAction(item.actionType, item.isSale);
                            final color = _getColorForAction(item.actionType, item.isSale);

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Icon(icon, color: color, size: 20),
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
                                    if (item.amount > 0)
                                      Text(
                                        '${item.amount.toStringAsFixed(2)} ${currency.code}',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontWeight: FontWeight.bold,
                                          color: item.isSale ? Colors.green : Colors.amber,
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
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey[400]),
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTime(item.timestamp),
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey[500]),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '👤 منفذ العملية: ${widget.employeeName}',
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.blueAccent[200]),
                                        ),
                                      ],
                                    ),
                                  ],
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
