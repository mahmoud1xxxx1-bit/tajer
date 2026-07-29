import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/guest_limit_service.dart';
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
        title: Text(AppLocalizations.of(context)!.text_122, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text_123, style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                onTap: () {
                  _showEditSupplierDialog(context, ref, supplier);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.business, color: Theme.of(context).colorScheme.primary, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  supplier.phone ?? AppLocalizations.of(context)!.text_124,
                                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.text_125,
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Tajawal'),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: supplier.totalDebt > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${supplier.totalDebt} ${currentCurrency.code}',
                              style: TextStyle(
                                color: supplier.totalDebt > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddSupplier(context, ref);
          if (!canAdd) return;
          if (context.mounted) _showAddSupplierDialog(context, ref);
        },
        child: Icon(Icons.add),
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
          title: Text(AppLocalizations.of(context)!.text_126, style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_127),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_128),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_129),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text_43),
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
              child: Text(AppLocalizations.of(context)!.text_44),
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
          title: Text(AppLocalizations.of(context)!.text_130, style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_127),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_128),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_131),
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
              child: Text(AppLocalizations.of(context)!.text_59, style: TextStyle(color: Colors.red)),
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
              child: Text(AppLocalizations.of(context)!.text_46),
            ),
          ],
        );
      },
    );
  }
}

