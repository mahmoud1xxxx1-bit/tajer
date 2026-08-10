import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../domain/order.dart';
import '../data/order_repository.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../../core/widgets/tax_dialog.dart';
import '../../../core/services/activity_logger.dart';
import '../../authentication/data/auth_repository.dart';
import 'pdf_viewer_screen.dart';
import 'partial_return_screen.dart';
import '../../../../../../../../core/theme/glass_card.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final AppOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {

  String _getPaymentMethodName(BuildContext context, String? method) {
    final l10n = AppLocalizations.of(context)!;
    switch (method) {
      case 'cash': return l10n.cash;
      case 'card': return l10n.card;
      case 'transfer': return l10n.transfer;
      default: return l10n.unknown;
    }
  }

  late AppOrder currentOrder;

  @override
  void initState() {
    super.initState();
    currentOrder = widget.order;
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  String _getPaymentMethod(String method, bool isAr) {
    switch (method) {
      case 'cash':
        return 'كاش 💵';
      case 'mada':
      case 'card':
        return 'مدى 💳';
      case 'transfer':
        return 'تحويل بنكي 🏦';
      case 'apple_pay':
        return 'Apple Pay 🍏';
      case 'debt':
        return isAr ? 'آجل / ذمم (Credit)' : 'Credit';
      default:
        return method;
    }
  }

  Future<void> _cancelOrder(bool isAr) async {
    final appUser = ref.read(appUserProvider).value;
    if (appUser != null) {
      if (!context.mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final success = await PinConfirmationDialog.requirePinOrSetup(
        context, 
        appUser,
        title: isAr ? 'تحذير: إلغاء الطلب' : 'Warning: Cancel Order',
        warning: isAr 
            ? 'تحذير: سيتم إلغاء الفاتورة وإرجاع كميات الأصناف للمخزون تلقائياً، وسيتم خصم المبلغ من كاش الوردية إذا كانت مدفوعة كاش.' 
            : 'Warning: This will cancel the order, restore inventory, and deduct the amount from shift drawer if paid in cash.',
      );
      if (!success) return;
    }

    try {
        final user = ref.read(appUserProvider).value;
        final repository = ref.read(orderRepositoryProvider);

        // Actually update the database
        await repository.updateOrderStatus(currentOrder, 'cancelled');

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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(label: 'إخفاء', textColor: Colors.white, onPressed: () {}),
            ),
          );
        }
      }
  }

  // _deleteOrder function has been completely removed to enforce Soft Delete.

  void _showPartialReturnDialog(bool isAr) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PartialReturnScreen(order: currentOrder)),
    );
    if (result == true) {
      final repository = ref.read(orderRepositoryProvider);
      final updatedOrder = await repository.queryOrders(currentOrder.merchantId).where('id', isEqualTo: currentOrder.id).get();
      if (updatedOrder.docs.isNotEmpty) {
        setState(() {
          currentOrder = updatedOrder.docs.first.data();
        });
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
    final isEmployee = ref.watch(appUserProvider).value?.role == 'employee';

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
            GlassCard(
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
                            color: isCancelled ? Colors.red.withOpacity(0.2) : (currentOrder.isCredit && (currentOrder.paidAmount ?? 0.0) >= currentOrder.total) ? Colors.green.withOpacity(0.2) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isCancelled ? Colors.red : Colors.transparent),
                          ),
                          child: Text(
                            isCancelled 
                              ? (isAr ? '❌ طلب ملغي / مرتجع' : '❌ Cancelled / Refunded') 
                              : (currentOrder.isCredit && (currentOrder.paidAmount ?? 0.0) >= currentOrder.total)
                                ? (isAr ? '✅ تم سداد الفاتورة بالكامل' : '✅ Fully Paid')
                                : (isAr ? '✅ طلب مؤكد / مكتمل' : '✅ Completed'),
                            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: isCancelled ? Colors.red : null),
                          ),
                        ),
                        Text(
                          '#${currentOrder.queueNumber ?? currentOrder.id.substring(0, 6)}',
                          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 18), const SizedBox(width: 4), Text(_getPaymentMethodName(context, currentOrder.paymentMethod), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18), const SizedBox(width: 4), Text(currentOrder.customerName ?? (isAr ? 'عميل غير معروف' : 'Unknown Customer'), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (currentOrder.creatorName != null && currentOrder.creatorName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 18), const SizedBox(width: 4), Text(currentOrder.creatorName ?? '', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
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
            GlassCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentOrder.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = currentOrder.items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    title: Text(item.productName, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${isAr ? "سعر الوحدة:" : "Unit Price:"} ${item.price.toStringAsFixed(2)} ${currency.code}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                    ),
                    trailing: Text(
                      '${item.total.toStringAsFixed(2)} ${currency.code}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            // Totals Card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isAr ? 'المجموع الفرعي' : 'Subtotal', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                        Text(
                          '${currentOrder.total.toStringAsFixed(2)} ${currency.code}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final storeProfile = ref.watch(storeProfileProvider).value;
    final isEmployee = ref.watch(appUserProvider).value?.role == 'employee';
                        final defaultTaxPercentage = storeProfile?.defaultTaxPercentage ?? 0.0;
                        final defaultIsTaxInclusive = storeProfile?.defaultIsTaxInclusive ?? false;
                        
                        double totalTaxAmount = 0.0;
                        double grandTotal = 0.0;
                        bool hasTax = false;
                        
                        for (var item in currentOrder.items) {
                          final taxRate = item.taxPercentage ?? defaultTaxPercentage;
                          final isInclusive = (item.taxPercentage != null && item.taxPercentage! > 0) ? (item.isTaxInclusive ?? defaultIsTaxInclusive) : defaultIsTaxInclusive;
                          
                          final taxableBase = item.total - (item.discountAmount ?? 0.0);
                          if (taxRate > 0) {
                            hasTax = true;
                            if (isInclusive) {
                              final tax = taxableBase - (taxableBase / (1 + (taxRate / 100)));
                              totalTaxAmount += tax;
                              grandTotal += taxableBase;
                            } else {
                              final tax = taxableBase * (taxRate / 100);
                              totalTaxAmount += tax;
                              grandTotal += taxableBase + tax;
                            }
                          } else {
                            grandTotal += item.total;
                          }
                        }

                        if (hasTax) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isAr ? 'الإجمالي (قبل الضريبة)' : 'Total (Before Tax)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                                  Text('${(grandTotal - totalTaxAmount).toStringAsFixed(2)} ${currency.code}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isAr ? "إجمالي الضريبة" : "Total Tax", style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                                  Text('${totalTaxAmount.toStringAsFixed(2)} ${currency.code}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isAr ? 'المجموع النهائي للفاتورة' : 'Grand Total', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text(
                                    '${grandTotal.toStringAsFixed(2)} ${currency.code}',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isAr ? 'المبلغ المدفوع' : 'Paid Amount', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.green)),
                        Text(
                          '${(currentOrder.paidAmount ?? currentOrder.total).toStringAsFixed(2)} ${currency.code}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    if (currentOrder.isCredit) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isAr ? 'المبلغ المتبقي' : 'Remaining Amount', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.red)),
                          Text(
                            '${(currentOrder.total - (currentOrder.paidAmount ?? 0.0)).clamp(0.0, double.infinity).toStringAsFixed(2)} ${currency.code}',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
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
                      bool needsTaxPrompt = currentOrder.items.any((item) => (item.taxPercentage == null || item.taxPercentage! <= 0));
                      double? tax = storeProfile?.defaultTaxPercentage;
                      bool isInclusive = storeProfile?.defaultIsTaxInclusive ?? false;
                      if (needsTaxPrompt && (tax == null || tax <= 0)) {
                        final taxResult = await TaxDialog.show(context);
                        tax = taxResult?.percentage;
                        if (taxResult != null) {
                          isInclusive = taxResult.isInclusive;
                        }
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(order: currentOrder, currency: currency.code, taxPercentage: tax, defaultIsTaxInclusive: isInclusive),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepPurple),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.assignment_return_outlined, color: Colors.deepPurple),
                      label: Text(isAr ? 'إرجاع جزئي' : 'Partial Return', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      onPressed: () => _showPartialReturnDialog(isAr),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
