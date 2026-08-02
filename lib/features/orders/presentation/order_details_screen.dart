import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/order.dart';
import '../data/order_repository.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../../core/widgets/tax_dialog.dart';
import '../../../core/services/activity_logger.dart';
import '../../authentication/data/auth_repository.dart';
import 'pdf_viewer_screen.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final AppOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  late AppOrder currentOrder;

  @override
  void initState() {
    super.initState();
    currentOrder = widget.order;
  }

  String _getPaymentMethod(String method, bool isAr) {
    switch (method) {
      case 'cash':
        return isAr ? 'نقداً (Cash)' : 'Cash';
      case 'card':
        return isAr ? 'بطاقة / شبكة (Card)' : 'Card';
      case 'debt':
        return isAr ? 'آجل / ذمم (Credit)' : 'Credit';
      default:
        return method;
    }
  }

  Future<void> _cancelOrder(bool isAr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تأكيد الإلغاء' : 'Confirm Cancellation', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text(
          isAr ? 'هل أنت متأكد من رغبتك في إلغاء هذه الفاتورة؟ سيتم إرجاع كميات الأصناف للمخزون تلقائياً.' : 'Are you sure you want to cancel this order? Stock quantities will be restored automatically.',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'تراجع' : 'No', style: const TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'إلغاء الطلب' : 'Cancel Order', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(orderRepositoryProvider).updateOrderStatus(currentOrder, 'cancelled');
      final user = ref.read(appUserProvider).value;
      await ActivityLogger.log(
        user: user,
        actionType: isAr ? 'إلغاء فاتورة' : 'Order Cancelled',
        description: isAr 
            ? 'تم إلغاء الفاتورة رقم #${currentOrder.queueNumber ?? currentOrder.id.substring(0, 6)} بقيمة ${currentOrder.total}' 
            : 'Cancelled order #${currentOrder.queueNumber ?? currentOrder.id.substring(0, 6)} with total ${currentOrder.total}',
        amount: currentOrder.total,
      );
      setState(() {
        currentOrder = AppOrder(
          id: currentOrder.id,
          merchantId: currentOrder.merchantId,
          customerId: currentOrder.customerId,
          customerName: currentOrder.customerName,
          items: currentOrder.items,
          total: currentOrder.total,
          paidAmount: currentOrder.paidAmount,
          isCredit: currentOrder.isCredit,
          paymentMethod: currentOrder.paymentMethod,
          createdAt: currentOrder.createdAt,
          status: 'cancelled',
          queueNumber: currentOrder.queueNumber,
          creatorId: currentOrder.creatorId,
          creatorName: currentOrder.creatorName,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم إلغاء الفاتورة بنجاح وإرجاع المواد للمخزون' : 'Order cancelled and inventory restored successfully.', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  Future<void> _deleteOrder(bool isAr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تأكيد الحذف النهائي' : 'Confirm Deletion', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          isAr ? 'هل أنت متأكد من رغبتك في مسح الفاتورة نهائياً؟ لا يمكن التراجع عن هذه الخطوة.' : 'Are you sure you want to permanently delete this order? This action cannot be undone.',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'تراجع' : 'No', style: const TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف نهائي' : 'Delete Permanently', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(orderRepositoryProvider).deleteOrder(currentOrder);
      final user = ref.read(appUserProvider).value;
      await ActivityLogger.log(
        user: user,
        actionType: isAr ? 'حذف فاتورة' : 'Order Deleted',
        description: isAr 
            ? 'تم حذف الفاتورة رقم #${currentOrder.queueNumber ?? currentOrder.id.substring(0, 6)} نهائياً من قبل ${user?.name ?? "التاجر"}' 
            : 'Permanently deleted order #${currentOrder.queueNumber ?? currentOrder.id.substring(0, 6)} by ${user?.name ?? "Owner"}',
        amount: currentOrder.total,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم حذف الفاتورة نهائياً' : 'Order deleted permanently.', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isCancelled = currentOrder.status == 'cancelled';
    final dateStr = DateFormat('yyyy-MM-dd | hh:mm a').format(currentOrder.createdAt);
    final storeProfile = ref.watch(storeProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr 
            ? 'تفاصيل الطلب #${currentOrder.queueNumber ?? (currentOrder.id.length > 6 ? currentOrder.id.substring(0, 6) : currentOrder.id)}' 
            : 'Order Details #${currentOrder.queueNumber ?? (currentOrder.id.length > 6 ? currentOrder.id.substring(0, 6) : currentOrder.id)}',
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status and Info Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              color: isCancelled ? Colors.red.withOpacity(0.1) : theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCancelled ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCancelled ? (isAr ? '❌ طلب ملغي' : '❌ Cancelled') : (isAr ? '✅ طلب مؤكد / مكتمل' : '✅ Completed'),
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Text(
                          '#${currentOrder.queueNumber ?? currentOrder.id.substring(0, 6)}',
                          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.withOpacity(0.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(dateStr, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '${isAr ? "طريقة الدفع:" : "Payment:"} ${_getPaymentMethod(currentOrder.paymentMethod ?? "cash", isAr)}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '${isAr ? "العميل:" : "Customer:"} ${currentOrder.customerName}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (currentOrder.creatorName != null && currentOrder.creatorName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 18, color: theme.colorScheme.secondary),
                          const SizedBox(width: 8),
                          Text(
                            '${isAr ? "👤 منفذ الفاتورة:" : "👤 Created by:"} ${currentOrder.creatorName}',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              isAr ? '🛍️ قائمة الأصناف والمنتجات' : '🛍️ Order Items',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Items List Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentOrder.items.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                itemBuilder: (context, index) {
                  final item = currentOrder.items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text('${item.quantity}x', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13)),
                    ),
                    title: Text(item.productName, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${isAr ? "سعر الوحدة:" : "Unit Price:"} ${item.price.toStringAsFixed(2)} ${currency.code}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey[500]),
                    ),
                    trailing: Text(
                      '${item.total.toStringAsFixed(2)} ${currency.code}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            // Totals Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isAr ? 'المجموع النهائي للفاتورة' : 'Total Amount', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          '${currentOrder.total.toStringAsFixed(2)} ${currency.code}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green),
                        ),
                      ],
                    ),
                    if (currentOrder.isCredit) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isAr ? 'المبلغ المدفوع' : 'Paid Amount', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                          Text('${currentOrder.paidAmount.toStringAsFixed(2)} ${currency.code}', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isAr ? 'المبلغ الآجل (على الحساب)' : 'Remaining Credit', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Actions Section
            Text(
              isAr ? '⚙️ خيارات الفاتورة' : '⚙️ Invoice Actions',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: Text(isAr ? 'فاتورة PDF' : 'PDF Invoice', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () async {
                      double? tax = storeProfile?.defaultTaxPercentage;
                      if (tax == null || tax <= 0) {
                        tax = await TaxDialog.show(context);
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(order: currentOrder, currency: currency.code, taxPercentage: tax),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (!isCancelled) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                      label: Text(isAr ? 'إلغاء الطلب' : 'Cancel Order', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.orange)),
                      onPressed: () => _cancelOrder(isAr),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(isAr ? 'حذف نهائي' : 'Delete', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
                    onPressed: () => _deleteOrder(isAr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
