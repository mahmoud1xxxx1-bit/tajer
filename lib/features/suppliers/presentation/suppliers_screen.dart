import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموردين', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(child: Text('لا يوجد موردين حالياً', style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: Icon(Icons.business, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                  subtitle: Text(supplier.phone ?? 'لا يوجد رقم هاتف', style: const TextStyle(fontFamily: 'Tajawal')),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('الديون المستحقة', style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Tajawal')),
                      Text(
                        '${supplier.totalDebt} ${currentCurrency.code}',
                        style: TextStyle(
                          color: supplier.totalDebt > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Show edit/pay dialog
                    _showEditSupplierDialog(context, ref, supplier);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplierDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final debtController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة مورد جديد', style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم المورد'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الجوال'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي (الديون)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null) return;
                
                if (nameController.text.isEmpty) return;

                final supplier = Supplier(
                  id: const Uuid().v4(),
                  merchantId: user.uid,
                  name: nameController.text,
                  phone: phoneController.text,
                  totalDebt: double.tryParse(debtController.text) ?? 0.0,
                  createdAt: DateTime.now(),
                );

                ref.read(supplierRepositoryProvider)?.addSupplier(supplier);
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showEditSupplierDialog(BuildContext context, WidgetRef ref, Supplier supplier) {
    final nameController = TextEditingController(text: supplier.name);
    final phoneController = TextEditingController(text: supplier.phone);
    final debtController = TextEditingController(text: supplier.totalDebt.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل المورد', style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم المورد'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الجوال'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'تحديث الديون'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(supplierRepositoryProvider)?.deleteSupplier(supplier.id);
                Navigator.pop(context);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;

                final updatedSupplier = supplier.copyWith(
                  name: nameController.text,
                  phone: phoneController.text,
                  totalDebt: double.tryParse(debtController.text) ?? 0.0,
                );

                ref.read(supplierRepositoryProvider)?.updateSupplier(updatedSupplier);
                Navigator.pop(context);
              },
              child: const Text('تحديث'),
            ),
          ],
        );
      },
    );
  }
}
