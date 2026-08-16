import '../domain/order.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/order_repository.dart';
import 'pos_screen.dart';
import 'order_details_screen.dart';
import 'pdf_viewer_screen.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../../core/widgets/tax_dialog.dart';

import '../../../core/theme/glass_card.dart';
import '../../authentication/data/auth_repository.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider).code;
    final appUser = ref.watch(appUserProvider).value;
    final canCreateOrders = appUser?.hasPermission('can_create_orders') ?? false;
    final canCancelOrders = appUser?.hasPermission('can_cancel_orders') ?? false;
    final storeProfile = ref.watch(storeProfileProvider).value;

    final repository = ref.watch(orderRepositoryProvider);

    if (appUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    var query = repository.queryOrders(
      merchantId: appUser.merchantId ?? appUser.id,
      searchQuery: _searchQuery,
      limitToRecent: !appUser.hasPermission('can_view_all_orders'),
    );

    if (_statusFilter == 'cancelled') {
      query = query.where('status', isEqualTo: 'cancelled');
    } else if (_statusFilter == 'active') {
      query = query.where('status', isEqualTo: 'pending');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orders, style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'بحث بالاسم أو رقم الفاتورة (5 أرقام)',
                    labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('الكل', style: TextStyle(fontFamily: 'Tajawal')),
                        selected: _statusFilter == 'all',
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('نشط', style: TextStyle(fontFamily: 'Tajawal')),
                        selected: _statusFilter == 'active',
                        selectedColor: Colors.blue.withValues(alpha: 0.2),
                        checkmarkColor: Colors.blue,
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = 'active');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('ملغى', style: TextStyle(fontFamily: 'Tajawal')),
                        selected: _statusFilter == 'cancelled',
                        selectedColor: Colors.red.withValues(alpha: 0.2),
                        checkmarkColor: Colors.red,
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = 'cancelled');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FirestoreListView<AppOrder>(
              query: query,
              pageSize: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              emptyBuilder: (context) => Center(
                child: Text(
                  AppLocalizations.of(context)!.text86,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'تعذر تحميل الطلبات. حاول مرة أخرى.'
                      : 'Could not load orders. Please try again.',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
              itemBuilder: (context, doc) {
                final order = doc.data();

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(0),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)));
                  },
                  child: Container(
                    decoration: order.status == 'cancelled'
                        ? BoxDecoration(
                            color: Colors.red.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1),
                          )
                        : null,
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
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                                        l10n.orderNumberLabel(order.queueNumber?.toString() ?? (order.id.length >= 5 ? order.id.substring(0, 5).toUpperCase() : order.id.toUpperCase())),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                                      ),
                                      Text('${order.total} $currency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${l10n.customer}: ${order.customerName == 'walk_in' ? l10n.walkInCustomer : order.customerName}', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${l10n.quantity}: ${order.items.fold<int>(0, (sum, item) => sum + item.quantity)}', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                      Text(DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt), style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  if (order.status == 'cancelled') ...[
                                    const SizedBox(height: 8),
                                    Text(l10n.cancelled, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                                  ],
                                  if (order.isCredit) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${l10n.credit}${l10n.paymentMethod}${order.paidAmount} $currency)', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12)),
                                    ),
                                  ],
                                  if (order.scheduledDate != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                      child: Text('موعد التسليم: ${DateFormat('yyyy/MM/dd HH:mm').format(order.scheduledDate!)}', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12)),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(_getPaymentMethodName(context, order.paymentMethod), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12)),
                                      ),
                                      if (order.creatorName != null && order.creatorName!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                          child: Text(l10n.byCreatorIcon(order.creatorName!), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.white.withValues(alpha: 0.1)),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    final needsTaxPrompt = order.items.any((item) => item.taxPercentage == null || item.taxPercentage! <= 0);
                                    double? tax = storeProfile?.defaultTaxPercentage;
                                    var isInclusive = storeProfile?.defaultIsTaxInclusive ?? false;
                                    if (needsTaxPrompt && (tax == null || tax <= 0)) {
                                      final taxResult = await TaxDialog.show(context);
                                      tax = taxResult?.percentage;
                                      if (taxResult != null) isInclusive = taxResult.isInclusive;
                                    }
                                    if (!context.mounted) return;
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(order: order, currency: currency, taxPercentage: tax, defaultIsTaxInclusive: isInclusive)));
                                  },
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.amber, size: 18),
                                  label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'فاتورة PDF' : 'PDF Invoice', style: const TextStyle(color: Colors.amber, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final needsTaxPrompt = order.items.any((item) => item.taxPercentage == null || item.taxPercentage! <= 0);
                                    double? tax = storeProfile?.defaultTaxPercentage;
                                    var isInclusive = storeProfile?.defaultIsTaxInclusive ?? false;
                                    if (needsTaxPrompt && (tax == null || tax <= 0)) {
                                      final taxResult = await TaxDialog.show(context);
                                      tax = taxResult?.percentage;
                                      if (taxResult != null) isInclusive = taxResult.isInclusive;
                                    }
                                    try {
                                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                      await PrinterService.printReceipt(order, currency, isKitchen: false, taxPercentage: tax, defaultIsTaxInclusive: isInclusive, isAr: isAr).timeout(const Duration(seconds: 5));
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'تعذر الاتصال بالطابعة الحرارية. تأكد من إعداد الطابعة بشكل صحيح.' : 'Unable to connect to printer.', style: const TextStyle(fontFamily: 'Tajawal'))),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.print_outlined, color: Colors.blueAccent, size: 18),
                                  label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'طباعة حرارية' : 'Thermal Print', style: const TextStyle(color: Colors.blueAccent, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                ),
                              ],
                            ),
                            if (canCancelOrders && order.status != 'cancelled')
                              TextButton.icon(
                                onPressed: () async {
                                  final currentUser = ref.read(appUserProvider).value;
                                  if (currentUser != null) {
                                    if (!context.mounted) return;
                                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                    final success = await PinConfirmationDialog.requirePinOrSetup(
                                      context,
                                      currentUser,
                                      title: isAr ? 'تحذير: إلغاء الطلب' : 'Warning: Cancel Order',
                                      warning: isAr
                                          ? 'تحذير: سيتم إلغاء الفاتورة وإرجاع كميات الأصناف للمخزون تلقائياً، وسيتم خصم المبلغ من كاش الوردية إذا كانت مدفوعة كاش.'
                                          : 'Warning: This will cancel the order, restore inventory, and deduct the amount from shift drawer if paid in cash.',
                                    );
                                    if (!success) return;
                                  }
                                  ref.read(orderRepositoryProvider).updateOrderStatus(order, 'cancelled');
                                },
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                label: Text(l10n.cancel, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canCreateOrders
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () async {
                final canAdd = await GuestLimitService.canAddOrder(context, ref);
                if (!canAdd) return;
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PosScreen()));
                }
              },
              label: Text(l10n.posTitle, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.point_of_sale),
            )
          : null,
    );
  }

  String _getPaymentMethodName(BuildContext context, String? method) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    switch (method) {
      case 'cash':
        return isAr ? 'كاش' : 'Cash';
      case 'card':
        return isAr ? 'بطاقة بنكية' : 'Card';
      case 'mada':
        return isAr ? 'مدى' : 'Mada';
      case 'apple_pay':
        return 'Apple Pay';
      case 'transfer':
        return isAr ? 'تحويل بنكي' : 'Bank Transfer';
      case 'split':
        return isAr ? 'دفع مقسم (كاش+شبكة)' : 'Split (Cash+Card)';
      default:
        return method ?? (isAr ? 'غير محدد' : 'Unknown');
    }
  }
}
