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

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final List<CartItem> _cart = [];
  bool _isLoading = false;
  String _searchQuery = '';

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.productId == product.id);
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
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('المنتج نفذ من المخزون', style: TextStyle(fontFamily: 'Tajawal'))));
        }
      }
    });
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
        creatorId: appUser.id,
        creatorName: appUser.name ?? 'غير معروف',
        createdAt: DateTime.now(),
      );

      await ref.read(orderRepositoryProvider).createOrder(newOrder);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إتمام الطلب بنجاح', style: TextStyle(fontFamily: 'Tajawal'))));
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
    final productsAsync = ref.watch(productsStreamProvider);
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('نقطة البيع (POS)', style: TextStyle(fontFamily: 'Tajawal')),
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
                        onTap: () => _addToCart(product),
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
                            title: Text(item.productName, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
  }
}

class OrderDetails {
  final String customerId;
  final String customerName;
  final double paidAmount;
  final bool isCredit;
  final String? notes;

  OrderDetails({required this.customerId, required this.customerName, required this.paidAmount, required this.isCredit, this.notes});
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

  @override
  void initState() {
    super.initState();
    _paidController.text = widget.total.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إنهاء الطلب', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const Text('العميل: عميل عام (مشي نقدي)', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('دفع آجل؟', style: TextStyle(fontFamily: 'Tajawal')),
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
              widget.onCheckoutComplete(OrderDetails(
                customerId: 'walk_in',
                customerName: 'عميل عام',
                paidAmount: paid,
                isCredit: _isCredit,
                notes: '',
              ));
            },
            child: const Text('تأكيد وإصدار الفاتورة', style: TextStyle(fontSize: 18, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}
