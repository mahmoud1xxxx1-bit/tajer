import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../authentication/application/session_identity.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../products/data/raw_material_repository.dart';
import '../../products/domain/raw_material.dart';
import '../../shifts/data/shift_repository.dart';
import '../data/purchase_invoice_repository.dart';
import '../domain/purchase_invoice.dart';
import '../domain/supplier.dart';

class PurchaseInvoiceScreen extends ConsumerStatefulWidget {
  final Supplier supplier;

  const PurchaseInvoiceScreen({super.key, required this.supplier});

  @override
  ConsumerState<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends ConsumerState<PurchaseInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _amountPaidController = TextEditingController();
  
  String _paymentMethod = 'cash';
  bool _isFromShiftDrawer = true;
  DateTime _purchaseDate = DateTime.now();
  
  final List<_InvoiceLine> _lines = [];

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountPaidController.dispose();
    for (var line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() {
      _lines.add(_InvoiceLine());
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  double get _totalAmount {
    return _lines.fold(0.0, (sum, line) => sum + line.totalCost);
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'يجب إضافة صنف واحد على الأقل'
                : 'At least one item must be added',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;
    if (amountPaid > _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي'
                : 'Paid amount cannot exceed total',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final merchantId = ref.read(sessionIdentityProvider)?.effectiveMerchantId;
    if (merchantId == null) return;

    final branchId = ref.read(selectedBranchIdProvider);
    
    final needsShift = _paymentMethod == 'cash' && _isFromShiftDrawer && amountPaid > 0;
    String? shiftId;
    if (needsShift) {
      final currentShift = ref.read(currentShiftProvider(merchantId)).value;
      if (currentShift == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'لا يوجد وردية مفتوحة حالياً'
                  : 'No active shift found',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      shiftId = currentShift.id;
    }

    final appUser = ref.read(appUserProvider).value;
    if (appUser != null) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final confirmed = await PinConfirmationDialog.requirePinOrSetup(
        context,
        appUser,
        title: isAr ? 'تأكيد فاتورة الشراء' : 'Confirm Purchase Invoice',
        warning: isAr
            ? 'هل أنت متأكد من حفظ هذه الفاتورة؟'
            : 'Are you sure you want to save this invoice?',
      );
      if (!confirmed) return;
    }

    try {
      final invoiceItems = _lines.map((line) => PurchaseInvoiceItem(
        itemId: line.selectedItemId!,
        itemName: line.selectedItemName!,
        itemType: line.itemType,
        quantity: double.tryParse(line.quantityController.text) ?? 0.0,
        unitCost: double.tryParse(line.unitCostController.text) ?? 0.0,
        totalCost: line.totalCost,
      )).toList();

      await ref.read(purchaseInvoiceRepositoryProvider).createPurchaseInvoice(
        branchId: branchId,
        supplierId: widget.supplier.id,
        supplierName: widget.supplier.name,
        invoiceNumber: _invoiceNumberController.text.trim(),
        items: invoiceItems,
        totalAmount: _totalAmount,
        amountPaid: amountPaid,
        paymentMethod: _paymentMethod,
        isFromShiftDrawer: _isFromShiftDrawer,
        occurredAt: _purchaseDate,
        shiftId: shiftId,
        creatorId: appUser?.id,
        creatorName: appUser?.name,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم حفظ الفاتورة بنجاح'
                  : 'Invoice saved successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currency = ref.watch(currencyProvider);
    final products = ref.watch(productsStreamProvider).value ?? [];
    final merchantId = ref.watch(sessionIdentityProvider)?.effectiveMerchantId;
    final rawMaterials = merchantId != null 
        ? (ref.watch(rawMaterialsStreamProvider(merchantId)).value ?? [])
        : <RawMaterial>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'فاتورة شراء' : 'Purchase Invoice',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _submit(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isAr ? 'المورد' : 'Supplier'}: ${widget.supplier.name}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _invoiceNumberController,
                      decoration: InputDecoration(
                        labelText: isAr ? 'رقم الفاتورة (اختياري)' : 'Invoice Number (Optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(isAr ? 'تاريخ الشراء' : 'Purchase Date'),
                      subtitle: Text('${_purchaseDate.year}-${_purchaseDate.month.toString().padLeft(2, '0')}-${_purchaseDate.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _purchaseDate = date);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAr ? 'الأصناف' : 'Items',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._lines.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${isAr ? 'صنف' : 'Item'} #${index + 1}'),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeLine(index),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: line.itemType,
                        decoration: InputDecoration(
                          labelText: isAr ? 'نوع الصنف' : 'Item Type',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'product',
                            child: Text(isAr ? 'منتج' : 'Product'),
                          ),
                          DropdownMenuItem(
                            value: 'raw_material',
                            child: Text(isAr ? 'مادة خام' : 'Raw Material'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              line.itemType = val;
                              line.selectedItemId = null;
                              line.selectedItemName = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: line.selectedItemId,
                        decoration: InputDecoration(
                          labelText: isAr ? 'الصنف' : 'Item',
                        ),
                        validator: (val) => val == null
                            ? (isAr ? 'مطلوب' : 'Required')
                            : null,
                        items: line.itemType == 'product'
                            ? products.map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                )).toList()
                            : rawMaterials.map((r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              line.selectedItemId = val;
                              if (line.itemType == 'product') {
                                line.selectedItemName = products.firstWhere((p) => p.id == val).name;
                              } else {
                                line.selectedItemName = rawMaterials.firstWhere((r) => r.id == val).name;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: line.quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isAr ? 'الكمية' : 'Quantity',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.isEmpty) return isAr ? 'مطلوب' : 'Required';
                                if (double.tryParse(val) == null || double.parse(val) <= 0) return isAr ? 'رقم غير صحيح' : 'Invalid number';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: line.unitCostController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isAr ? 'التكلفة' : 'Cost',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.isEmpty) return isAr ? 'مطلوب' : 'Required';
                                if (double.tryParse(val) == null || double.parse(val) < 0) return isAr ? 'رقم غير صحيح' : 'Invalid number';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          '${isAr ? 'الإجمالي' : 'Total'}: ${line.totalCost.toStringAsFixed(2)} ${currency.code}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            ElevatedButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: Text(isAr ? 'إضافة صنف' : 'Add Item'),
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isAr ? 'إجمالي الفاتورة' : 'Invoice Total'}: ${_totalAmount.toStringAsFixed(2)} ${currency.code}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountPaidController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'المبلغ المدفوع' : 'Amount Paid',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: InputDecoration(
                        labelText: isAr ? 'طريقة الدفع' : 'Payment Method',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text(isAr ? 'كاش' : 'Cash'),
                        ),
                        DropdownMenuItem(
                          value: 'network',
                          child: Text(isAr ? 'شبكة/حوالة' : 'Network/Transfer'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _paymentMethod = val);
                        }
                      },
                    ),
                    if (_paymentMethod == 'cash') ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(isAr ? 'من درج الوردية؟' : 'From Shift Drawer?'),
                        value: _isFromShiftDrawer,
                        onChanged: (val) => setState(() => _isFromShiftDrawer = val),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final paid = double.tryParse(_amountPaidController.text) ?? 0.0;
                        final debt = _totalAmount - paid;
                        return Text(
                          '${isAr ? 'المتبقي كدين' : 'Remaining Debt'}: ${debt > 0 ? debt.toStringAsFixed(2) : "0.00"} ${currency.code}',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _InvoiceLine {
  String itemType = 'product';
  String? selectedItemId;
  String? selectedItemName;
  final quantityController = TextEditingController();
  final unitCostController = TextEditingController();

  double get quantity => double.tryParse(quantityController.text) ?? 0.0;
  double get unitCost => double.tryParse(unitCostController.text) ?? 0.0;
  double get totalCost => quantity * unitCost;

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
  }
}
