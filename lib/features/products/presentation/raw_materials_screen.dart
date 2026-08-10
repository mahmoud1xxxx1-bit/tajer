import 'package:flutter/material.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/raw_material.dart';
import '../data/raw_material_repository.dart';
import '../../inventory_log/data/inventory_log_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/services/app_error_mapper.dart';
import '../../../core/widgets/tajer_message.dart';

import '../../../../../../../../core/theme/glass_card.dart';

class RawMaterialsScreen extends ConsumerStatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  ConsumerState<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends ConsumerState<RawMaterialsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  void _showAddEditDialog([RawMaterial? rawMaterial]) {
    final nameController = TextEditingController(text: rawMaterial?.name ?? '');
    final quantityController =
        TextEditingController(text: rawMaterial?.quantity.toString() ?? '');
    final lowStockThresholdController = TextEditingController(text: rawMaterial?.lowStockThreshold?.toString() ?? '0');
    String selectedUnit = rawMaterial?.unit ?? 'g';
    final capturedBranchId = ref.read(selectedBranchIdProvider);
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(rawMaterial == null ? Icons.add_circle : Icons.edit,
                  color: Colors.amber),
              const SizedBox(width: 10),
              Text(
                  rawMaterial == null
                      ? l10n.addNewRawMaterial
                      : (isAr ? 'تعديل مادة خام' : 'Edit Raw Material'),
                  style: const TextStyle(
                      fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.rawMaterialsUsageHint,
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.amber),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isAr
                          ? 'اسم المادة الخام (مثال: لحم برجر، جبن، قهوة بن)'
                          : 'Raw Material Name (e.g., burger meat, cheese, coffee)',
                      labelStyle:
                          const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: isAr
                          ? 'الكمية المتوفرة حالياً في المستودع'
                          : 'Quantity available currently in warehouse',
                      labelStyle:
                          const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: lowStockThresholdController,
                    decoration: InputDecoration(
                      labelText: isAr
                          ? 'الحد الأدنى لتنبيه انخفاض المخزون'
                          : 'Low stock threshold for alerts',
                      labelStyle:
                          const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                      prefixIcon: const Icon(Icons.warning_amber),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.measuringUnit,
                      style: TextStyle(
                          fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.scale),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'g',
                          child: Text(l10n.gUnitDesc,
                              style: TextStyle(
                                  fontFamily: 'Tajawal', fontSize: 13))),
                      DropdownMenuItem(
                          value: 'ml',
                          child: Text(l10n.mlUnitDesc,
                              style: TextStyle(
                                  fontFamily: 'Tajawal', fontSize: 13))),
                      DropdownMenuItem(
                          value: 'piece',
                          child: Text(l10n.pieceUnitDesc,
                              style: TextStyle(
                                  fontFamily: 'Tajawal', fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedUnit = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: Text(l10n.saveInWarehouse,
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final qty = double.tryParse(quantityController.text) ?? 0;
                final threshold = double.tryParse(lowStockThresholdController.text) ?? 0;

                if (name.isEmpty) {
                  await TajerMessage.show(
                    context,
                    AppErrorMapper.validation(
                      ar: l10n.pleaseEnterRawMaterialName,
                      en: l10n.pleaseEnterRawMaterialName,
                    ),
                  );
                  return;
                }

                final user = ref.read(appUserProvider).value;
                final merchantId =
                    user == null ? null : currentEffectiveMerchantId(user);

                if (merchantId == null) return;

                final repo = ref.read(rawMaterialRepositoryProvider);
                final operationContext = BranchOperationContext(
                  merchantId: merchantId,
                  branchId: capturedBranchId,
                );

                if (rawMaterial == null) {
                  final newItem = RawMaterial(
                    id: const Uuid().v4(),
                    merchantId: merchantId,
                    name: name,
                    quantity: qty,
                    initialQuantity: qty,
                    lowStockThreshold: threshold,
                    unit: selectedUnit,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await repo.addRawMaterial(
                    newItem,
                    context: operationContext,
                    enabledBranchIds: {operationContext.branchId},
                  );
                  if (qty > 0) {
                    final logRepo = ref.read(inventoryLogRepositoryProvider);
                    await logRepo?.logChange(
                      productId: newItem.id,
                      productName: newItem.name,
                      previousQuantity: 0,
                      newQuantity: qty,
                      reason: 'إضافة خام جديد / Add New Raw Material',
                      branchId: operationContext.branchId,
                      userEmail: user?.email,
                      userName: user?.name,
                      itemType: 'raw_material',
                    );
                  }
                } else {
                  final updatedItem = rawMaterial.copyWith(
                    name: name,
                    quantity: qty,
                    lowStockThreshold: threshold,
                    unit: selectedUnit,
                    updatedAt: DateTime.now(),
                  );
                  await repo.updateRawMaterial(
                    updatedItem,
                    context: operationContext,
                  );
                  if (qty != rawMaterial.quantity) {
                    final logRepo = ref.read(inventoryLogRepositoryProvider);
                    await logRepo?.logChange(
                      productId: updatedItem.id,
                      productName: updatedItem.name,
                      previousQuantity: rawMaterial.quantity,
                      newQuantity: qty,
                      reason: 'تحديث يدوي / Manual Update',
                      branchId: operationContext.branchId,
                      userEmail: user?.email,
                      userName: user?.name,
                      itemType: 'raw_material',
                    );
                  }
                }
                if (mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(appUserProvider).value;
    final merchantId = user == null ? null : currentEffectiveMerchantId(user);
    final canManageInventory =
        user?.hasPermission('can_manage_inventory') ?? false;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (merchantId == null) return const Scaffold();

    final materialsAsync = ref.watch(rawMaterialsStreamProvider(merchantId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rawMaterialsWarehouse,
            style:
                TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: canManageInventory
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: Text(l10n.addRawMaterial,
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            )
          : null,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.rawMaterialsGuide,
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: materialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (materials) {
                if (materials.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(l10n.noRawMaterialsFound,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 16,
                                color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: materials.length,
                  itemBuilder: (ctx, index) {
                    final item = materials[index];
                    String unitLabel = item.unit == 'g'
                        ? l10n.gLabel
                        : item.unit == 'ml'
                            ? l10n.mlLabel
                            : l10n.pieceUnit;
                    bool isLowStock = item.initialQuantity > 0 &&
                        item.quantity <= (item.initialQuantity * 0.10);
                    return GlassCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock
                              ? Colors.red.withOpacity(0.2)
                              : Colors.amber.withOpacity(0.2),
                          child: Icon(
                              isLowStock
                                  ? Icons.warning_amber_rounded
                                  : Icons.inventory,
                              color: isLowStock ? Colors.red : Colors.amber),
                        ),
                        title: Text(item.name,
                            style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                l10n.availableBalance(
                                    item.quantity.toString(), unitLabel),
                                style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: isLowStock
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            if (isLowStock)
                              Text(l10n.resourceRunningOut,
                                  style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: canManageInventory
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _showAddEditDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final appUser =
                                          ref.read(appUserProvider).value;
                                      if (appUser != null) {
                                        final success =
                                            await PinConfirmationDialog
                                                .requirePinOrSetup(
                                          context,
                                          appUser,
                                          title: isAr
                                              ? 'تحذير: حذف مادة خام'
                                              : 'Warning: Delete Raw Material',
                                          warning: isAr
                                              ? 'هل أنت متأكد من حذف هذه المادة الخام (${item.name})؟'
                                              : 'Are you sure you want to delete this raw material (${item.name})?',
                                        );
                                        if (!success) return;
                                      }
                                      ref
                                          .read(rawMaterialRepositoryProvider)
                                          .deleteRawMaterial(
                                            context: BranchOperationContext(
                                              merchantId: merchantId,
                                              branchId: ref.read(
                                                  selectedBranchIdProvider),
                                            ),
                                            id: item.id,
                                          );
                                    },
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
