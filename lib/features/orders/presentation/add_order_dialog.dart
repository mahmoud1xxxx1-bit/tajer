import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../../products/data/product_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import '../../inventory_log/data/inventory_log_repository.dart';
import '../../../core/utils/barcode_scanner_screen.dart';
import '../../products/domain/product.dart';

class AddOrderDialog extends ConsumerStatefulWidget {
  const AddOrderDialog({super.key});

  @override
  ConsumerState<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends ConsumerState<AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  String? _selectedProductId;
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _barcodeController = TextEditingController();
  bool _isCredit = false;
  bool _isLoading = false;
  
  List<Product> _products = [];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _paidAmountController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result != null && result is String) {
      setState(() {
        _barcodeController.text = result;
      });
      _findProductByBarcode(result);
    }
  }

  void _findProductByBarcode(String barcode) {
    try {
      final product = _products.firstWhere((p) => p.barcode == barcode);
      setState(() {
        _selectedProductId = product.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم اختيار المنتج: ${product.name}', style: const TextStyle(fontFamily: 'Tajawal'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على منتج بهذا الباركود', style: TextStyle(fontFamily: 'Tajawal'))),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedCustomerId == null || _selectedProductId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('المستخدم غير مسجل');

      final orderRepo = ref.read(orderRepositoryProvider);
      final logRepo = ref.read(inventoryLogRepositoryProvider);

      final customers = ref.read(customersStreamProvider).value ?? [];

      final selectedProduct = _products.firstWhere((p) => p.id == _selectedProductId);
      final selectedCustomer = customers.firstWhere((c) => c.id == _selectedCustomerId);

      final quantity = int.parse(_quantityController.text);
      final total = selectedProduct.price * quantity;

      if (selectedProduct.quantity < quantity) {
        throw Exception('الكمية المطلوبة غير متوفرة في المخزون');
      }

      double paidAmount = total;
      if (_isCredit) {
        if (_paidAmountController.text.isNotEmpty) {
          paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
        } else {
          paidAmount = 0.0;
        }
        if (paidAmount > total) {
          throw Exception('المبلغ المدفوع لا يمكن أن يكون أكبر من الإجمالي');
        }
      }

      final newOrder = AppOrder(
        id: const Uuid().v4(),
        merchantId: user.uid,
        customerId: selectedCustomer.id,
        customerName: selectedCustomer.name,
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        quantity: quantity,
        price: selectedProduct.price,
        total: total,
        paidAmount: paidAmount,
        isCredit: _isCredit,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await orderRepo.createOrder(newOrder);

      // Log inventory change
      await logRepo?.logChange(
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        previousQuantity: selectedProduct.quantity,
        newQuantity: selectedProduct.quantity - quantity,
        reason: 'طلب مبيعات جديد (فاتورة)',
        userEmail: user.email,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsStreamProvider);
    final customersState = ref.watch(customersStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إنشاء طلب جديد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Customer Dropdown
            customersState.when(
              data: (customers) => DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(labelText: 'العميل', border: OutlineInputBorder()),
                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
                onChanged: (val) => setState(() => _selectedCustomerId = val),
                validator: (val) => val == null ? 'يرجى اختيار العميل' : null,
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('خطأ في تحميل العملاء: $e'),
            ),
            const SizedBox(height: 16),

            // Barcode search
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'بحث بالباركود',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (val) => _findProductByBarcode(val.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.blue, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Dropdown
            productsState.when(
              data: (products) {
                _products = products;
                return DropdownButtonFormField<String>(
                  value: _selectedProductId,
                  decoration: const InputDecoration(labelText: 'أو اختر المنتج من القائمة', border: OutlineInputBorder()),
                  items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (متاح: ${p.quantity})', style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
                  onChanged: (val) => setState(() => _selectedProductId = val),
                  validator: (val) => val == null ? 'يرجى اختيار المنتج' : null,
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('خطأ في تحميل المنتجات: $e'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الكمية المطلوبة',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Credit / Debt Section
            SwitchListTile(
              title: const Text('بيع آجل (دين)', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              subtitle: const Text('تسجيل الطلب كدين على العميل', style: TextStyle(fontFamily: 'Tajawal')),
              value: _isCredit,
              onChanged: (val) {
                setState(() {
                  _isCredit = val;
                  if (!val) {
                    _paidAmountController.clear();
                  }
                });
              },
            ),
            
            if (_isCredit) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _paidAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع مقدماً (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
            ],
            
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('اعتماد الطلب', style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
