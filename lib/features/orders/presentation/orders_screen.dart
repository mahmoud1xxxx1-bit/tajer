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
          return ListView.builder(
            itemCount: orders.length,
            padding: EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final order = orders[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
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
                                      'طلب #${order.id.substring(0, 5).toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                                    ),
                                    Text(
                                      '${order.total} $currency',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(order.customerName, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text('${order.productName} (x${order.quantity})', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14))),
                                  ],
                                ),
                                if (order.isCredit) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.money_off, size: 16, color: Colors.red),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'بيع آجل (دُفع: ${order.paidAmount} | الباقي: ${order.total - order.paidAmount})',
                                            style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppDateFormatter.format(order.createdAt),
                                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                                if (order.creatorName != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_pin, size: 14, color: Colors.purple.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.creatorName!,
                                        style: TextStyle(fontFamily: 'Tajawal', color: Colors.purple.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
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
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                onSelected: (value) async {
                                  final repo = ref.read(orderRepositoryProvider);
                                  if (value == 'delete') {
                                    if (!canCancelOrders) return;
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(l10n.delete, style: const TextStyle(fontFamily: 'Tajawal')),
                                        content: Text(AppLocalizations.of(context)!.text87, style: const TextStyle(fontFamily: 'Tajawal')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'Tajawal')),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              repo.deleteOrder(order);
                                              Navigator.pop(context);
                                            },
                                            child: Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (value.startsWith('status_')) {
                                    if (!canCancelOrders) return;
                                    final newStatus = value.replaceFirst('status_', '');
                                    try {
                                      await repo.updateOrderStatus(order, newStatus);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
                                        );
                                      }
                                    }
                                  } else if (value == 'print') {
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        final taxController = TextEditingController();
                                        bool applyTax = false;
                                        return StatefulBuilder(
                                          builder: (context, setState) {
                                            return AlertDialog(
                                              title: const Text('خيارات الطباعة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SwitchListTile(
                                                    title: const Text('إضافة ضريبة للفاتورة', style: TextStyle(fontFamily: 'Tajawal')),
                                                    value: applyTax,
                                                    onChanged: (val) => setState(() => applyTax = val),
                                                  ),
                                                  if (applyTax)
                                                    TextField(
                                                      controller: taxController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: const InputDecoration(
                                                        labelText: 'نسبة الضريبة (%)',
                                                        border: OutlineInputBorder(),
                                                        suffixText: '%',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dialogContext),
                                                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    Navigator.pop(dialogContext);
                                                    double? tax;
                                                    if (applyTax && taxController.text.isNotEmpty) {
                                                      tax = double.tryParse(taxController.text);
                                                    }
                                                    try {
                                                      await PdfService.printInvoice(context, order, currency, taxPercentage: tax);
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('خطأ في الطباعة: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                                  child: const Text('طباعة PDF', style: TextStyle(fontFamily: 'Tajawal')),
                                                ),
                                              ],
                                            );
                                          }
                                        );
                                      }
                                    );
                                  } else if (value == 'whatsapp') {
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        final taxController = TextEditingController();
                                        bool applyTax = false;
                                        return StatefulBuilder(
                                          builder: (context, setState) {
                                            return AlertDialog(
                                              title: const Text('إرسال الفاتورة عبر واتساب', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SwitchListTile(
                                                    title: const Text('إضافة ضريبة للفاتورة', style: TextStyle(fontFamily: 'Tajawal')),
                                                    value: applyTax,
                                                    onChanged: (val) => setState(() => applyTax = val),
                                                  ),
                                                  if (applyTax)
                                                    TextField(
                                                      controller: taxController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: const InputDecoration(
                                                        labelText: 'نسبة الضريبة (%)',
                                                        border: OutlineInputBorder(),
                                                        suffixText: '%',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dialogContext),
                                                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    Navigator.pop(dialogContext);
                                                    double? tax;
                                                    if (applyTax && taxController.text.isNotEmpty) {
                                                      tax = double.tryParse(taxController.text);
                                                    }
                                                    try {
                                                      await WhatsAppService.sendInvoice(order, currency, taxPercentage: tax);
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                  child: const Text('إرسال الآن', style: TextStyle(fontFamily: 'Tajawal')),
                                                ),
                                              ],
                                            );
                                          }
                                        );
                                      }
                                    );
                                  } else if (value == 'thermal_print') {
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        final taxController = TextEditingController();
                                        bool applyTax = false;
                                        return StatefulBuilder(
                                          builder: (context, setState) {
                                            return AlertDialog(
                                              title: const Text('الطباعة الحرارية', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SwitchListTile(
                                                    title: const Text('إضافة ضريبة للفاتورة', style: TextStyle(fontFamily: 'Tajawal')),
                                                    value: applyTax,
                                                    onChanged: (val) => setState(() => applyTax = val),
                                                  ),
                                                  if (applyTax)
                                                    TextField(
                                                      controller: taxController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: const InputDecoration(
                                                        labelText: 'نسبة الضريبة (%)',
                                                        border: OutlineInputBorder(),
                                                        suffixText: '%',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dialogContext),
                                                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    Navigator.pop(dialogContext);
                                                    double? tax;
                                                    if (applyTax && taxController.text.isNotEmpty) {
                                                      tax = double.tryParse(taxController.text);
                                                    }
                                                    try {
                                                      await PrinterService.printReceipt(order, currency, taxPercentage: tax);
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('خطأ في الطباعة الحرارية: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                                                  child: const Text('طباعة', style: TextStyle(fontFamily: 'Tajawal')),
                                                ),
                                              ],
                                            );
                                          }
                                        );
                                      }
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (canCancelOrders) ...[
                                    const PopupMenuItem(
                                      value: 'status_pending',
                                      child: Text('قيد الانتظار', style: TextStyle(fontFamily: 'Tajawal')),
                                    ),
                                    const PopupMenuItem(
                                      value: 'status_processing',
                                      child: Text('جاري التجهيز', style: TextStyle(fontFamily: 'Tajawal')),
                                    ),
                                    const PopupMenuItem(
                                      value: 'status_delivered',
                                      child: Text('مكتمل', style: TextStyle(fontFamily: 'Tajawal')),
                                    ),
                                    const PopupMenuItem(
                                      value: 'status_cancelled',
                                      child: Text('ملغى', style: TextStyle(fontFamily: 'Tajawal')),
                                    ),
                                    const PopupMenuItem(
                                      value: 'status_return',
                                      child: Text('مرتجع', style: TextStyle(fontFamily: 'Tajawal')),
                                    ),
                                    const PopupMenuDivider(),
                                  ],
                                  const PopupMenuItem(
                                    value: 'print',
                                    child: Row(
                                      children: [
                                        Icon(Icons.picture_as_pdf, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('طباعة PDF', style: TextStyle(fontFamily: 'Tajawal')),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'thermal_print',
                                    child: Row(
                                      children: [
                                        Icon(Icons.print, color: Colors.indigo),
                                        SizedBox(width: 8),
                                        Text('طباعة حرارية', style: TextStyle(fontFamily: 'Tajawal')),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'whatsapp',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('إرسال واتساب', style: TextStyle(fontFamily: 'Tajawal')),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  if (canCancelOrders)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, color: Colors.red, size: 20),
                                          const SizedBox(width: 8),
                                          Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
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
