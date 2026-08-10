import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/raw_material_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/raw_material.dart';
import '../data/branch_inventory_repository.dart';
import '../data/branch_repository.dart';
import 'branch_context.dart';
import '../domain/branch.dart';
import '../domain/branch_inventory.dart';

final _transferProductsProvider = StreamProvider<List<Product>>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return Stream.value(const <Product>[]);
  final merchantId = currentEffectiveMerchantId(user);
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return Stream.value(const <Product>[]);
  final repo = ref.watch(productRepositoryProvider);
  return repo.queryProducts(merchantId, branchId).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
      );
});

final _transferRawMaterialsProvider = StreamProvider<List<RawMaterial>>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return Stream.value(const <RawMaterial>[]);
  final merchantId = currentEffectiveMerchantId(user);
  final branchId = ref.watch(selectedBranchIdProvider);
  if (branchId.isEmpty) return Stream.value(const <RawMaterial>[]);
  return ref
      .watch(rawMaterialRepositoryProvider)
      .watchRawMaterials(merchantId, branchId);
});

class InventoryTransferScreen extends ConsumerStatefulWidget {
  const InventoryTransferScreen({super.key});

  @override
  ConsumerState<InventoryTransferScreen> createState() =>
      _InventoryTransferScreenState();
}

class _InventoryTransferScreenState
    extends ConsumerState<InventoryTransferScreen> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromBranchId;
  String? _toBranchId;
  String _itemType = 'product';
  String? _itemId;
  bool _submitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  String _branchName(List<Branch> branches, String id) {
    for (final branch in branches) {
      if (branch.id == id) return branch.name;
    }
    return id;
  }

  double _inventoryQuantity(
    List<BranchInventory> inventory,
    String itemId,
    String itemType,
    double legacyMainQuantity,
    String branchId,
  ) {
    for (final item in inventory) {
      if (item.itemId == itemId && item.itemType == itemType) {
        return item.quantity;
      }
    }
    return branchId == BranchIds.main ? legacyMainQuantity : 0.0;
  }

  Future<void> _submit({
    required List<Branch> branches,
    required String itemName,
    required double sourceAvailable,
    required double sourceLegacyQuantity,
    required double destinationLegacyQuantity,
  }) async {
    final from = _fromBranchId;
    final to = _toBranchId;
    final itemId = _itemId;
    final quantity = double.tryParse(_quantityController.text.trim());

    String? error;
    if (from == null || to == null) {
      error = _isAr
          ? 'اختر فرع المصدر وفرع الوجهة.'
          : 'Select source and destination branches.';
    } else if (from == to) {
      error = _isAr
          ? 'يجب أن يكون فرع الوجهة مختلفاً عن فرع المصدر.'
          : 'Destination branch must be different from source branch.';
    } else if (itemId == null) {
      error = _isAr
          ? 'اختر المنتج أو المادة الخام.'
          : 'Select a product or raw material.';
    } else if (quantity == null || quantity <= 0) {
      error = _isAr
          ? 'أدخل كمية صحيحة أكبر من صفر.'
          : 'Enter a valid quantity greater than zero.';
    } else if (quantity > sourceAvailable + 0.000001) {
      error = _isAr
          ? 'الكمية المطلوبة أكبر من الرصيد المتاح في فرع المصدر.'
          : 'Requested quantity exceeds available source stock.';
    }

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final fromName = _branchName(branches, from!);
    final toName = _branchName(branches, to!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isAr ? 'تأكيد تحويل المخزون' : 'Confirm Stock Transfer'),
        content: Text(
          _isAr
              ? 'سيتم تحويل ${quantity!.toStringAsFixed(2)} من "$itemName" من "$fromName" إلى "$toName".\n\nهذه العملية ستُسجل في سجل التحويلات وسجل المخزون.'
              : 'Transfer ${quantity!.toStringAsFixed(2)} of "$itemName" from "$fromName" to "$toName".\n\nThis action will be recorded in transfer and inventory history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(_isAr ? 'تأكيد التحويل' : 'Confirm Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(branchInventoryRepositoryProvider);
      final user = ref.read(appUserProvider).value;
      if (repo == null || user == null)
        throw StateError('Inventory repository unavailable');
      await repo.transferQuantity(
        fromBranchId: from,
        toBranchId: to,
        itemType: _itemType,
        itemId: itemId!,
        itemName: itemName,
        quantity: quantity!,
        legacySourceMainQuantity: sourceLegacyQuantity,
        legacyDestinationMainQuantity: destinationLegacyQuantity,
        userEmail: user.email,
        userName: user.name ?? user.email,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      _quantityController.clear();
      _noteController.clear();
      setState(() => _itemId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAr
              ? 'تم تحويل المخزون بنجاح.'
              : 'Stock transferred successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAr
              ? 'تعذر تنفيذ التحويل. تحقق من الرصيد والصلاحيات ثم حاول مجدداً.'
              : 'Transfer failed. Check stock and permissions, then try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final canManageInventory =
        user?.hasPermission('can_manage_inventory') ?? false;
    final branchesAsync = ref.watch(branchesStreamProvider);
    final productsAsync = ref.watch(_transferProductsProvider);
    final rawMaterialsAsync = ref.watch(_transferRawMaterialsProvider);

    if (!canManageInventory) {
      return Scaffold(
        appBar: AppBar(title: Text(_isAr ? 'تحويل المخزون' : 'Stock Transfer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _isAr
                  ? 'ليس لديك صلاحية إدارة المخزون.'
                  : 'You do not have inventory management permission.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isAr ? 'تحويل المخزون بين الفروع' : 'Inter-Branch Stock Transfer'),
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: Text(
                _isAr ? 'تعذر تحميل الفروع.' : 'Could not load branches.')),
        data: (allBranches) {
          final branches = allBranches.where((b) => b.isActive).toList();
          if (branches.length < 2) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _isAr
                      ? 'تحتاج إلى فرعين نشطين على الأقل لتنفيذ تحويل مخزون.'
                      : 'At least two active branches are required for a stock transfer.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          _fromBranchId ??= branches.first.id;
          _toBranchId ??= branches.firstWhere((b) => b.id != _fromBranchId).id;
          final fromId = _fromBranchId!;
          final toId = _toBranchId!;
          final sourceInventory =
              ref.watch(branchInventoryStreamProvider(fromId)).valueOrNull ??
                  const <BranchInventory>[];

          final products = productsAsync.valueOrNull ?? const <Product>[];
          final materials =
              rawMaterialsAsync.valueOrNull ?? const <RawMaterial>[];

          final itemEntries = _itemType == 'product'
              ? products
                  .map((p) => _TransferItem(
                      id: p.id,
                      name: p.name,
                      legacyQuantity: p.quantity.toDouble()))
                  .toList()
              : materials
                  .map((m) => _TransferItem(
                      id: m.id, name: m.name, legacyQuantity: m.quantity))
                  .toList();

          _TransferItem? selectedItem;
          for (final item in itemEntries) {
            if (item.id == _itemId) selectedItem = item;
          }
          final available = selectedItem == null
              ? 0.0
              : _inventoryQuantity(sourceInventory, selectedItem.id, _itemType,
                  selectedItem.legacyQuantity, fromId);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _isAr
                        ? 'انقل المنتجات أو المواد الخام بين الفروع بأمان. يتم تحديث الفرعين وسجلات التدقيق في عملية واحدة.'
                        : 'Move products or raw materials safely between branches. Both branches and audit records are updated in one transaction.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: fromId,
                decoration: InputDecoration(
                  labelText: _isAr ? 'من فرع' : 'From branch',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.store_rounded),
                ),
                items: branches
                    .map((b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _fromBranchId = value;
                          if (_toBranchId == value) {
                            _toBranchId =
                                branches.firstWhere((b) => b.id != value).id;
                          }
                          _itemId = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: toId,
                decoration: InputDecoration(
                  labelText: _isAr ? 'إلى فرع' : 'To branch',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on_rounded),
                ),
                items: branches
                    .where((b) => b.id != fromId)
                    .map((b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _toBranchId = value),
              ),
              const SizedBox(height: 20),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'product',
                      icon: const Icon(Icons.inventory_2_rounded),
                      label: Text(_isAr ? 'منتجات' : 'Products')),
                  ButtonSegment(
                      value: 'raw_material',
                      icon: const Icon(Icons.scale_rounded),
                      label: Text(_isAr ? 'مواد خام' : 'Raw Materials')),
                ],
                selected: {_itemType},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => setState(() {
                          _itemType = selection.first;
                          _itemId = null;
                        }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _isAr ? 'الصنف' : 'Item',
                  border: const OutlineInputBorder(),
                ),
                items: itemEntries
                    .map((item) => DropdownMenuItem(
                        value: item.id,
                        child:
                            Text(item.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _itemId = value),
              ),
              if (selectedItem != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.35),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isAr
                              ? 'الرصيد المتاح في ${_branchName(branches, fromId)}: ${available.toStringAsFixed(2)}'
                              : 'Available in ${_branchName(branches, fromId)}: ${available.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                enabled: !_submitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      _isAr ? 'الكمية المراد تحويلها' : 'Transfer quantity',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                enabled: !_submitting,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _isAr ? 'ملاحظة (اختياري)' : 'Note (optional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting || selectedItem == null
                    ? null
                    : () => _submit(
                          branches: branches,
                          itemName: selectedItem!.name,
                          sourceAvailable: available,
                          sourceLegacyQuantity: fromId == BranchIds.main
                              ? selectedItem.legacyQuantity
                              : 0.0,
                          destinationLegacyQuantity: toId == BranchIds.main
                              ? selectedItem.legacyQuantity
                              : 0.0,
                        ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.swap_horiz_rounded),
                label: Text(_isAr ? 'تحويل المخزون' : 'Transfer Stock'),
              ),
              const SizedBox(height: 26),
              Text(
                _isAr ? 'سجل التحويلات' : 'Transfer History',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ref.watch(inventoryTransfersStreamProvider).when(
                    loading: () => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator())),
                    error: (_, __) => Text(_isAr
                        ? 'تعذر تحميل سجل التحويلات.'
                        : 'Could not load transfer history.'),
                    data: (transfers) {
                      if (transfers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                              _isAr
                                  ? 'لا توجد تحويلات مخزون حتى الآن.'
                                  : 'No stock transfers yet.',
                              textAlign: TextAlign.center),
                        );
                      }
                      return Column(
                        children: transfers.take(50).map((t) {
                          final fromName =
                              _branchName(allBranches, t.fromBranchId);
                          final toName = _branchName(allBranches, t.toBranchId);
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.swap_horiz_rounded)),
                              title: Text(t.itemName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                _isAr
                                    ? '$fromName ← $toName\nالكمية: ${t.quantity.toStringAsFixed(2)}${t.createdByName == null ? '' : ' • ${t.createdByName}'}'
                                    : '$fromName → $toName\nQty: ${t.quantity.toStringAsFixed(2)}${t.createdByName == null ? '' : ' • ${t.createdByName}'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.check_circle_rounded,
                                  color: Colors.green),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TransferItem {
  final String id;
  final String name;
  final double legacyQuantity;

  const _TransferItem({
    required this.id,
    required this.name,
    required this.legacyQuantity,
  });
}
