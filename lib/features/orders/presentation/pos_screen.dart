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
import '../../../core/theme/glass_card.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import '../../shifts/data/shift_repository.dart';
import '../../shifts/presentation/start_shift_dialog.dart';
import '../../../core/providers/store_profile_provider.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final List<CartItem> _cart = [];
  final List<List<CartItem>> _heldOrders = [];
  bool _isLoading = false;
  String _searchQuery = '';

  void _addToCart(Product product, {List<String> selectedModifiers = const []}) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.productId == product.id && listEquals(item.selectedModifiers, selectedModifiers));
      if (existingIndex >= 0) {
        if (product.quantity > _cart[existingIndex].quantity) {
           _cart[existingIndex] = _cart[existingIndex].copyWith(
             quantity: _cart[existingIndex].quantity + 1,
             total: (_cart[existingIndex].quantity + 1) * product.price,
           );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية غير متوفرة في المخزون', style: TextStyle(fontFamily: 'Tajawal'))));
        }
      } else {
        if (product.quantity > 0) {
          _cart.add(CartItem(
            productId: product.id,
            productName: product.name,
            quantity: 1,
            price: product.price,
            total: product.price,
            selectedModifiers: List.from(selectedModifiers),
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
              onPressed: () {
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

  void _checkout() {
    if (_cart.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutSheet(
        cart: _cart,
        total: _cartTotal,
        onCheckoutComplete: (OrderDetails details) async {
          Navigator.pop(ctx);
          await _processOrder(details);
        },
      ),
    );
  }

  Future<void> _processOrder(OrderDetails details) async {
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
        total: _cartTotal,
        paidAmount: details.paidAmount,
        isCredit: details.isCredit,
        notes: details.notes,
        paymentMethod: details.paymentMethod,
        scheduledDate: details.scheduledDate,
        creatorId: appUser.id,
        creatorName: appUser.name ?? 'غير معروف',
        createdAt: DateTime.now(),
      );

      final merchantId = appUser.merchantId ?? appUser.id;
      final shift = await ref.read(currentShiftProvider(merchantId).future);

      final savedOrder = await ref.read(orderRepositoryProvider).createOrder(newOrder, shiftId: shift?.id);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إتمام الطلب بنجاح (رقم: ${savedOrder.queueNumber ?? savedOrder.id.substring(0,4)})', style: TextStyle(fontFamily: 'Tajawal'))));
      
      // Attempt to print receipt
      try {
        final storeProfile = ref.read(storeProfileProvider).value;
        await PrinterService.printReceipt(
          savedOrder, 
          ref.read(currencyProvider).code,
          storeProfile: storeProfile,
          isKitchen: false, // Could add a setting for this later if needed
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الطلب، لكن تعذرت الطباعة: $e', style: TextStyle(fontFamily: 'Tajawal'))));
      }

      setState(() {
        _cart.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: TextStyle(fontFamily: 'Tajawal'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final merchantId = user?.merchantId ?? user?.id;
    final shiftAsync = ref.watch(currentShiftProvider(merchantId ?? ''));
    
    final productsAsync = ref.watch(productsStreamProvider);
    final isTablet = MediaQuery.of(context).size.width > 600;

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
          appBar: AppBar(
            title: Text('نقطة البيع (POS)', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          if (_heldOrders.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_heldOrders.length}'),
                backgroundColor: Colors.red,
                child: const Icon(Icons.pause_circle_filled, color: Colors.amber),
              ),
              onPressed: _showHeldOrders,
              tooltip: 'عرض الطلبات المعلقة',
            ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.pause, color: Colors.amber),
              tooltip: 'تعليق الطلب',
              onPressed: () {
                setState(() {
                  _heldOrders.add(List.from(_cart));
                  _cart.clear();
                });
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final filtered = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
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
                                Text('المتبقي: ${product.quantity}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('خطأ: $e', style: TextStyle(fontFamily: 'Tajawal'))),
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
                        child: Text('دفع الإجمالي: $_cartTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
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

  OrderDetails({required this.customerId, required this.customerName, required this.paidAmount, required this.isCredit, this.notes, this.paymentMethod = 'cash', this.scheduledDate});
}

class _CheckoutSheet extends StatefulWidget {
  final List<CartItem> cart;
  final double total;
  final Function(OrderDetails) onCheckoutComplete;

  const _CheckoutSheet({required this.cart, required this.total, required this.onCheckoutComplete});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  bool _isCredit = false;
  final _paidController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _paidController.text = widget.total.toString();
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
            const Text('إنهاء الطلب', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('طلب مجدول 🗓', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
            const Text('طريقة الدفع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('كاش 💵'),
                  selected: _paymentMethod == 'cash',
                  onSelected: (val) => setState(() => _paymentMethod = 'cash'),
                ),
                ChoiceChip(
                  label: const Text('مدى 💳'),
                  selected: _paymentMethod == 'mada',
                  onSelected: (val) => setState(() => _paymentMethod = 'mada'),
                ),
                ChoiceChip(
                  label: const Text('تحويل بنكي 🏦'),
                  selected: _paymentMethod == 'transfer',
                  onSelected: (val) => setState(() => _paymentMethod = 'transfer'),
                ),
                ChoiceChip(
                  label: const Text('Apple Pay 🍏'),
                  selected: _paymentMethod == 'apple_pay',
                  onSelected: (val) => setState(() => _paymentMethod = 'apple_pay'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('دفع آجل؟ (دين)', style: TextStyle(fontFamily: 'Tajawal')),
              value: _isCredit,
              onChanged: (val) => setState(() => _isCredit = val),
            ),
            if (_isCredit) ...[
              TextField(
                controller: _paidController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ المدفوع الان', border: OutlineInputBorder()),
              )
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final paid = _isCredit ? (double.tryParse(_paidController.text) ?? 0.0) : widget.total;
                DateTime? finalSchedule;
                if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
                  finalSchedule = DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, _scheduledTime!.hour, _scheduledTime!.minute);
                }
                widget.onCheckoutComplete(OrderDetails(
                  customerId: 'walk_in',
                  customerName: 'عميل عام',
                  paidAmount: paid,
                  isCredit: _isCredit,
                  notes: '',
                  paymentMethod: _paymentMethod,
                  scheduledDate: finalSchedule,
                ));
              },
              child: const Text('تأكيد وإصدار الفاتورة', style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
