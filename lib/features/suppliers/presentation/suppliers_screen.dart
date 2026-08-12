import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/services/app_error_mapper.dart';
import '../../../core/widgets/tajer_message.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';
import 'package:flutter/cupertino.dart';
import 'supplier_details_screen.dart';
import '../data/supplier_transaction_repository.dart';
import '../domain/supplier_transaction.dart';
import '../../branches/presentation/branch_context.dart';
import '../../branches/presentation/active_branch_selector.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageInventory =
        appUser?.hasPermission('can_manage_inventory') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text122,
            style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          final activeBranchId = ref.watch(selectedBranchIdProvider);
          final activeSuppliers = suppliers.where((s) {
            // Include supplier if they are associated with the active branch,
            // or if they have debt in the active branch, or if we have no active branch.
            if (activeBranchId == null) return true;
            if (s.associatedBranchIds.contains(activeBranchId)) return true;
            if ((s.branchDebts[activeBranchId] ?? 0) > 0) return true;
            return false;
          }).toList();
          
          if (activeSuppliers.isEmpty) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ActiveBranchSelector(compact: true),
                ),
                Expanded(
                  child: Center(
                      child: Text(AppLocalizations.of(context)!.text123,
                          style: TextStyle(fontFamily: 'Tajawal'))),
                ),
              ],
            );
          }

          final totalSupplierDebts =
              activeSuppliers.fold<double>(0, (sum, s) => sum + (s.branchDebts[activeBranchId] ?? s.totalDebt));

          return Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ActiveBranchSelector(compact: true),
            ),
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
                        child: const Icon(Icons.money_off,
                            color: Colors.red, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي ديون الموردين',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontFamily: 'Tajawal'),
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
                itemCount: activeSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = activeSuppliers[index];
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.zero,
                    onTap: canManageInventory
                        ? () {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (_) => SupplierDetailsScreen(
                                        supplier: supplier)));
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.business,
                                color: Theme.of(context).colorScheme.primary,
                                size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                    fontSize: 17,
                                    decoration: !supplier.isActive
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color:
                                        !supplier.isActive ? Colors.grey : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.phone,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      supplier.phone ??
                                          AppLocalizations.of(context)!.text124,
                                      style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          color: Colors.grey[700],
                                          fontSize: 13),
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
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontFamily: 'Tajawal'),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (activeBranchId != null ? (supplier.branchDebts[activeBranchId] ?? 0.0) : supplier.totalDebt) > 0
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${activeBranchId != null ? (supplier.branchDebts[activeBranchId] ?? 0.0) : supplier.totalDebt} ${currentCurrency.code}',
                                  style: TextStyle(
                                    color: (activeBranchId != null ? (supplier.branchDebts[activeBranchId] ?? 0.0) : supplier.totalDebt) > 0
                                        ? Colors.red
                                        : Colors.green,
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
                              icon: const Icon(Icons.arrow_forward_ios,
                                  color: Colors.grey, size: 16),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                        builder: (_) => SupplierDetailsScreen(
                                            supplier: supplier)));
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
      floatingActionButton: canManageInventory
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                final canAdd =
                    await GuestLimitService.canAddSupplier(context, ref);
                if (!canAdd) return;
                if (context.mounted) _showAddSupplierDialog(context, ref);
              },
              child: Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddSupplierDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final debtController = TextEditingController();

    var isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.text126,
              style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.text127),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.text128),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.text129),
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
              onPressed: () async {
                if (isSaving) return;
                final user = ref.read(authRepositoryProvider).currentUser;
                final appUser = ref.read(appUserProvider).value;
                if (user == null || appUser == null) return;

                final supplierName = nameController.text.trim();
                if (supplierName.isEmpty) {
                  await TajerMessage.show(
                    context,
                    AppErrorMapper.validation(
                      ar: 'أدخل اسم المورد.',
                      en: 'Enter the supplier name.',
                    ),
                  );
                  return;
                }

                final rawDebt = debtController.text.trim();
                final initialDebt = rawDebt.isEmpty ? 0.0 : double.tryParse(rawDebt);
                if (initialDebt == null || !initialDebt.isFinite || initialDebt < 0) {
                  await TajerMessage.show(
                    context,
                    AppErrorMapper.validation(
                      ar: 'أدخل رصيدًا افتتاحيًا صحيحًا يساوي صفرًا أو أكبر.',
                      en: 'Enter a valid opening balance greater than or equal to zero.',
                    ),
                  );
                  return;
                }

                final activeBranchId = ref.read(selectedBranchIdProvider);
                final branchId = activeBranchId ?? 'main';
                final now = DateTime.now();
                final supplier = Supplier(
                  id: const Uuid().v4(),
                  merchantId: currentEffectiveMerchantId(appUser),
                  name: supplierName,
                  phone: phoneController.text.trim(),
                  totalDebt: initialDebt,
                  associatedBranchIds: [branchId],
                  branchDebts: {branchId: initialDebt},
                  createdAt: now,
                );
                final openingTransaction = initialDebt > 0
                    ? SupplierTransaction(
                        id: const Uuid().v4(),
                        supplierId: supplier.id,
                        merchantId: supplier.merchantId,
                        branchId: branchId,
                        amount: initialDebt,
                        type: 'debt_addition',
                        description: 'رصيد افتتاحي / دين أولي',
                        date: now,
                        createdAt: now,
                      )
                    : null;

                final repository = ref.read(supplierRepositoryProvider);
                if (repository == null) return;
                isSaving = true;
                try {
                  await repository.addSupplier(
                    supplier,
                    openingTransaction: openingTransaction,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  isSaving = false;
                  if (context.mounted) {
                    await TajerMessage.show(
                      context,
                      AppErrorMapper.fromError(e, domain: 'supplier'),
                    );
                  }
                }
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
