import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerToEdit != null) {
      _nameController.text = widget.customerToEdit!.name;
      _phoneController.text = widget.customerToEdit!.phone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('المستخدم غير مسجل');

      final customerRepo = ref.read(customerRepositoryProvider);

      final isEditing = widget.customerToEdit != null;
      final newCustomer = Customer(
        id: isEditing ? widget.customerToEdit!.id : const Uuid().v4(),
        merchantId: isEditing ? widget.customerToEdit!.merchantId : user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        createdAt: isEditing ? widget.customerToEdit!.createdAt : DateTime.now(),
        totalPurchases: isEditing ? widget.customerToEdit!.totalPurchases : 0.0,
        orderCount: isEditing ? widget.customerToEdit!.orderCount : 0,
        updatedAt: isEditing ? DateTime.now() : null,
      );

      if (isEditing) {
        await customerRepo.updateCustomer(newCustomer);
      } else {
        await customerRepo.addCustomer(newCustomer);
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
    final isEditing = widget.customerToEdit != null;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم العميل',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(isEditing ? 'حفظ التعديلات' : 'إضافة العميل', style: const TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
