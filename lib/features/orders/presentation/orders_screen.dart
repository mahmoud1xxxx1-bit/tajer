import '../domain/order.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/order_repository.dart';
import 'add_order_dialog.dart';
import 'pos_screen.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/services/printer_service.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/date_formatter.dart';

import '../../../core/theme/glass_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ordersAsyncValue = ref.watch(ordersStreamProvider);
    final currency = ref.watch(currencyProvider).code;
    final appUser = ref.watch(appUserProvider).value;
    final canCreateOrders = appUser?.hasPermission('can_create_orders') ?? false;
    final canCancelOrders = appUser?.hasPermission('can_cancel_orders') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: ordersAsyncValue.when(
        data: (orders) {
            if (orders.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.text86,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                ),
              );
            }

            final Map<String, List<AppOrder>> groupedOrders = {};
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

            for (var order in orders) {
              final d = order.createdAt;
              final orderDate = DateTime(d.year, d.month, d.day);
              
              String groupKey;
              if (order.scheduledDate != null) {
                groupKey = '00_طلبات مجدولة 🗓';
              } else if (orderDate == today) {
                groupKey = '01_اليوم - ' + DateFormat('yyyy/MM/dd').format(orderDate);
              } else if (orderDate == yesterday) {
                groupKey = '02_أمس - ' + DateFormat('yyyy/MM/dd').format(orderDate);
              } else if (orderDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
                final endOfWeek = startOfWeek.add(const Duration(days: 6));
                groupKey = '03_هذا الأسبوع (من ' + DateFormat('MM/dd').format(startOfWeek) + ' إلى ' + DateFormat('MM/dd').format(endOfWeek) + ')';
              } else if (orderDate.isAfter(today.subtract(const Duration(days: 30)))) {
                final diffDays = startOfWeek.difference(orderDate).inDays;
                final weeksAgo = (diffDays / 7).floor() + 1;
                final wStart = startOfWeek.subtract(Duration(days: weeksAgo * 7));
                final wEnd = wStart.add(const Duration(days: 6));
                groupKey = '04_قبل ' + weeksAgo.toString() + ' أسبوع (من ' + DateFormat('MM/dd').format(wStart) + ' إلى ' + DateFormat('MM/dd').format(wEnd) + ')';
              } else if (orderDate.year == today.year) {
                groupKey = '05_شهر ' + DateFormat('MMMM').format(orderDate);
              } else {
                groupKey = '06_سنة ' + DateFormat('yyyy').format(orderDate);
              }
              
              groupedOrders.putIfAbsent(groupKey, () => []).add(order);
            }
            
            final sortedKeys = groupedOrders.keys.toList()..sort();

            return ListView.builder(
              itemCount: sortedKeys.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final groupOrders = groupedOrders[key]!;
                final totalRevenue = groupOrders.fold(0.0, (sum, o) => sum + o.total);
                final displayName = key.substring(3);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: index == 0,
                      title: Text(
                        displayName,
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        'إجمالي الدخل: ' + totalRevenue.toStringAsFixed(2) + ' ' + currency,
                        style: TextStyle(color: Colors.green.shade700, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                      ),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      children: groupOrders.map<Widget>((order) {
                      return GlassCard(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.all(0),
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(l10n.delete, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                              content: Text(AppLocalizations.of(context)!.text87, style: const TextStyle(fontFamily: 'Tajawal')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(orderRepositoryProvider).deleteOrder(order);
                                    Navigator.pop(context);
                                  },
                                  child: Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'طلب #${order.queueNumber ?? (order.id.length >= 5 ? order.id.substring(0, 5).toUpperCase() : order.id.toUpperCase())}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                                            ),
                                            Text(
                                              order.total.toString() + ' ' + currency,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.customer + ': ' + (order.customerName == 'walk_in' ? l10n.walkInCustomer : order.customerName),
                                          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              l10n.quantity + ': ' + order.items.fold<int>(0, (sum, item) => sum + item.quantity).toString(),
                                              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                                            ),
                                            Text(
                                              DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt),
                                              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        if (order.status == 'cancelled') ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.cancelled,
                                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                          ),
                                        ],
                                        if (order.isCredit) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              l10n.credit + ' (الدفع: ' + order.paidAmount.toString() + ' ' + currency + ')',
                                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        if (order.scheduledDate != null) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'موعد التسليم: ' + DateFormat('yyyy/MM/dd HH:mm').format(order.scheduledDate!),
                                              style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _getPaymentMethodName(order.paymentMethod),
                                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12),
                                              ),
                                            ),
                                            if (order.creatorName != null && order.creatorName!.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '👤 بواسطة: ${order.creatorName}',
                                                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.white.withOpacity(0.1)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          PdfService.printInvoice(context, order, currency);
                                        },
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.amber, size: 18),
                                        label: const Text('فاتورة PDF', style: TextStyle(color: Colors.amber, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () async {
                                          try {
                                            await PrinterService.printReceipt(order, currency, isKitchen: false).timeout(const Duration(seconds: 5));
                                          } catch (_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('تعذر الاتصال بالطابعة الحرارية. تأكد من إعداد الطابعة بشكل صحيح.', style: TextStyle(fontFamily: 'Tajawal'))),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.print_outlined, color: Colors.blueAccent, size: 18),
                                        label: const Text('طباعة حرارية', style: TextStyle(color: Colors.blueAccent, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (canCancelOrders && order.status != 'cancelled')
                                    TextButton.icon(
                                      onPressed: () {
                                        ref.read(orderRepositoryProvider).updateOrderStatus(order, 'cancelled');
                                      },
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                      label: Text(l10n.cancel, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
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
        loading: () => Center(child: CircularProgressIndicator()),

        error: (e, st) => Center(
          child: Text('${l10n.error}: $e', style: TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
      floatingActionButton: canCreateOrders ? FloatingActionButton.extended(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddOrder(context, ref);
          if (!canAdd) return;

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PosScreen()),
            );
          }
        },
        label: Text('نقطة البيع (POS)', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: Icon(Icons.point_of_sale),
      ) : null,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'processing': return Colors.blue;
      case 'shipped': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'pending':
      default:
        return Colors.amber.shade700;
    }
  }

  String _getStatusLabel(BuildContext context, String status) {
    switch (status) {
      case 'processing': return AppLocalizations.of(context)!.text95;
      case 'shipped': return AppLocalizations.of(context)!.text96;
      case 'delivered': return AppLocalizations.of(context)!.text97;
      case 'cancelled': return AppLocalizations.of(context)!.text98;
      case 'pending':
      default:
        return AppLocalizations.of(context)!.text99;
    }
  }

  String _getPaymentMethodName(String? method) {
    switch (method) {
      case 'cash': return 'دفع كاش 💵';
      case 'mada': return 'دفع مدى 💳';
      case 'transfer': return 'تحويل بنكي 🏦';
      case 'apple_pay': return 'Apple Pay 🍏';
      default: return 'دفع كاش 💵';
    }
  }
}
