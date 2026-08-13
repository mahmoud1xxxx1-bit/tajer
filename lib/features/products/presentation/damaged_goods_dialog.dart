import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/product.dart';
import '../data/product_repository.dart';
import '../../inventory_log/data/inventory_log_repository.dart';
import '../../inventory_log/domain/inventory_log.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/services/activity_logger.dart';

class DamagedGoodsDialog extends ConsumerStatefulWidget {
  final Product product;
  const DamagedGoodsDialog({super.key, required this.product});

  @override
  ConsumerState<DamagedGoodsDialog> createState() => _DamagedGoodsDialogState();
}

class _DamagedGoodsDialogState extends ConsumerState<DamagedGoodsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String _type = 'damaged'; // 'damaged' or 'vendor_return'

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final appUser = ref.read(appUserProvider).value;
    if (appUser == null) return;

    setState(() => _isLoading = true);

    try {
      final qtyToDeduct = double.parse(_qtyController.text);
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      
      // 1. Update Product Inventory
      final newQuantity = widget.product.quantity - qtyToDeduct;
      final updatedProduct = widget.product.copyWith(quantity: newQuantity);
      await ref.read(productRepositoryProvider).updateProduct(updatedProduct);

      // 2. Create Inventory Log
      final logTypeLabel = _type == 'damaged' 
          ? (isAr ? 'إعدام تالف' : 'Damaged Goods')
          : (isAr ? 'مرتجع لمورد' : 'Vendor Return');
          
      final logReason = '$logTypeLabel: ${_notesController.text.trim()}';
      
      final invLog = InventoryLog(
        id: const Uuid().v4(),
        merchantId: appUser.merchantId ?? appUser.id,
        productId: widget.product.id,
        productName: widget.product.name,
        changeQuantity: -qtyToDeduct,
        previousQuantity: widget.product.quantity,
        newQuantity: newQuantity,
        reason: logReason,
        userEmail: appUser.email,
        userName: appUser.name,
        itemType: 'product',
        date: DateTime.now(),
      );
      
      await ref.read(inventoryLogRepositoryProvider)?.addLog(invLog);

      // 3. Create Expense for Damaged Goods (Financial Loss)
      if (_type == 'damaged') {
        final totalCostLoss = (widget.product.costPrice ?? 0.0) * qtyToDeduct;
        
        if (totalCostLoss > 0) {
          final expense = Expense(
            id: const Uuid().v4(),
            merchantId: appUser.merchantId ?? appUser.id,
            title: isAr 
                ? 'خسائر توالف: ${widget.product.name} ($qtyToDeduct)'
                : 'Damaged Loss: ${widget.product.name} ($qtyToDeduct)',
            amount: totalCostLoss,
            category: isAr ? 'خسائر توالف' : 'Damaged Goods Loss',
            notes: _notesController.text.trim(),
            creatorId: appUser.id,
            creatorName: appUser.name ?? appUser.email,
            date: DateTime.now(),
            createdAt: DateTime.now(),
            isFromShiftDrawer: false, // CRITICAL: Does not deduct from cash drawer
            paymentMethod: 'other',
            isSupplierPayment: false,
          );
          
          await ref.read(expenseRepositoryProvider)?.addExpense(expense);
        }
      }

      // 4. Activity Log
      await ActivityLogger.log(
        user: appUser,
        actionType: isAr ? 'إدارة التوالف والمرتجعات' : 'Damaged Goods & Returns',
        description: isAr 
            ? 'تم خصم $qtyToDeduct من ${widget.product.name} كـ ($logTypeLabel)'
            : 'Deducted $qtyToDeduct of ${widget.product.name} as ($logTypeLabel)',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr ? 'تم تطبيق العملية بنجاح' : 'Operation completed successfully',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_shopping_cart, color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'إدارة التوالف والمرتجعات' : 'Damaged & Returns',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.product.name,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: theme.colorScheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Type Selection
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'damaged',
                  label: Text(isAr ? 'إعدام تالف' : 'Damaged', style: const TextStyle(fontFamily: 'Tajawal')),
                  icon: const Icon(Icons.delete_sweep),
                ),
                ButtonSegment(
                  value: 'vendor_return',
                  label: Text(isAr ? 'إرجاع لمورد' : 'Vendor Return', style: const TextStyle(fontFamily: 'Tajawal')),
                  icon: const Icon(Icons.local_shipping),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _type = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            
            if (_type == 'damaged')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isAr 
                          ? 'سيتم تسجيل تكلفة هذا المنتج (${widget.product.costPrice ?? 0}) كخسائر تشغيلية في التقارير.'
                          : 'The cost (${widget.product.costPrice ?? 0}) will be logged as an operational loss in reports.',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 16),
            
            // Quantity
            TextFormField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: InputDecoration(
                labelText: isAr ? 'الكمية' : 'Quantity',
                hintText: isAr ? 'المخزون الحالي: ${widget.product.quantity}' : 'Current: ${widget.product.quantity}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return isAr ? 'مطلوب' : 'Required';
                final qty = double.tryParse(value);
                if (qty == null || qty <= 0) return isAr ? 'كمية غير صالحة' : 'Invalid quantity';
                if (qty > widget.product.quantity) return isAr ? 'الكمية تتجاوز المخزون' : 'Exceeds current stock';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: isAr ? 'السبب / الملاحظات' : 'Reason / Notes',
                hintText: isAr ? 'مثال: انكسر بالخطأ، منتهي الصلاحية...' : 'e.g., Broken by mistake, expired...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.notes),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return isAr ? 'مطلوب' : 'Required';
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'damaged' ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isAr ? 'تأكيد العملية' : 'Confirm Action',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
