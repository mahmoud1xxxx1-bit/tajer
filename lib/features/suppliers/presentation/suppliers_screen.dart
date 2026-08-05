import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';
import 'package:flutter/cupertino.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import 'supplier_details_screen.dart';
import '../data/supplier_transaction_repository.dart';
import '../domain/supplier_transaction.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageInventory = appUser?.hasPermission('can_manage_inventory') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text122, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text123, style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          final totalSupplierDebts = suppliers.fold<double>(0, (sum, s) => sum + s.totalDebt);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.money_off, color: Colors.red, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إجمالي ديون الموردين',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700], fontFamily: 'Tajawal'),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalSupplierDebts ${currentCurrency.code}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                onTap: canManageInventory ? () {
                  Navigator.push(context, CupertinoPageRoute(builder: (_) => SupplierDetailsScreen(supplier: supplier)));
                } : null,
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
                                  supplier.phone ?? AppLocalizations.of(context)!.text124,
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
                            AppLocalizations.of(context)!.text125,
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
                      if (canManageInventory) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                          onPressed: () {
                             Navigator.push(context, CupertinoPageRoute(builder: (_) => SupplierDetailsScreen(supplier: supplier)));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]);
    },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: canManageInventory ? FloatingActionButton(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddSupplier(context, ref);
          if (!canAdd) return;
          if (context.mounted) _showAddSupplierDialog(context, ref);
        },
        child: Icon(Icons.add),
      ) : null,
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
          title: Text(AppLocalizations.of(context)!.text126, style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text127),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text128),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text129),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text43),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null) return;
                
                if (nameController.text.isEmpty) return;

                final initialDebt = double.tryParse(debtController.text) ?? 0.0;
                final supplier = Supplier(
                  id: Uuid().v4(),
                  merchantId: ref.read(appUserProvider).value?.merchantId ?? user.uid,
                  name: nameController.text,
                  phone: phoneController.text,
                  totalDebt: initialDebt,
                  createdAt: DateTime.now(),
                );

                ref.read(supplierRepositoryProvider)?.addSupplier(supplier);
                
                if (initialDebt > 0) {
                  final tx = SupplierTransaction(
                    id: const Uuid().v4(),
                    supplierId: supplier.id,
                    merchantId: supplier.merchantId,
                    amount: initialDebt,
                    type: 'debt_addition',
                    description: 'رصيد افتتاحي / دين أولي',
                    date: DateTime.now(),
                    createdAt: DateTime.now(),
                  );
                  ref.read(supplierTransactionRepositoryProvider)?.addTransaction(tx);
                }
                
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text44),
            ),
          ],
        );
      },
    );
  }

  // Removed old _showEditSupplierDialog and _showPaySupplierDebtDialog as they are now in SupplierDetailsScreen
}

