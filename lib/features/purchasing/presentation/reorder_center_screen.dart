import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/purchase_order_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/raw_material_repository.dart';
import '../domain/purchase_order.dart';

class ReorderCenterScreen extends ConsumerWidget {
  const ReorderCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeBranchId = ref.watch(selectedBranchIdProvider);
    final ordersAsync = ref.watch(purchaseOrdersProvider(activeBranchId ?? 'main'));
    
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reorderCenter ?? 'Reorder Center')),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No purchase orders yet.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('PO ${order.id.substring(0, 8)} - ${order.status.toUpperCase()}'),
                  subtitle: Text('Items: ${order.lines.length} | Supplier: ${order.supplierId}'),
                  trailing: ElevatedButton(
                    onPressed: order.status == 'cancelled' || order.status == 'received' ? null : () {
                      final appUser = ref.read(appUserProvider).value;
                      if (appUser != null) {
                        ref.read(purchaseOrderRepositoryProvider).receiveGoods(
                          order: order,
                          receiptLines: order.lines.map((l) => l.copyWith(receivedQuantity: l.orderedQuantity - l.receivedQuantity)).toList(),
                          actorUid: appUser.id,
                          actorName: appUser.email ?? 'Unknown',
                          operationId: 'reorder_receipt_${order.id}_${DateTime.now().millisecondsSinceEpoch}',
                        );
                      }
                    },
                    child: const Text('Receive'),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final activeBranch = activeBranchId ?? 'main';
          final appUser = ref.read(appUserProvider).value;
          if (appUser == null) return;
          final merchantId = currentEffectiveMerchantId(appUser);
          
          final products = await ref.read(productsStreamProvider.future);
          final materials = await ref.read(rawMaterialsStreamProvider(merchantId).future);
          
          final Map<String, List<PurchaseOrderLine>> supplierLines = {};
          
          for (final p in products) {
            if (!p.isArchived && p.lowStockThreshold > 0 && p.quantity <= p.lowStockThreshold && p.targetQuantity != null && p.preferredSupplierId != null) {
              final needed = p.targetQuantity! - p.quantity;
              if (needed > 0) {
                supplierLines.putIfAbsent(p.preferredSupplierId!, () => []).add(PurchaseOrderLine(
                  id: p.id,
                  itemId: p.id,
                  itemNameSnapshot: p.name,
                  itemType: 'product',
                  orderedQuantity: needed.toDouble(),
                  receivedQuantity: 0,
                  unitCost: p.costPrice,
                ));
              }
            }
          }
          
          for (final m in materials) {
            final low = m.lowStockThreshold ?? 0;
            if (!m.isArchived && low > 0 && m.quantity <= low && m.targetQuantity != null && m.preferredSupplierId != null) {
              final needed = m.targetQuantity! - m.quantity;
              if (needed > 0) {
                supplierLines.putIfAbsent(m.preferredSupplierId!, () => []).add(PurchaseOrderLine(
                  id: m.id,
                  itemId: m.id,
                  itemNameSnapshot: m.name,
                  itemType: 'raw_material',
                  orderedQuantity: needed.toDouble(),
                  receivedQuantity: 0,
                ));
              }
            }
          }
          
          if (supplierLines.isEmpty && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No reorders needed.')));
            return;
          }
          
          for (final entry in supplierLines.entries) {
            final supplierId = entry.key;
            final lines = entry.value;
            
            final order = PurchaseOrder(
              id: '', // Generated by repo
              merchantId: merchantId,
              branchId: activeBranch,
              supplierId: supplierId,
              status: 'draft',
              lines: lines,
              createdAt: DateTime.now(),
              createdByUid: appUser?.id ?? 'system',
            );
            await ref.read(purchaseOrderRepositoryProvider).createPurchaseOrder(order);
          }
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated ${supplierLines.length} draft purchase orders.')));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
