import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../data/order_repository.dart';
import 'add_order_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/pdf_service.dart';

import '../../../core/providers/settings_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ordersAsyncValue = ref.watch(ordersStreamProvider);
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: ordersAsyncValue.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.text_86,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: orders.length,
            padding: EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final order = orders[index];
              return GlassCard(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(4),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.delete, style: TextStyle(fontFamily: 'Tajawal')),
                      content: Text(AppLocalizations.of(context)!.text_87, style: TextStyle(fontFamily: 'Tajawal')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel, style: TextStyle(fontFamily: 'Tajawal')),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(orderRepositoryProvider).deleteOrder(order);
                            Navigator.pop(context);
                          },
                          child: Text(l10n.delete, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                        ),
                      ],
                    ),
                  );
                },
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(
                    'طلب #${order.id.substring(0, 5).toUpperCase()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(order.customerName, style: TextStyle(fontFamily: 'Tajawal')),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text('${order.productName} (x${order.quantity})', style: TextStyle(fontFamily: 'Tajawal')),
                          ],
                        ),
                        if (order.isCredit) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.money_off, size: 14, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'بيع آجل (دُفع: ${order.paidAmount} / الباقي: ${order.total - order.paidAmount})',
                                style: TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${order.total} $currency',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getStatusColor(order.status).withOpacity(0.5)),
                            ),
                            child: Text(
                              _getStatusLabel(context, order.status),
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert),
                        onSelected: (value) async {
                          final repo = ref.read(orderRepositoryProvider);
                          if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(l10n.delete, style: TextStyle(fontFamily: 'Tajawal')),
                                content: Text(AppLocalizations.of(context)!.text_87, style: TextStyle(fontFamily: 'Tajawal')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(l10n.cancel, style: TextStyle(fontFamily: 'Tajawal')),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      repo.deleteOrder(order);
                                      Navigator.pop(context);
                                    },
                                    child: Text(l10n.delete, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                  ),
                                ],
                              ),
                            );
                          } else if (value.startsWith('status_')) {
                            final newStatus = value.replaceFirst('status_', '');
                            try {
                              await repo.updateOrderStatus(order, newStatus);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString(), style: TextStyle(fontFamily: 'Tajawal'))),
                                );
                              }
                            }
                          } else if (value == 'print') {
                            try {
                              await PdfService.printInvoice(context, order, currency);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ في الطباعة: $e', style: TextStyle(fontFamily: 'Tajawal'))),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'status_pending',
                            child: Text(AppLocalizations.of(context)!.text_88, style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                          const PopupMenuItem(
                            value: 'status_processing',
                            child: Text(AppLocalizations.of(context)!.text_89, style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                          const PopupMenuItem(
                            value: 'status_shipped',
                            child: Text(AppLocalizations.of(context)!.text_90, style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                          const PopupMenuItem(
                            value: 'status_delivered',
                            child: Text(AppLocalizations.of(context)!.text_91, style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                          const PopupMenuItem(
                            value: 'status_cancelled',
                            child: Text(AppLocalizations.of(context)!.text_92, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'print',
                            child: Row(
                              children: [
                                Icon(Icons.print_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.text_93, style: TextStyle(fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(l10n.delete, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
      floatingActionButton: FloatingActionButton.extended(
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
        label: Text(AppLocalizations.of(context)!.text_94, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: Icon(Icons.add_shopping_cart),
      ),
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
      case 'processing': return AppLocalizations.of(context)!.text_95;
      case 'shipped': return AppLocalizations.of(context)!.text_96;
      case 'delivered': return AppLocalizations.of(context)!.text_97;
      case 'cancelled': return AppLocalizations.of(context)!.text_98;
      case 'pending':
      default:
        return AppLocalizations.of(context)!.text_99;
    }
  }
}
