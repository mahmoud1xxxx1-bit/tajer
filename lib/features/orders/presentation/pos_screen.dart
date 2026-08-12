import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import '../domain/cart_item.dart';
import '../../customers/domain/customer.dart';
import 'package:tajer/core/utils/app_snackbar.dart';
import '../../customers/data/customer_repository.dart';
import '../../../core/services/activity_logger.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/widgets/tax_dialog.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/app_drawer.dart';
import 'package:flutter/foundation.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/start_shift_dialog.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../shifts/domain/shift.dart';
import '../../categories/data/category_repository.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final List<CartItem> _cart = [];
  final List<List<CartItem>> _heldOrders = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  void _addToCart(Product product, {List<String> selectedModifiers = const []}) {
    final storeProfile = ref.read(storeProfileProvider).value;
    final defaultTax = storeProfile?.defaultTaxPercentage ?? 0.0;
    final defaultIsInclusive = storeProfile?.defaultIsTaxInclusive ?? true;

    final finalTax = product.getEffectiveTax(defaultTax);
    final hasCustomTax = product.taxMode == TaxMode.custom;
    final finalIsInclusive = hasCustomTax ? product.isTaxInclusive : defaultIsInclusive;

    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.productId == product.id && listEquals(item.selectedModifiers, selectedModifiers));
      if (existingIndex >= 0) {
        if (product.isManufacturedOnDemand || product.quantity > _cart[existingIndex].quantity) {
           _cart[existingIndex] = _cart[existingIndex].copyWith(
             quantity: _cart[existingIndex].quantity + 1,
             total: (_cart[existingIndex].quantity + 1) * product.price,
           );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية غير متوفرة في المخزون', style: TextStyle(fontFamily: 'Tajawal'))));
        }
      } else {
        if (product.isManufacturedOnDemand || product.quantity > 0) {
          _cart.add(CartItem(
            productId: product.id,
            productName: product.name,
            quantity: 1,
            price: product.price,
            total: product.price,
            selectedModifiers: List.from(selectedModifiers),
            isTaxInclusive: finalIsInclusive,
            taxPercentage: finalTax,
            taxMode: product.taxMode,
            costPrice: product.costPrice,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('المنتج نفذ من المخزون', style: TextStyle(fontFamily: 'Tajawal'))));
        }
      }
    });
  }

  void _showModifiersSheet(Product product) {
    if (product.modifiers.isEmpty) {
      _addToCart(product);
      return;
    }
    List<String> selected = [];
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اختر الإضافات السريعة لـ ${product.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.modifiers.map((mod) {
                      final isSelected = selected.contains(mod);
                      return FilterChip(
                        label: Text(mod, style: TextStyle(fontFamily: 'Tajawal')),
                        selected: isSelected,
                        onSelected: (val) {
                          setSheetState(() {
                            if (val) {
                              selected.add(mod);
                            } else {
                              selected.remove(mod);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addToCart(product, selectedModifiers: selected);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text('إضافة للسلة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }

  void _showHeldOrders() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: _heldOrders.length,
        itemBuilder: (context, index) {
          final held = _heldOrders[index];
          final total = held.fold(0.0, (sum, item) => sum + item.total);
          return ListTile(
            title: Text('طلب معلق #${index + 1}', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            subtitle: Text('عدد المنتجات: ${held.length} - الإجمالي: $total', style: TextStyle(fontFamily: 'Tajawal')),
            trailing: IconButton(
              icon: Icon(Icons.restore, color: Colors.green),
              onPressed: () async {
                if (_cart.isNotEmpty) {
                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text(isAr ? 'تنبيه!' : 'Warning!'),
                      content: Text(isAr ? 'السلة الحالية غير فارغة. استرجاع هذا الطلب سيؤدي لمسح السلة الحالية بالكامل. هل أنت متأكد؟' : 'Current cart is not empty. Restoring this order will clear the current cart completely. Are you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(dCtx, true), 
                          child: Text(isAr ? 'نعم، استرجع وامسح' : 'Yes, Restore & Clear')
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                }
                if (!context.mounted) return;
                Navigator.pop(ctx);
                setState(() {
                  _cart.clear();
                  _cart.addAll(held);
                  _heldOrders.removeAt(index);
                });
              },
            ),
          );
        },
      ),
    );
  }

  void _updateQuantity(int index, int newQuantity, Product product) {
    if (newQuantity <= 0) {
      setState(() {
        _cart.removeAt(index);
      });
      return;
    }
    if (newQuantity > product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية غير متوفرة في المخزون', style: TextStyle(fontFamily: 'Tajawal'))));
      return;
    }
    setState(() {
      _cart[index] = _cart[index].copyWith(
        quantity: newQuantity,
        total: newQuantity * product.price,
      );
    });
  }

  double get _cartTotal => _cart.fold(0.0, (sum, item) => sum + item.total);

  double get _grandTotal {
    final storeProfile = ref.read(storeProfileProvider).value;
    final defaultTaxPercentage = storeProfile?.defaultTaxPercentage ?? 0.0;
    final defaultIsTaxInclusive = storeProfile?.defaultIsTaxInclusive ?? false;
    double gt = 0.0;
    for (var item in _cart) {
      final itemTax = item.getEffectiveTax(defaultTaxPercentage);
      final itemInclusive = item.taxMode == TaxMode.custom ? (item.isTaxInclusive ?? defaultIsTaxInclusive) : defaultIsTaxInclusive;
      if (itemInclusive) {
        gt += item.total;
      } else {
        gt += item.total + (item.total * (itemTax / 100));
      }
    }
    return gt;
  }

  void _checkout() {
    if (_cart.isEmpty) return;
    
    final appUser = ref.read(appUserProvider).value;
    final merchantId = appUser?.merchantId ?? appUser?.id ?? '';
    final currentShift = ref.read(currentShiftProvider(merchantId)).value;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (currentShift == null) {
      final amountController = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.point_of_sale, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(isAr ? "درج الكاشير مغلق!" : "Drawer Closed!", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr 
                  ? "يجب فتح وردية لاستلام هذه المبيعة. كم يوجد في الدرج الآن لبدء البيع؟"
                  : "You must open a shift to process this sale. How much is in the drawer now?",
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isAr ? 'المبلغ الافتتاحي' : 'Opening Amount',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.money),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? "إلغاء" : "Cancel", style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final openingAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                Navigator.pop(ctx);
                
                final shift = Shift(
                  id: const Uuid().v4(),
                  merchantId: merchantId,
                  employeeId: appUser?.id ?? '',
                  employeeName: appUser?.name ?? 'Unknown',
                  startTime: DateTime.now(),
                  startCash: openingAmount,
                  status: 'open',
                );
                await ref.read(shiftRepositoryProvider).openShift(shift);
                
                if (context.mounted) _checkout();
              },
              icon: const Icon(Icons.lock_open),
              label: Text(isAr ? "افتح الدرج وأكمل البيع" : "Open Drawer & Continue", style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ).then((_) {
        amountController.dispose();
      });
      return;
    }

    final customers = (ref.read(customersStreamProvider).value ?? []).where((c) => c.isActive).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutSheet(
        cart: _cart,
        total: _grandTotal,
        customers: customers,
        onCheckoutComplete: (OrderDetails details) async {
          Navigator.pop(ctx);
          await _processOrder(details);
        },
      ),
    );
  }

  Future<void> _processOrder(OrderDetails details) async {
    if (_isLoading) return; // Prevent double submission
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      final appUser = ref.read(appUserProvider).value;
      if (user == null || appUser == null) throw Exception(AppLocalizations.of(context)!.text47);

      final newOrder = AppOrder(
        id: Uuid().v4(),
        merchantId: appUser.merchantId ?? user.uid,
        customerId: details.customerId,
        customerName: details.customerName,
        items: List.from(_cart),
        total: _grandTotal,
        paidAmount: details.paidAmount,
        isCredit: details.isCredit,
        notes: details.notes,
        paymentMethod: details.paymentMethod,
        scheduledDate: details.scheduledDate,
        tenderedAmount: details.tenderedAmount,
        changeAmount: details.changeAmount,
        splitCashAmount: details.splitCashAmount,
        splitNetworkAmount: details.splitNetworkAmount,
        creatorId: appUser.id,
        creatorName: appUser.name ?? 'غير معروف',
        createdAt: DateTime.now(),
      );

      final merchantId = appUser.merchantId ?? appUser.id;
      final shift = await ref.read(currentShiftProvider(merchantId).future);
      final currency = ref.read(currencyProvider).code;

      final savedOrder = await ref.read(orderRepositoryProvider).createOrder(newOrder, shiftId: shift?.id);

      // Stop loading and clear cart immediately so UI never hangs!
      setState(() {
        _cart.clear();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم إتمام الطلب بنجاح (رقم الانتظار: ${savedOrder.queueNumber ?? savedOrder.id.substring(0,4)}) 🎉', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ));
      }
      final storeProfile = ref.read(storeProfileProvider).value;
      double? tax = storeProfile?.defaultTaxPercentage;
      
      // Do not pop the POS screen! Just stay on it for the next customer.
      // if (mounted) {
      //   Navigator.pop(context, true);
      // }

      // Attempt to print receipt asynchronously in background with a 5-second timeout
      final bool isAr = Localizations.localeOf(context).languageCode == 'ar';
      PrinterService.printReceipt(
        savedOrder, 
        currency,
        storeProfile: storeProfile,
        isKitchen: false,
        taxPercentage: tax,
        defaultIsTaxInclusive: storeProfile?.defaultIsTaxInclusive ?? false,
        isAr: isAr,
      ).timeout(const Duration(seconds: 5)).catchError((e) {
        debugPrint('Auto-print ignored or failed: $e');
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final merchantId = user?.merchantId ?? user?.id;
    final shiftAsync = ref.watch(currentShiftProvider(merchantId ?? ''));
    
    final productsAsync = ref.watch(productsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final isTablet = MediaQuery.of(context).size.width > 600;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return shiftAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (shift) {
        if (shift == null) {
          return const Scaffold(
            body: Center(
              child: StartShiftDialog(),
            ),
          );
        }

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Text(isAr ? 'نقطة البيع (POS)' : 'Point of Sale (POS)', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            actions: [
              if (_heldOrders.isNotEmpty)
                TextButton.icon(
                  icon: Badge(
                    label: Text('${_heldOrders.length}'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.history, color: Colors.amber),
                  ),
                  label: Text(isAr ? 'المعلقة' : 'Held', style: const TextStyle(color: Colors.amber, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  onPressed: _showHeldOrders,
                ),
              if (_cart.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.pause_circle_outline, color: Colors.amber),
                  label: Text(isAr ? 'تعليق' : 'Hold', style: const TextStyle(color: Colors.amber, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() {
                      _heldOrders.add(List.from(_cart));
                      _cart.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isAr ? 'تم تعليق الطلب وحفظه مؤقتاً في الأعلى 📌' : 'Order held and saved temporarily 📌', style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.orange),
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: isAr ? 'ابحث عن منتج أو امسح الباركود...' : 'Search product or scan barcode...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                  onSubmitted: (val) {
                    final trimmed = val.trim();
                    if (trimmed.isEmpty) return;
                    final products = productsAsync.value ?? [];
                    final matchedProduct = products.where((p) => p.barcode == trimmed).firstOrNull;
                    if (matchedProduct != null) {
                      _addToCart(matchedProduct);
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    }
                  },
                ),
              ),
            ),
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isAr 
                              ? '💡 دليل الكاشير: اضغط على المنتج لإضافته للسلة. لحفظ الفاتورة مؤقتاً أثناء انتظام العميل اضغط على زر "تعليق" بالأعلى. لإصدار الفاتورة اضغط "دفع الإجمالي" بالأسفل.'
                              : '💡 Cashier Guide: Tap product to add to cart. To hold invoice temporarily, tap "Hold" above. To issue invoice, tap "Pay Total" below.',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  categoriesAsync.when(
                    data: (categories) {
                      if (categories.isEmpty) return const SizedBox.shrink();
                      return Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(isAr ? 'الكل' : 'All', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                selected: _selectedCategoryId == null,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedCategoryId = null);
                                },
                              ),
                            ),
                            ...categories.map((category) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(category.name, style: const TextStyle(fontFamily: 'Tajawal')),
                                selected: _selectedCategoryId == category.id,
                                onSelected: (selected) {
                                  setState(() => _selectedCategoryId = selected ? category.id : null);
                                },
                              ),
                            )),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: productsAsync.when(
                      data: (products) {
                        final filtered = products.where((p) {
                          final matchesSearch = p.name.toLowerCase().contains(_searchQuery) || (p.barcode != null && p.barcode!.toLowerCase().contains(_searchQuery));
                          final matchesCategory = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
                          return matchesSearch && matchesCategory;
                        }).toList();
                        if (filtered.isEmpty) return const Center(child: Text('لا توجد منتجات', style: TextStyle(fontFamily: 'Tajawal')));
                  
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 4 : 2,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return InkWell(
                        onTap: () => _showModifiersSheet(product),
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(height: 8),
                                Text(product.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text('${product.price}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(isAr ? 'المتبقي: ${product.quantity}' : 'Left: ${product.quantity}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text(isAr ? 'خطأ: $e' : 'Error: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
              ),
            ),
            if (_cart.isNotEmpty)
              Container(
                height: isTablet ? 250 : 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          final product = productsAsync.value?.firstWhere((p) => p.id == item.productId);
                          return ListTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                if (item.selectedModifiers.isNotEmpty)
                                  Text(item.selectedModifiers.join('، '), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.blue)),
                              ],
                            ),
                            subtitle: Text('${item.price} x ${item.quantity} = ${item.total}', style: const TextStyle(color: Colors.green)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => product != null ? _updateQuantity(index, item.quantity - 1, product) : null),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => product != null ? _updateQuantity(index, item.quantity + 1, product) : null),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _checkout,
                        child: Text(isAr ? 'دفع الإجمالي: ${_grandTotal.toStringAsFixed(2)}' : 'Pay Total: ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      ),
                    )
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  }
}

class OrderDetails {
  final String customerId;
  final String customerName;
  final double paidAmount;
  final bool isCredit;
  final String? notes;
  final String paymentMethod;
  final DateTime? scheduledDate;
  final double? tenderedAmount;
  final double? changeAmount;
  final double? splitCashAmount;
  final double? splitNetworkAmount;

  OrderDetails({required this.customerId, required this.customerName, required this.paidAmount, required this.isCredit, this.notes, this.paymentMethod = 'cash', this.scheduledDate, this.tenderedAmount, this.changeAmount, this.splitCashAmount, this.splitNetworkAmount});
}

class _CheckoutSheet extends ConsumerStatefulWidget {
  final List<CartItem> cart;
  final double total;
  final List<Customer> customers;
  final Function(OrderDetails) onCheckoutComplete;

  const _CheckoutSheet({required this.cart, required this.total, required this.customers, required this.onCheckoutComplete});

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  bool _isCredit = false;
  final _paidController = TextEditingController();
  final _tenderedController = TextEditingController();
  final _splitCashController = TextEditingController();
  final _splitNetworkController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  String? _selectedCustomerId;
  late List<Customer> _localCustomers;
  bool _highlightCustomer = false;

  @override
  void initState() {
    super.initState();
    _paidController.text = widget.total.toString();
    _localCustomers = List.from(widget.customers);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _paidController.dispose();
    _tenderedController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _scheduledDate = pickedDate;
          _scheduledTime = pickedTime;
        });
      } else {
        setState(() => _isScheduled = false);
      }
    } else {
      setState(() => _isScheduled = false);
    }
  }

  void _showQuickAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة عميل سريع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final user = ref.read(appUserProvider).value;
              if (user == null) return;
              
              final newCustomer = Customer(
                id: const Uuid().v4(),
                merchantId: user.merchantId ?? user.id,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                createdAt: DateTime.now(),
              );
              
              await ref.read(customerRepositoryProvider).addCustomer(newCustomer);
              await ActivityLogger.log(
                user: user,
                actionType: 'Quick Customer Added|إضافة عميل سريع',
                description: 'Added customer (${newCustomer.name}) from POS|تم إضافة العميل (${newCustomer.name}) من الكاشير',
              );
              
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {
                  _localCustomers.add(newCustomer);
                  _selectedCustomerId = newCustomer.id;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم إضافة العميل ${newCustomer.name} بنجاح', style: const TextStyle(fontFamily: 'Tajawal'))),
                );
              }
            },
            child: Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final appUser = ref.watch(appUserProvider).value;
    final canManageCustomers = appUser?.hasPermission('can_manage_customers') ?? false;
    final canSellOnCredit = appUser?.hasPermission('can_sell_on_credit') ?? false;

    // Calculate Grand Total including taxes correctly for validation
    final storeProfile = ref.read(storeProfileProvider).value;
    final defaultTaxPercentage = storeProfile?.defaultTaxPercentage ?? 0.0;
    final defaultIsTaxInclusive = storeProfile?.defaultIsTaxInclusive ?? false;
    
    double grandTotal = 0.0;
    for (var item in widget.cart) {
      final itemTax = item.getEffectiveTax(defaultTaxPercentage);
      final isInclusive = item.taxMode == TaxMode.custom ? (item.isTaxInclusive ?? defaultIsTaxInclusive) : defaultIsTaxInclusive;
      if (isInclusive) {
        grandTotal += item.total;
      } else {
        grandTotal += item.total + (item.total * (itemTax / 100));
      }
    }
    
    final requiredAmount = _isCredit ? (double.tryParse(_paidController.text) ?? 0.0) : grandTotal;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isAr ? 'إنهاء الطلب' : 'Checkout', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _highlightCustomer ? Colors.red.withOpacity(0.1) : Colors.transparent,
                border: Border.all(color: _highlightCustomer ? Colors.red : Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<Customer>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Customer>.empty();
                            }
                            return _localCustomers.where((Customer customer) {
                              return customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                     customer.phone.contains(textEditingValue.text);
                            });
                          },
                          displayStringForOption: (Customer option) => option.name,
                          onSelected: (Customer selection) {
                            setState(() {
                              _selectedCustomerId = selection.id;
                            });
                          },
                          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                            if (_selectedCustomerId != null) {
                              final currentCustomer = _localCustomers.firstWhere((c) => c.id == _selectedCustomerId, orElse: () => Customer(id: '', merchantId: '', name: '', phone: '', createdAt: DateTime.now()));
                              if (currentCustomer.id.isNotEmpty && textEditingController.text != currentCustomer.name) {
                                textEditingController.text = currentCustomer.name;
                              }
                            }
                            
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: isAr ? 'ابحث عن اسم أو رقم العميل' : 'Search customer name or phone',
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(fontFamily: 'Tajawal', color: _highlightCustomer ? Colors.red : null),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    textEditingController.clear();
                                    setState(() {
                                      _selectedCustomerId = null;
                                    });
                                  },
                                ),
                              ),
                              onFieldSubmitted: (String value) {
                                onFieldSubmitted();
                              },
                            );
                          },
                          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Customer> onSelected, Iterable<Customer> options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 200, 
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Customer option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(option.name, style: const TextStyle(fontFamily: 'Tajawal')),
                                        subtitle: Text(option.phone, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                                        onTap: () {
                                          onSelected(option);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canManageCustomers)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: _highlightCustomer ? Colors.red.withOpacity(0.2) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.person_add, color: _highlightCustomer ? Colors.red : Theme.of(context).colorScheme.primary),
                        tooltip: isAr ? 'إضافة عميل جديد' : 'Add New Customer',
                        onPressed: _showQuickAddCustomerDialog,
                      ),
                    ),
                ],
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
              title: Text(isAr ? 'طلب مجدول 🗓' : 'Scheduled Order 🗓', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              subtitle: _isScheduled && _scheduledDate != null && _scheduledTime != null
                  ? Text('${_scheduledDate!.toString().split(' ')[0]} - ${_scheduledTime!.format(context)}', style: TextStyle(color: Colors.blue))
                  : null,
              value: _isScheduled,
              onChanged: (val) {
                setState(() {
                  _isScheduled = val;
                  if (val) _selectDateTime();
                });
              },
            ),
            const SizedBox(height: 16),
            Text(isAr ? 'طريقة الدفع' : 'Payment Method', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(isAr ? 'كاش 💵' : 'Cash 💵'),
                  selected: _paymentMethod == 'cash',
                  onSelected: (val) => setState(() => _paymentMethod = 'cash'),
                ),
                ChoiceChip(
                  label: Text(isAr ? 'مدى 💳' : 'Mada/Card 💳'),
                  selected: _paymentMethod == 'mada',
                  onSelected: (val) => setState(() => _paymentMethod = 'mada'),
                ),
                ChoiceChip(
                  label: Text(isAr ? 'تحويل بنكي 🏦' : 'Bank Transfer 🏦'),
                  selected: _paymentMethod == 'transfer',
                  onSelected: (val) => setState(() => _paymentMethod = 'transfer'),
                ),
                ChoiceChip(
                  label: Text('Apple Pay 🍏'),
                  selected: _paymentMethod == 'apple_pay',
                  onSelected: (val) => setState(() => _paymentMethod = 'apple_pay'),
                ),
                ChoiceChip(
                  label: Text(isAr ? 'متعدد 🔀' : 'Split 🔀'),
                  selected: _paymentMethod == 'split',
                  onSelected: (val) {
                    setState(() {
                      _paymentMethod = 'split';
                      _splitNetworkController.text = requiredAmount.toStringAsFixed(2);
                      _splitCashController.text = '0';
                    });
                  },
                ),
              ],
            ),
            if (_paymentMethod == 'split') ...[
               const SizedBox(height: 16),
               Row(
                 children: [
                   Expanded(
                     child: TextField(
                       controller: _splitCashController,
                       keyboardType: TextInputType.number,
                       decoration: InputDecoration(labelText: isAr ? 'نقدي (كاش)' : 'Cash', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money)),
                       onChanged: (val) {
                         final cash = double.tryParse(val) ?? 0.0;
                         if (cash <= requiredAmount) {
                           _splitNetworkController.text = (requiredAmount - cash).toStringAsFixed(2);
                         }
                         setState((){});
                       },
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextField(
                       controller: _splitNetworkController,
                       keyboardType: TextInputType.number,
                       decoration: InputDecoration(labelText: isAr ? 'شبكة (بطاقة)' : 'Network', border: OutlineInputBorder(), prefixIcon: Icon(Icons.credit_card)),
                       onChanged: (val) {
                         final network = double.tryParse(val) ?? 0.0;
                         if (network <= requiredAmount) {
                           _splitCashController.text = (requiredAmount - network).toStringAsFixed(2);
                         }
                         setState((){});
                       },
                     ),
                   ),
                 ],
               ),
                 Builder(
                 builder: (context) {
                   final cash = double.tryParse(_splitCashController.text) ?? 0.0;
                   final network = double.tryParse(_splitNetworkController.text) ?? 0.0;
                   final diff = requiredAmount - (cash + network);
                   if (diff.abs() > 0.01) {
                     return Padding(
                       padding: const EdgeInsets.only(top: 8.0),
                       child: Text('المجموع لا يساوي المبلغ المدفوع (${requiredAmount.toStringAsFixed(2)})', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                     );
                   }
                   return const SizedBox.shrink();
                 }
               )
            ],
            const SizedBox(height: 16),
            if (canSellOnCredit)
              SwitchListTile(
                title: Text(isAr ? 'دفع آجل؟ (دين)' : 'Pay Later? (Credit)', style: TextStyle(fontFamily: 'Tajawal')),
                value: _isCredit,
                onChanged: (val) => setState(() => _isCredit = val),
              ),
            if (_isCredit) ...[
              TextField(
                controller: _paidController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: isAr ? 'المبلغ المدفوع الان' : 'Amount Paid Now', border: OutlineInputBorder()),
                onChanged: (val) => setState(() {
                  if (_paymentMethod == 'split') {
                     final newPaid = double.tryParse(val) ?? 0.0;
                     _splitNetworkController.text = newPaid.toStringAsFixed(2);
                     _splitCashController.text = '0';
                  }
                }),
              )
            ],
            if (_paymentMethod == 'cash') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _tenderedController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: isAr ? 'المبلغ المستلم فعلياً (لحساب الباقي)' : 'Tendered Amount (Cash only)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined)),
                onChanged: (val) => setState(() {}),
              ),
              if (_tenderedController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final tendered = double.tryParse(_tenderedController.text) ?? 0.0;
                    final change = tendered - requiredAmount;
                    if (tendered > 0 && change >= 0) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                        child: Text(
                          'المتبقي للعميل: ${change.toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      );
                    } else if (tendered > 0 && change < 0) {
                      return Text('المبلغ غير كافٍ', style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold), textAlign: TextAlign.center);
                    }
                    return const SizedBox.shrink();
                  }
                ),
              ],
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Removed local grandTotal calculation to use the one computed at the start of build()
                final paid = _isCredit ? (double.tryParse(_paidController.text) ?? 0.0) : grandTotal;
                
                // 1. التحقق من الدفع المتعدد (إلزامي في الكاش والآجل معاً)
                if (_paymentMethod == 'split') {
                   final cash = double.tryParse(_splitCashController.text) ?? 0.0;
                   final network = double.tryParse(_splitNetworkController.text) ?? 0.0;
                   final diff = requiredAmount - (cash + network);
                   if (diff.abs() > 0.01) {
                     showDialog(context: context, builder: (ctx) => AlertDialog(
                         title: Text(isAr ? 'تنبيه' : 'Warning', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
                         content: Text(isAr ? 'يجب أن يتطابق مجموع المبالغ مع المبلغ المدفوع (${requiredAmount.toStringAsFixed(2)}).' : 'Split amounts must match the paid amount.', style: TextStyle(fontFamily: 'Tajawal')),
                         actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'حسناً' : 'OK', style: TextStyle(fontFamily: 'Tajawal')))]
                     ));
                     return;
                   }
                }
                
                // 2. التحقق من الكاش وحساب الباقي (منع ظهور الباقي بالسالب)
                if (_paymentMethod == 'cash' && _tenderedController.text.isNotEmpty) {
                  final tendered = double.tryParse(_tenderedController.text);
                  if (tendered == null || tendered < requiredAmount) {
                     showDialog(context: context, builder: (ctx) => AlertDialog(
                         title: Text(isAr ? 'تنبيه' : 'Warning', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
                         content: Text(isAr ? 'المبلغ المستلم من العميل غير كافٍ لتغطية المطلوب.' : 'Tendered amount is insufficient.', style: TextStyle(fontFamily: 'Tajawal')),
                         actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'حسناً' : 'OK', style: TextStyle(fontFamily: 'Tajawal')))]
                     ));
                     return;
                  }
                }
                
                // --- Validation for Anonymous Debt ---
                if (_isCredit && _selectedCustomerId == null) {
                   _triggerHighlight();
                   showDialog(
                     context: context,
                     builder: (ctx) => AlertDialog(
                       title: Text('تنبيه', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.orange)),
                       content: Text('لا يمكن تسجيل فاتورة آجلة لعميل عام.\nيرجى اختيار العميل من القائمة أو إضافة عميل جديد بالضغط على علامة (+).', style: TextStyle(fontFamily: 'Tajawal')),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(ctx), child: Text('حسناً', style: TextStyle(fontFamily: 'Tajawal')))
                       ],
                     )
                   );
                   return;
                }

                if (paid < grandTotal && _selectedCustomerId == null) {
                   _triggerHighlight();
                   showDialog(
                     context: context,
                     builder: (ctx) => AlertDialog(
                       title: Text('تنبيه', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.orange)),
                       content: Text('المبلغ المدفوع أقل من الإجمالي.\nيرجى إضافة العميل لتسجيل المتبقي كدين في حسابه.', style: TextStyle(fontFamily: 'Tajawal')),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(ctx), child: Text('حسناً', style: TextStyle(fontFamily: 'Tajawal')))
                       ],
                     )
                   );
                   return;
                }
                // -------------------------------------

                DateTime? finalSchedule;
                if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
                  finalSchedule = DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, _scheduledTime!.hour, _scheduledTime!.minute);
                }
                String finalCustomerId = 'walk_in';
                String finalCustomerName = 'عميل عام';
                if (_selectedCustomerId != null) {
                  final customer = _localCustomers.firstWhere((c) => c.id == _selectedCustomerId, orElse: () => Customer(id: _selectedCustomerId!, merchantId: '', name: 'عميل عام', phone: '', createdAt: DateTime.now()));
                  finalCustomerId = customer.id;
                  finalCustomerName = customer.name;
                }
                
                widget.onCheckoutComplete(OrderDetails(
                  customerId: finalCustomerId,
                  customerName: finalCustomerName,
                  paidAmount: paid,
                  isCredit: _isCredit || paid < grandTotal,
                  notes: '',
                  paymentMethod: _paymentMethod,
                  scheduledDate: finalSchedule,
                  tenderedAmount: _paymentMethod == 'cash' && _tenderedController.text.isNotEmpty ? double.tryParse(_tenderedController.text) : null,
                  changeAmount: _paymentMethod == 'cash' && _tenderedController.text.isNotEmpty ? (double.tryParse(_tenderedController.text) ?? 0) - paid : null,
                  splitCashAmount: _paymentMethod == 'split' ? (double.tryParse(_splitCashController.text) ?? 0) : null,
                  splitNetworkAmount: _paymentMethod == 'split' ? (double.tryParse(_splitNetworkController.text) ?? 0) : null,
                ));
              },
              child: Text(isAr ? 'تأكيد وإصدار الفاتورة' : 'Confirm & Issue Invoice', style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _triggerHighlight() async {
    setState(() => _highlightCustomer = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _highlightCustomer = false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _highlightCustomer = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _highlightCustomer = false);
  }
}
