import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../../inventory_log/data/inventory_log_repository.dart';
import '../../../core/utils/barcode_scanner_screen.dart';

class AddProductDialog extends ConsumerStatefulWidget {
  final Product? productToEdit;
  const AddProductDialog({super.key, this.productToEdit});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _barcodeController = TextEditingController();
  String? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      _nameController.text = widget.productToEdit!.name;
      _priceController.text = widget.productToEdit!.price.toString();
      _quantityController.text = widget.productToEdit!.quantity.toString();
      _barcodeController.text = widget.productToEdit!.barcode ?? '';
      _selectedCategoryId = widget.productToEdit!.categoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
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
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('المستخدم غير مسجل');

      final productRepo = ref.read(productRepositoryProvider);
      final logRepo = ref.read(inventoryLogRepositoryProvider);

      final isEditing = widget.productToEdit != null;
      final newQuantity = int.parse(_quantityController.text);
      final previousQuantity = isEditing ? widget.productToEdit!.quantity : 0;
      
      final newProduct = Product(
        id: isEditing ? widget.productToEdit!.id : const Uuid().v4(),
        merchantId: isEditing ? widget.productToEdit!.merchantId : user.uid,
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        quantity: newQuantity,
        categoryId: _selectedCategoryId,
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        createdAt: isEditing ? widget.productToEdit!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await productRepo.updateProduct(newProduct);
        if (newQuantity != previousQuantity) {
          await logRepo?.logChange(
            productId: newProduct.id,
            productName: newProduct.name,
            previousQuantity: previousQuantity,
            newQuantity: newQuantity,
            reason: 'تعديل يدوي من الإعدادات',
            userEmail: user.email,
          );
        }
      } else {
        await productRepo.addProduct(newProduct);
        if (newQuantity > 0) {
          await logRepo?.logChange(
            productId: newProduct.id,
            productName: newProduct.name,
            previousQuantity: 0,
            newQuantity: newQuantity,
            reason: 'إضافة منتج جديد',
            userEmail: user.email,
          );
        }
      }
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
    final isEditing = widget.productToEdit != null;
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'الباركود',
                      border: OutlineInputBorder(),
                    ),
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
            categoriesAsync.when(
              data: (categories) {
                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون تصنيف', style: TextStyle(fontFamily: 'Tajawal'))),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontFamily: 'Tajawal')))),
                  ],
                  onChanged: (value) => setState(() => _selectedCategoryId = value),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => const Text('خطأ في تحميل التصنيفات'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'السعر',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية المتاحة',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(isEditing ? 'حفظ التعديلات' : 'إضافة المنتج', style: const TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
