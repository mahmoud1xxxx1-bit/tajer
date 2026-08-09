import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../branches/presentation/branch_context.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../../../core/services/activity_logger.dart';

class AddCustomerDialog extends ConsumerStatefulWidget {
  final Customer? customerToEdit;
  const AddCustomerDialog({super.key, this.customerToEdit});

  @override
  ConsumerState<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends ConsumerState<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _debtController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerToEdit != null) {
      _nameController.text = widget.customerToEdit!.name;
      _phoneController.text = widget.customerToEdit!.phone;
      _debtController.text = widget.customerToEdit!.totalDebt.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception(AppLocalizations.of(context)!.text47);

      final customerRepo = ref.read(customerRepositoryProvider);
      final appUser = ref.read(appUserProvider).value;
      if (appUser == null)
        throw Exception(AppLocalizations.of(context)!.text47);
      final isEditing = widget.customerToEdit != null;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final branchId = ref.read(selectedBranchIdProvider);

      final newCustomer = Customer(
        id: isEditing ? widget.customerToEdit!.id : Uuid().v4(),
        merchantId: isEditing
            ? widget.customerToEdit!.merchantId
            : currentEffectiveMerchantId(appUser),
        branchId: isEditing ? widget.customerToEdit!.branchId : branchId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        createdAt:
            isEditing ? widget.customerToEdit!.createdAt : DateTime.now(),
        totalPurchases: isEditing ? widget.customerToEdit!.totalPurchases : 0.0,
        orderCount: isEditing ? widget.customerToEdit!.orderCount : 0,
        totalDebt: double.tryParse(_debtController.text.trim()) ?? 0.0,
        creatorName: isEditing
            ? widget.customerToEdit!.creatorName
            : (appUser.name ?? (isAr ? 'التاجر' : 'Owner')),
      );

      if (isEditing) {
        await customerRepo.updateCustomer(newCustomer);
        await ActivityLogger.log(
          user: appUser,
          actionType: isAr ? 'تعديل عميل' : 'Customer Updated',
          description: isAr
              ? 'تم تعديل بيانات العميل (${newCustomer.name})'
              : 'Updated customer details (${newCustomer.name})',
        );
      } else {
        await customerRepo.addCustomer(newCustomer);
        await ActivityLogger.log(
          user: appUser,
          actionType: isAr ? 'إضافة عميل' : 'Customer Added',
          description: isAr
              ? 'تم إضافة العميل الجديد (${newCustomer.name}) بواسطة (${newCustomer.creatorName})'
              : 'Added new customer (${newCustomer.name}) by (${newCustomer.creatorName})',
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('حدث خطأ: $e', style: TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customerToEdit != null;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing
                  ? AppLocalizations.of(context)!.text48
                  : AppLocalizations.of(context)!.text49,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.text50,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  value!.isEmpty ? AppLocalizations.of(context)!.text51 : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.text52,
                helperText: isAr
                    ? 'مفتاح الدولة الافتراضي هو السعودية (+966). للعملاء من دول أخرى الرجاء كتابة مفتاح الدولة.'
                    : 'Default country code is SA (+966). For other countries, include the country code.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value!.isEmpty ? AppLocalizations.of(context)!.text51 : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _debtController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isAr
                    ? 'الرصيد الافتتاحي (ديون سابقة)'
                    : 'Opening Balance (Previous Debts)',
                border: const OutlineInputBorder(),
                labelStyle: const TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      isEditing
                          ? AppLocalizations.of(context)!.text53
                          : AppLocalizations.of(context)!.text54,
                      style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
