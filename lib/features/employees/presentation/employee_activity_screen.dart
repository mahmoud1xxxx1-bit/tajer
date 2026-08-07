import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/date_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_details_screen.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../../../../../../core/theme/glass_card.dart';

class EmployeeActivityItem {
  final String title;
  final String subtitle;
  final String details;
  final DateTime timestamp;
  final double amount;
  final bool isSale;
  final String actionType;
  final AppOrder? order;
  final Color badgeColor;

  EmployeeActivityItem({
    required this.title,
    required this.subtitle,
    this.details = '',
    required this.timestamp,
    required this.amount,
    required this.isSale,
    required this.actionType,
    this.order,
    required this.badgeColor,
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
  String _formatTime(DateTime dt, bool isAr) {
    int hour = dt.hour;
    String period = isAr ? (hour >= 12 ? 'م' : 'ص') : (hour >= 12 ? 'PM' : 'AM');
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    String min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String _getPaymentMethodName(String? method, bool isAr) {
    switch (method) {
      case 'cash':
        return isAr ? 'نقداً (كاش)' : 'Cash';
      case 'card':
        return isAr ? 'بطاقة شبكة' : 'Card';
      case 'debt':
        return isAr ? 'آجل / ذمم على العميل' : 'Credit / Debt';
      default:
        return method ?? (isAr ? 'نقدي' : 'Cash');
    }
  }

  IconData _getIconForAction(String type, bool isSale) {
    if (isSale) return Icons.point_of_sale;
    if (type.contains('عميل') || type.toLowerCase().contains('customer')) return Icons.person_add_alt_1_outlined;
    if (type.contains('مصروف') || type.toLowerCase().contains('expense')) return Icons.account_balance_wallet_outlined;
    if (type.contains('منتج') || type.toLowerCase().contains('product') || type.contains('بضاعة') || type.contains('مخزون')) return Icons.inventory_2_outlined;
    return Icons.work_history_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final merchantId = appUser?.role == 'employee' ? appUser?.merchantId : appUser?.id;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'سجلات الموظف: ${widget.employeeName}' : 'Employee Activity: ${widget.employeeName}', 
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

                final allOrders = ordersAsync.value ?? [];
                final employeeOrders = allOrders.where((o) => 
                  o.creatorId == widget.employeeId || 
                  (o.creatorName != null && o.creatorName == widget.employeeName && widget.employeeName.isNotEmpty)
                ).toList();

                final List<EmployeeActivityItem> items = [];

                // 1. Add Sales Orders
                for (final order in employeeOrders) {
                  try {
                    final isCancelled = order.status == 'cancelled';
                    final refNum = order.queueNumber != null ? '#${order.queueNumber}' : (order.id.length >= 6 ? '#${order.id.substring(0, 6).toUpperCase()}' : '#${order.id.toUpperCase()}');
                    final itemsSummary = order.items.map((i) => '${i.productName} (${i.quantity}x)').join('، ');
                    
                    items.add(
                      EmployeeActivityItem(
                        title: isAr 
                            ? '🛒 فاتورة مبيعات $refNum ${isCancelled ? "[ملغى]" : ""}' 
                            : '🛒 Sales Order $refNum ${isCancelled ? "[Cancelled]" : ""}',
                        subtitle: isAr 
                            ? '🤝 العميل: ${order.customerName} | 💵 الدفع: ${_getPaymentMethodName(order.paymentMethod, isAr)}' 
                            : '🤝 Customer: ${order.customerName} | 💵 Payment: ${_getPaymentMethodName(order.paymentMethod, isAr)}',
                        details: isAr ? '📦 الأصناف: $itemsSummary' : '📦 Items: $itemsSummary',
                        timestamp: order.createdAt,
                        amount: isCancelled ? 0.0 : order.total,
                        isSale: true,
                        actionType: 'مبيعات',
                        order: order,
                        badgeColor: isCancelled ? Colors.redAccent : Colors.green,
                      ),
                    );
                  } catch (e) {
                    // Prevent crash on malformed record
                  }
                }

                // 2. Add Expenses by Employee
                final allExpenses = expensesAsync.value ?? [];
                final employeeExpenses = allExpenses.where((e) => 
                  e.creatorId == widget.employeeId || 
                  (e.creatorName != null && e.creatorName == widget.employeeName && widget.employeeName.isNotEmpty)
                ).toList();

                for (final exp in employeeExpenses) {
                  try {
                    items.add(
                      EmployeeActivityItem(
                        title: isAr ? '💸 مصروف: ${exp.title}' : '💸 Expense: ${exp.title}',
                        subtitle: isAr ? '📝 البيان: ${exp.category ?? ""} ${exp.notes ?? ""}' : '📝 Note: ${exp.category ?? ""} ${exp.notes ?? ""}',
                        timestamp: exp.date,
                        amount: -exp.amount,
                        isSale: false,
                        actionType: 'مصروفات',
                        badgeColor: Colors.orangeAccent,
                      ),
                    );
                  } catch (e) {
                    // Safe skip
                  }
                }

                // 3. Add Activity Logs from Firestore
                if (snapshot.hasData && snapshot.data != null) {
                  for (final doc in snapshot.data!.docs) {
                    try {
                      if (doc.id == 'store_profile_doc' || doc.id.startsWith('counter_')) continue;
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      
                      if (doc.id.startsWith('act_')) {
                        final empId = data['employeeId']?.toString() ?? '';
                        final empName = data['employeeName']?.toString() ?? '';
                        
                        if (empId == widget.employeeId || (empName == widget.employeeName && widget.employeeName.isNotEmpty)) {
                          final ts = safeParseDate(data['timestamp']);
                          final amount = (data['amount'] as num? ?? 0.0).toDouble();
                          
                          final actionRaw = data['actionType']?.toString() ?? (isAr ? 'عملية نظام' : 'System Action');
                          final action = actionRaw.contains('|') ? (isAr ? actionRaw.split('|')[1] : actionRaw.split('|')[0]) : actionRaw;
                          
                          final descRaw = data['description']?.toString() ?? '';
                          final subtitle = descRaw.contains('|') ? (isAr ? descRaw.split('|')[1] : descRaw.split('|')[0]) : descRaw;

                          items.add(
                            EmployeeActivityItem(
                              title: '⚙️ $action',
                              subtitle: subtitle,
                              timestamp: ts,
                              amount: amount,
                              isSale: false,
                              actionType: action,
                              badgeColor: action.contains('حذف') || action.contains('Delete') || action.contains('إلغاء') || action.contains('Cancel') ? Colors.redAccent : Colors.blueAccent,
                            ),
                          );
                        }
                      } else {
                        // Inventory logs by this employee
                        final empEmail = data['userEmail']?.toString() ?? '';
                        if (empEmail == widget.employeeName || empEmail.contains(widget.employeeName)) {
                          final ts = safeParseDate(data['date']);
                          final pName = data['productName']?.toString() ?? (isAr ? 'صنف/منتج' : 'Product');
                          final change = (data['changeQuantity'] as num? ?? 0).toInt();
                          final prev = (data['previousQuantity'] as num? ?? 0).toInt();
                          final next = (data['newQuantity'] as num? ?? 0).toInt();
                          final reason = data['reason']?.toString() ?? '';
                          
                          final changeStr = change > 0 ? '+$change' : '$change';
                          items.add(
                            EmployeeActivityItem(
                              title: isAr ? '📦 مخزون: $pName ($changeStr)' : '📦 Inventory: $pName ($changeStr)',
                              subtitle: isAr ? '🔄 من ($prev) إلى ($next) | 📝 السبب: $reason' : '🔄 From ($prev) to ($next) | 📝 Reason: $reason',
                              timestamp: ts,
                              amount: 0.0,
                              isSale: false,
                              actionType: 'مخزون',
                              badgeColor: change > 0 ? Colors.teal : Colors.amber,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      // Prevent type cast errors
                    }
                  }
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[500]),
                        const SizedBox(height: 16),
                        Text(
                          isAr 
                              ? 'لا توجد عمليات أو مبيعات مسجلة للموظف (${widget.employeeName}) حتى الآن' 
                              : 'No activity logs found for (${widget.employeeName}) yet',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, color: Colors.grey[400], fontWeight: FontWeight.bold),
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
                days.sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final dayItems = groupedByDay[day]!;
                    final dailySales = dayItems.where((i) => i.isSale && i.amount > 0).fold<double>(0.0, (sum, i) => sum + i.amount);

                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                          collapsedBackgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.18),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              ),
                            child: Icon(Icons.calendar_month_outlined, size: 24),
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
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${isAr ? "عدد العمليات والحركات المنفذة في هذا اليوم:" : "Actions performed today:"} ${dayItems.length}',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                            ),
                          ),
                          children: dayItems.map((item) => _buildLogItem(item, theme, currency, isAr)).toList(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildLogItem(EmployeeActivityItem item, ThemeData theme, dynamic currency, bool isAr) {
    return InkWell(
      onTap: item.isSale && item.order != null ? () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: item.order!)));
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.badgeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIconForAction(item.actionType, item.isSale), color: item.badgeColor, size: 24),
            ),
            const SizedBox(width: 16),
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
                        ),
                      ),
                      if (item.amount != 0)
                        Text(
                          '${item.amount > 0 ? "+" : ""}${item.amount.toStringAsFixed(2)} ${currency.code}',
                          style: TextStyle(
                            fontFamily: 'Tajawal', 
                            fontWeight: FontWeight.bold,
                            color: item.amount > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (item.details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.details,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(item.timestamp, isAr),
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
