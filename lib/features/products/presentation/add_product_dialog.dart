import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../../inventory_log/data/inventory_log_repository.dart';
import '../../../core/utils/barcode_scanner_screen.dart';
import '../domain/raw_material.dart';
import '../data/raw_material_repository.dart';

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
  final _modifiersController = TextEditingController();
  final _rawMaterialQtyController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedRawMaterialId;
  List<RecipeItem> _recipe = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      _nameController.text = widget.productToEdit!.name;
      _priceController.text = widget.productToEdit!.price.toString();
      _quantityController.text = widget.productToEdit!.quantity.toString();
      _barcodeController.text = widget.productToEdit!.barcode ?? '';
      _modifiersController.text = widget.productToEdit!.modifiers.join('، ');
      _selectedCategoryId = widget.productToEdit!.categoryId;
      _recipe = List.from(widget.productToEdit!.recipe);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    _modifiersController.dispose();
    _rawMaterialQtyController.dispose();
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
      if (user == null) throw Exception(AppLocalizations.of(context)!.text47);
      final appUser = ref.read(appUserProvider).value;

      final productRepo = ref.read(productRepositoryProvider);
      final logRepo = ref.read(inventoryLogRepositoryProvider);

      final isEditing = widget.productToEdit != null;
      final newQuantity = int.parse(_quantityController.text);
      final previousQuantity = isEditing ? widget.productToEdit!.quantity : 0;
      
      final newProduct = Product(
        id: isEditing ? widget.productToEdit!.id : Uuid().v4(),
        merchantId: isEditing ? widget.productToEdit!.merchantId : (ref.read(appUserProvider).value?.merchantId ?? user.uid),
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        quantity: newQuantity,
        categoryId: _selectedCategoryId,
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        modifiers: _modifiersController.text.trim().isEmpty ? [] : _modifiersController.text.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        recipe: _recipe,
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
            reason: AppLocalizations.of(context)!.text100,
            userEmail: appUser?.name ?? user.email,
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
            reason: AppLocalizations.of(context)!.text101,
            userEmail: appUser?.name ?? user.email,
          );
        }
      }
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
    final isEditing = widget.productToEdit != null;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final appUser = ref.watch(appUserProvider).value;
    final merchantId = appUser?.merchantId ?? ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    final rawMaterialsAsync = ref.watch(rawMaterialsStreamProvider(merchantId));

    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? l10n.edit : l10n.add,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: l10n.barcode,
                      border: const OutlineInputBorder(),
                    ),
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
            categoriesAsync.when(
              data: (categories) {
                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: l10n.category,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.noCategory, style: TextStyle(fontFamily: 'Tajawal'))),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(fontFamily: 'Tajawal')))),
                  ],
                  onChanged: (value) => setState(() => _selectedCategoryId = value),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text(l10n.error),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.productName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? l10n.requiredField : null,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.price,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? l10n.requiredField : null,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.availableQuantity,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? l10n.requiredField : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _modifiersController,
              decoration: InputDecoration(
                labelText: 'أزرار سريعة (اختياري)',
                hintText: 'مثال: بدون بصل، سفري، حار',
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 16),
            Text(isAr ? 'المقادير (المواد الخام)' : 'Recipe (Raw Materials)', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            rawMaterialsAsync.when(
              data: (materials) {
                if (materials.isEmpty) {
                  return Text(isAr ? 'لا توجد مواد خام مضافة' : 'No raw materials added', style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal'));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedRawMaterialId,
                            decoration: InputDecoration(
                              labelText: isAr ? 'المادة الخام' : 'Raw Material',
                              border: const OutlineInputBorder(),
                            ),
                            items: materials.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
                            onChanged: (val) => setState(() => _selectedRawMaterialId = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _rawMaterialQtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isAr ? 'الكمية' : 'Qty',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_selectedRawMaterialId == null || _rawMaterialQtyController.text.isEmpty) return;
                            final qty = double.tryParse(_rawMaterialQtyController.text);
                            if (qty == null || qty <= 0) return;
                            
                            setState(() {
                              final existingIndex = _recipe.indexWhere((r) => r.rawMaterialId == _selectedRawMaterialId);
                              if (existingIndex >= 0) {
                                _recipe[existingIndex] = _recipe[existingIndex].copyWith(amountRequired: _recipe[existingIndex].amountRequired + qty);
                              } else {
                                _recipe.add(RecipeItem(rawMaterialId: _selectedRawMaterialId!, amountRequired: qty));
                              }
                              _selectedRawMaterialId = null;
                              _rawMaterialQtyController.clear();
                            });
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                        ),
                      ],
                    ),
                    if (_recipe.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recipe.length,
                        itemBuilder: (context, index) {
                          final recipeItem = _recipe[index];
                          final material = materials.firstWhere((m) => m.id == recipeItem.rawMaterialId, orElse: () => RawMaterial(id: '', merchantId: '', name: 'Unknown', quantity: 0, unit: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${material.name} - ${recipeItem.amountRequired} ${material.unit}', style: const TextStyle(fontFamily: 'Tajawal')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () {
                                setState(() {
                                  _recipe.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ]
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const Text('Error loading materials'),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(l10n.save, style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

