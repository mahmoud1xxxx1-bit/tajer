import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tajer/l10n/app_localizations.dart';
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
        SnackBar(content: Text('تم اختيار المنتج: ${product.name}', style: TextStyle(fontFamily: 'Tajawal'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.text_79, style: TextStyle(fontFamily: 'Tajawal'))),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedProductId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception(AppLocalizations.of(context)!.text_47);

      final orderRepo = ref.read(orderRepositoryProvider);
      final logRepo = ref.read(inventoryLogRepositoryProvider);

      final customers = ref.read(customersStreamProvider).value ?? [];

      final selectedProduct = _products.firstWhere((p) => p.id == _selectedProductId);
      
      String finalCustomerId = 'walk_in';
      String finalCustomerName = 'عميل عام';
      
      if (_selectedCustomerId != null) {
        final c = customers.firstWhere((c) => c.id == _selectedCustomerId);
        finalCustomerId = c.id;
        finalCustomerName = c.name;
      }

      final quantity = int.parse(_quantityController.text);
      final total = selectedProduct.price * quantity;

      if (selectedProduct.quantity < quantity) {
        throw Exception(AppLocalizations.of(context)!.text_80);
      }

      double paidAmount = total;
      if (_isCredit) {
        if (_paidAmountController.text.isNotEmpty) {
          paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
        } else {
          paidAmount = 0.0;
        }
        if (paidAmount > total) {
          throw Exception(AppLocalizations.of(context)!.text_81);
        }
      }

      final newOrder = AppOrder(
        id: const Uuid().v4(),
        merchantId: user.uid,
        customerId: finalCustomerId,
        customerName: finalCustomerName,
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
        reason: AppLocalizations.of(context)!.text_82,
        userEmail: user.email,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final productsState = ref.watch(productsStreamProvider);
    final customersState = ref.watch(customersStreamProvider);

    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.add,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Customer Dropdown
            customersState.when(
              data: (customers) => DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: InputDecoration(labelText: l10n.customers, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: null, child: Text('عميل عام (بدون تحديد)', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey))),
                  ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(fontFamily: 'Tajawal')))).toList(),
                ],
                onChanged: (val) => setState(() => _selectedCustomerId = val),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('${l10n.error}: $e'),
            ),
            SizedBox(height: 16),

            // Barcode search
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: l10n.searchByBarcode,
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (val) => _findProductByBarcode(val.trim()),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: _scanBarcode,
                  icon: Icon(Icons.qr_code_scanner, color: Colors.blue, size: 32),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Product Dropdown
            productsState.when(
              data: (products) {
                _products = products;
                return DropdownButtonFormField<String>(
                  value: _selectedProductId,
                  decoration: InputDecoration(labelText: l10n.products, border: const OutlineInputBorder()),
                  items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${l10n.quantity}: ${p.quantity})', style: TextStyle(fontFamily: 'Tajawal')))).toList(),
                  onChanged: (val) => setState(() => _selectedProductId = val),
                  validator: (val) => val == null ? l10n.requiredField : null,
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('${l10n.error}: $e'),
            ),
            SizedBox(height: 16),

            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.quantity,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? l10n.requiredField : null,
            ),
            SizedBox(height: 16),
            
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.notes,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),

            // Credit / Debt Section
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.text_83, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              subtitle: Text(AppLocalizations.of(context)!.text_84, style: TextStyle(fontFamily: 'Tajawal')),
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
              SizedBox(height: 8),
              TextFormField(
                controller: _paidAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.text_85,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
            ],
            
            SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(l10n.confirm, style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

