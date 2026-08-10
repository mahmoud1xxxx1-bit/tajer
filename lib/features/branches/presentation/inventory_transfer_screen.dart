import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/raw_material_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/raw_material.dart';
import '../data/branch_inventory_repository.dart';
import '../data/branch_repository.dart';
import '../domain/branch.dart';
import '../domain/branch_inventory.dart';
import '../domain/branch_operation_context.dart';
import '../../../core/providers/global_display_resolver.dart';

final _transferProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, branchId) {
  final user = ref.watch(appUserProvider).value;
  if (user == null || branchId.isEmpty) return Stream.value(const <Product>[]);
  final merchantId = currentEffectiveMerchantId(user);
  final repo = ref.watch(productRepositoryProvider);
  return repo.queryProducts(merchantId, branchId).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
      );
});

final _transferRawMaterialsProvider =
    StreamProvider.family<List<RawMaterial>, String>((ref, branchId) {
  final user = ref.watch(appUserProvider).value;
  if (user == null || branchId.isEmpty) {
    return Stream.value(const <RawMaterial>[]);
  }
  final merchantId = currentEffectiveMerchantId(user);
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
  String? _destinationItemId;
  bool _submitting = false;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _text(String ar, String en) => _isAr ? ar : en;

  String _branchName(List<Branch> branches, String id) {
    return ref.read(globalDisplayResolverProvider).resolveBranchName(id, isAr: _isAr);
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

  Future<void> _showMessage({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_text('حسنا', 'OK')),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_text('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _ensureDestinationItem({
    required String toBranchId,
    required _TransferItem sourceItem,
    required List<_TransferItem> destinationItems,
  }) async {
    final preferredId = _destinationItemId?.trim().isNotEmpty == true
        ? _destinationItemId!.trim()
        : sourceItem.id;
    if (destinationItems.any((item) => item.id == preferredId)) {
      return preferredId;
    }

    final shouldCopy = await _confirm(
      title: _text('نسخ الصنف إلى فرع الوجهة', 'Copy item to destination'),
      message: _text(
        'الصنف غير موجود في فرع الوجهة. هل تريد نسخه إلى فرع الوجهة قبل التحويل؟',
        'The item does not exist in the destination branch. Copy it there before transferring stock?',
      ),
      action: _text('نسخ', 'Copy'),
    );
    if (!shouldCopy || !mounted) return null;

    final product = sourceItem.product;
    if (product != null &&
        product.isManufacturedOnDemand &&
        product.recipe.isNotEmpty) {
      await _showMessage(
        title: _text('لا يمكن النسخ تلقائيا', 'Automatic copy blocked'),
        message: _text(
          'منتج التصنيع عند الطلب يحتوي وصفة. أنشئ المنتج في فرع الوجهة واربط مواد الخام هناك قبل التحويل.',
          'This made-to-order product has a recipe. Create it in the destination branch and map its raw materials there before transferring.',
        ),
      );
      return null;
    }

    final user = ref.read(appUserProvider).value;
    if (user == null) {
      await _showMessage(
        title: _text('تعذر المتابعة', 'Unable to continue'),
        message: _text('جلسة المستخدم غير متاحة.', 'User session unavailable.'),
      );
      return null;
    }

    final merchantId = currentEffectiveMerchantId(user);
    final operationContext = BranchOperationContext(
      merchantId: merchantId,
      branchId: toBranchId,
    );

    if (product != null) {
      await ref.read(productRepositoryProvider).addProduct(
        product.copyWith(
          quantity: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        context: operationContext,
        enabledBranchIds: {toBranchId},
      );
    } else if (sourceItem.rawMaterial != null) {
      await ref.read(rawMaterialRepositoryProvider).addRawMaterial(
        sourceItem.rawMaterial!.copyWith(
          quantity: 0.0,
          initialQuantity: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        context: operationContext,
        enabledBranchIds: {toBranchId},
      );
    }
    return sourceItem.id;
  }

  Future<void> _submit({
    required List<Branch> branches,
    required _TransferItem sourceItem,
    required List<_TransferItem> destinationItems,
    required double sourceAvailable,
    required double sourceLegacyQuantity,
    required double destinationLegacyQuantity,
  }) async {
    final from = _fromBranchId;
    final to = _toBranchId;
    final quantity = double.tryParse(_quantityController.text.trim());

    String? error;
    if (from == null || to == null) {
      error = _text('اختر فرع المصدر وفرع الوجهة.',
          'Select source and destination branches.');
    } else if (from == to) {
      error = _text('يجب أن يختلف فرع الوجهة عن فرع المصدر.',
          'Destination branch must be different from source branch.');
    } else if (quantity == null || quantity <= 0) {
      error = _text('أدخل كمية صحيحة أكبر من صفر.',
          'Enter a valid quantity greater than zero.');
    } else if (quantity > sourceAvailable + 0.000001) {
      error = _text('الكمية المطلوبة أكبر من رصيد فرع المصدر.',
          'Requested quantity exceeds available source stock.');
    }

    if (error != null) {
      await _showMessage(
        title: _text('تعذر التحويل', 'Transfer blocked'),
        message: error,
      );
      return;
    }

    final destinationItemId = await _ensureDestinationItem(
      toBranchId: to!,
      sourceItem: sourceItem,
      destinationItems: destinationItems,
    );
    if (destinationItemId == null || !mounted) return;

    final fromName = _branchName(branches, from!);
    final toName = _branchName(branches, to);
    final confirmed = await _confirm(
      title: _text('تأكيد تحويل المخزون', 'Confirm stock transfer'),
      message: _text(
        'سيتم تحويل ${quantity!.toStringAsFixed(2)} من "${sourceItem.name}" من "$fromName" إلى "$toName".',
        'Transfer ${quantity!.toStringAsFixed(2)} of "${sourceItem.name}" from "$fromName" to "$toName".',
      ),
      action: _text('تأكيد التحويل', 'Confirm transfer'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(branchInventoryRepositoryProvider);
      final user = ref.read(appUserProvider).value;
      if (repo == null || user == null) {
        throw StateError('Inventory repository unavailable');
      }
      await repo.transferQuantity(
        fromBranchId: from,
        toBranchId: to,
        itemType: _itemType,
        itemId: sourceItem.id,
        destinationItemId: destinationItemId,
        operationId: const Uuid().v4(),
        itemName: sourceItem.name,
        quantity: quantity,
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
      setState(() {
        _itemId = null;
        _destinationItemId = null;
      });
      await _showMessage(
        title: _text('تم التحويل', 'Transfer complete'),
        message:
            _text('تم تحويل المخزون بنجاح.', 'Stock transferred successfully.'),
      );
    } catch (_) {
      if (!mounted) return;
      await _showMessage(
        title: _text('تعذر التحويل', 'Transfer failed'),
        message: _text(
          'تعذر تنفيذ التحويل. تحقق من الرصيد والصلاحيات ثم حاول مجددا.',
          'Transfer failed. Check stock and permissions, then try again.',
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

    if (!canManageInventory) {
      return Scaffold(
        appBar: AppBar(title: Text(_text('تحويل المخزون', 'Stock Transfer'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _text('ليس لديك صلاحية إدارة المخزون.',
                  'You do not have inventory management permission.'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_text(
          'تحويل المخزون بين الفروع',
          'Inter-Branch Stock Transfer',
        )),
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(_text('تعذر تحميل الفروع.', 'Could not load branches.')),
        ),
        data: (allBranches) {
          final branches = allBranches.where((b) => b.isActive).toList();
          if (branches.length < 2) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _text(
                    'تحتاج إلى فرعين نشطين على الأقل لتنفيذ تحويل مخزون.',
                    'At least two active branches are required for a stock transfer.',
                  ),
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
          final destinationInventory =
              ref.watch(branchInventoryStreamProvider(toId)).valueOrNull ??
                  const <BranchInventory>[];
          final sourceProducts =
              ref.watch(_transferProductsProvider(fromId)).valueOrNull ??
                  const <Product>[];
          final sourceMaterials =
              ref.watch(_transferRawMaterialsProvider(fromId)).valueOrNull ??
                  const <RawMaterial>[];
          final destinationProducts =
              ref.watch(_transferProductsProvider(toId)).valueOrNull ??
                  const <Product>[];
          final destinationMaterials =
              ref.watch(_transferRawMaterialsProvider(toId)).valueOrNull ??
                  const <RawMaterial>[];

          final itemEntries = _itemType == 'product'
              ? sourceProducts
                  .map((p) => _TransferItem(
                        id: p.id,
                        name: p.name,
                        legacyQuantity: p.quantity.toDouble(),
                        product: p,
                      ))
                  .toList()
              : sourceMaterials
                  .map((m) => _TransferItem(
                        id: m.id,
                        name: m.name,
                        legacyQuantity: m.quantity,
                        rawMaterial: m,
                      ))
                  .toList();
          final destinationEntries = _itemType == 'product'
              ? destinationProducts
                  .map((p) => _TransferItem(
                        id: p.id,
                        name: p.name,
                        legacyQuantity: p.quantity.toDouble(),
                        product: p,
                      ))
                  .toList()
              : destinationMaterials
                  .map((m) => _TransferItem(
                        id: m.id,
                        name: m.name,
                        legacyQuantity: m.quantity,
                        rawMaterial: m,
                      ))
                  .toList();

          _TransferItem? selectedItem;
          for (final item in itemEntries) {
            if (item.id == _itemId) selectedItem = item;
          }
          if (_destinationItemId != null &&
              !destinationEntries
                  .any((item) => item.id == _destinationItemId)) {
            _destinationItemId = null;
          }

          final available = selectedItem == null
              ? 0.0
              : _inventoryQuantity(sourceInventory, selectedItem.id, _itemType,
                  selectedItem.legacyQuantity, fromId);
          final destinationQuantity = selectedItem == null
              ? 0.0
              : _inventoryQuantity(
                  destinationInventory,
                  _destinationItemId ?? selectedItem.id,
                  _itemType,
                  toId == BranchIds.main ? selectedItem.legacyQuantity : 0.0,
                  toId,
                );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: fromId,
                decoration: InputDecoration(
                  labelText: _text('من فرع', 'From branch'),
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
                          _destinationItemId = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: toId,
                decoration: InputDecoration(
                  labelText: _text('إلى فرع', 'To branch'),
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
                    : (value) => setState(() {
                          _toBranchId = value;
                          _destinationItemId = null;
                        }),
              ),
              const SizedBox(height: 20),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'product',
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: Text(_text('منتجات', 'Products')),
                  ),
                  ButtonSegment(
                    value: 'raw_material',
                    icon: const Icon(Icons.scale_rounded),
                    label: Text(_text('مواد خام', 'Raw Materials')),
                  ),
                ],
                selected: {_itemType},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => setState(() {
                          _itemType = selection.first;
                          _itemId = null;
                          _destinationItemId = null;
                        }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _text('صنف المصدر', 'Source item'),
                  border: const OutlineInputBorder(),
                ),
                items: itemEntries
                    .map((item) => DropdownMenuItem(
                          value: item.id,
                          child:
                              Text(item.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                          _itemId = value;
                          _destinationItemId =
                              destinationEntries.any((item) => item.id == value)
                                  ? value
                                  : null;
                        }),
              ),
              if (selectedItem != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _destinationItemId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _text('صنف الوجهة', 'Destination item'),
                    border: const OutlineInputBorder(),
                  ),
                  items: destinationEntries
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _destinationItemId = value),
                  hint: Text(_text(
                    'سيتم نسخ صنف المصدر إذا لم يوجد',
                    'Copy source item if missing',
                  )),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
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
                          _text(
                            'المصدر: ${available.toStringAsFixed(2)} | الوجهة: ${destinationQuantity.toStringAsFixed(2)}',
                            'Source: ${available.toStringAsFixed(2)} | Destination: ${destinationQuantity.toStringAsFixed(2)}',
                          ),
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
                      _text('الكمية المراد تحويلها', 'Transfer quantity'),
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
                  labelText: _text('ملاحظة (اختياري)', 'Note (optional)'),
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
                          sourceItem: selectedItem!,
                          destinationItems: destinationEntries,
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz_rounded),
                label: Text(_text('تحويل المخزون', 'Transfer Stock')),
              ),
              const SizedBox(height: 26),
              Text(
                _text('سجل التحويلات', 'Transfer History'),
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
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, __) => Text(_text(
                      'تعذر تحميل سجل التحويلات.',
                      'Could not load transfer history.',
                    )),
                    data: (transfers) {
                      if (transfers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _text('لا توجد تحويلات مخزون حتى الآن.',
                                'No stock transfers yet.'),
                            textAlign: TextAlign.center,
                          ),
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
                                child: Icon(Icons.swap_horiz_rounded),
                              ),
                              title: Text(t.itemName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                _text(
                                  '$fromName -> $toName\nالكمية: ${t.quantity.toStringAsFixed(2)}${t.createdByName == null ? '' : ' • ${t.createdByName}'}',
                                  '$fromName -> $toName\nQty: ${t.quantity.toStringAsFixed(2)}${t.createdByName == null ? '' : ' • ${t.createdByName}'}',
                                ),
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
  final Product? product;
  final RawMaterial? rawMaterial;

  const _TransferItem({
    required this.id,
    required this.name,
    required this.legacyQuantity,
    this.product,
    this.rawMaterial,
  });
}
