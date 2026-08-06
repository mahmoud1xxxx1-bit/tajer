import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../../core/services/activity_logger.dart';
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
  final _taxPercentageController = TextEditingController();
  final _costPriceController = TextEditingController();
  bool _isManufacturedOnDemand = false;
  bool? _isTaxInclusive;
  String? _selectedCategoryId;
  String? _selectedRawMaterialId;
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
      _taxPercentageController.text = widget.productToEdit!.taxPercentage?.toString() ?? '';
      _costPriceController.text = widget.productToEdit!.costPrice?.toString() ?? '';
      _isManufacturedOnDemand = widget.productToEdit!.isManufacturedOnDemand;
      _isTaxInclusive = widget.productToEdit!.isTaxInclusive;
      _selectedCategoryId = widget.productToEdit!.categoryId;
      if (widget.productToEdit!.recipe.isNotEmpty) {
        _selectedRawMaterialId = widget.productToEdit!.recipe.first.rawMaterialId;
        _rawMaterialQtyController.text = widget.productToEdit!.recipe.first.amountRequired.toString();
      }
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
    _taxPercentageController.dispose();
    _costPriceController.dispose();
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
    final l10n = AppLocalizations.of(context)!;
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

      List<RecipeItem> updatedRecipe = [];
      if (_selectedRawMaterialId != null && _rawMaterialQtyController.text.isNotEmpty) {
        final qty = double.tryParse(_rawMaterialQtyController.text) ?? 0.0;
        if (qty > 0) {
          updatedRecipe.add(RecipeItem(rawMaterialId: _selectedRawMaterialId!, amountRequired: qty));
        }
      }
      
      final merchantId = isEditing ? widget.productToEdit!.merchantId : (appUser?.merchantId ?? user.uid);
      
      final newProduct = Product(
        id: isEditing ? widget.productToEdit!.id : const Uuid().v4(),
        merchantId: merchantId,
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text),
        quantity: newQuantity,
        categoryId: _selectedCategoryId,
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        modifiers: _modifiersController.text.trim().isEmpty ? [] : _modifiersController.text.split('،').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        recipe: updatedRecipe,
        isTaxInclusive: _isTaxInclusive,
        taxPercentage: _taxPercentageController.text.trim().isEmpty ? null : double.tryParse(_taxPercentageController.text.trim()),
        isManufacturedOnDemand: _isManufacturedOnDemand,
        costPrice: _costPriceController.text.trim().isEmpty ? null : double.tryParse(_costPriceController.text.trim()),
        createdAt: isEditing ? widget.productToEdit!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await productRepo.updateProduct(newProduct);
        ActivityLogger.log(
          user: appUser,
          actionType: 'Edit Product|تعديل منتج',
          description: 'Updated product "${newProduct.name}"|تم تعديل بيانات المنتج "${newProduct.name}"',
        );
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
        ActivityLogger.log(
          user: appUser,
          actionType: 'Add Product|إضافة منتج',
          description: 'Added new product "${newProduct.name}"|تم إضافة منتج جديد "${newProduct.name}"',
        );
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
        child: SingleChildScrollView(
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
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isAr ? 'التكلفة (اختياري)' : 'Cost Price (Optional)',
                      border: const OutlineInputBorder(),
                    ),
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
            SwitchListTile(
              title: Text(isAr ? 'يُصنع عند الطلب (لا يُخصم من المخزون كمنتج نهائي)' : 'Made to order (Do not deduct product quantity)'),
              value: _isManufacturedOnDemand,
              onChanged: (value) => setState(() => _isManufacturedOnDemand = value),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _modifiersController,
              decoration: InputDecoration(
                labelText: isAr ? 'أزرار سريعة (اختياري)' : 'Fast Buttons (Optional)',
                hintText: isAr ? 'مثال: بدون بصل، سفري، حار' : 'e.g. No onion, Spicy, To-go',
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent.withOpacity(0.5) : Colors.orange.shade200),
              ),
              child: ExpansionTile(
                title: Text(
                  isAr ? 'إعدادات متقدمة للضريبة (اختياري)' : 'Advanced Tax Settings (Optional)',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800),
                ),
                iconColor: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800,
                collapsedIconColor: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800,
                childrenPadding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    isAr 
                      ? 'تحديد الإعدادات هنا سيلغي إعدادات المتجر العامة لهذا المنتج، وسيؤثر مباشرة على الحساب النهائي.' 
                      : 'Setting these will override the global store tax settings for this product.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange.shade900),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxPercentageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Tajawal'),
                    decoration: InputDecoration(
                      labelText: isAr ? 'نسبة الضريبة الخاصة بالمنتج (%)' : 'Product Tax Percentage (%)',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent.withOpacity(0.5) : Colors.orange.shade300),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(isAr ? 'السعر المحدد يشمل الضريبة' : 'Price is Tax Inclusive', style: const TextStyle(fontFamily: 'Tajawal')),
                    value: _isTaxInclusive ?? false,
                    onChanged: (val) => setState(() => _isTaxInclusive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(isAr ? 'المقادير (المواد الخام) - اختياري' : 'Recipe (Raw Material) - Optional', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', color: Colors.blueGrey)),
            const SizedBox(height: 8),
            rawMaterialsAsync.when(
              data: (materials) {
                if (materials.isEmpty) {
                  return Text(isAr ? 'لا توجد مواد خام مضافة' : 'No raw materials added', style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal'));
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRawMaterialId,
                        decoration: InputDecoration(
                          labelText: isAr ? 'اختر المادة الخام' : 'Select Raw Material',
                          border: const OutlineInputBorder(),
                        ),
                        items: materials.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
                        onChanged: (val) => setState(() => _selectedRawMaterialId = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _rawMaterialQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isAr ? 'الكمية المخصومة لكل 1 طلب' : 'Qty Deducted per Order',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
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
      ),
    );
  }
}

