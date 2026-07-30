import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/order_repository.dart';
import 'add_order_dialog.dart';
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

            final Map<String, List<dynamic>> groupedOrders = {};
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

            for (var order in orders) {
              final d = order.createdAt;
              final orderDate = DateTime(d.year, d.month, d.day);
              
              String groupKey;
              if (orderDate == today) {
                groupKey = '0_اليوم - ' + DateFormat('yyyy/MM/dd').format(orderDate);
              } else if (orderDate == yesterday) {
                groupKey = '1_أمس - ' + DateFormat('yyyy/MM/dd').format(orderDate);
              } else if (orderDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
                final endOfWeek = startOfWeek.add(const Duration(days: 6));
                groupKey = '2_هذا الأسبوع (من ' + DateFormat('MM/dd').format(startOfWeek) + ' إلى ' + DateFormat('MM/dd').format(endOfWeek) + ')';
              } else if (orderDate.isAfter(today.subtract(const Duration(days: 30)))) {
                final diffDays = startOfWeek.difference(orderDate).inDays;
                final weeksAgo = (diffDays / 7).floor() + 1;
                final wStart = startOfWeek.subtract(Duration(days: weeksAgo * 7));
                final wEnd = wStart.add(const Duration(days: 6));
                groupKey = '3_قبل ' + weeksAgo.toString() + ' أسبوع (من ' + DateFormat('MM/dd').format(wStart) + ' إلى ' + DateFormat('MM/dd').format(wEnd) + ')';
              } else if (orderDate.year == today.year) {
                groupKey = '4_شهر ' + DateFormat('MMMM').format(orderDate);
              } else {
                groupKey = '5_سنة ' + DateFormat('yyyy').format(orderDate);
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
                final displayName = key.substring(2);
                
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
                      children: groupOrders.map((order) {
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
                                              'طلب #' + order.id.substring(0, 5).toUpperCase(),
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
                                              l10n.quantity + ': ' + order.quantity.toString(),
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
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (canCancelOrders && order.status != 'cancelled') ...[
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      ref.read(orderRepositoryProvider).cancelOrder(order);
                                    },
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                    label: Text(l10n.cancel, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
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
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: const AddOrderDialog(),
              ),
            );
          }
        },
        label: Text(AppLocalizations.of(context)!.text94, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: Icon(Icons.add_shopping_cart),
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
}
