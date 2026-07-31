import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/product_repository.dart';
import 'add_product_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/utils/date_formatter.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsyncValue = ref.watch(productsStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageProducts = appUser?.hasPermission('can_manage_products') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '💡 دليل المنتجات: أضف أصناف وجباتك أو بضائعك هنا. يمكنك ربط المنتج بالمواد الخام (المكونات) ليتم الخصم التلقائي من المستودع عند البيع في شاشة الـ POS.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.4, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: productsAsyncValue.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.text102,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: products.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                onLongPress: canManageProducts ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddProductDialog(productToEdit: product),
                    ),
                  );
                } : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.inventory_2_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory,
                                      size: 14,
                                      color: product.quantity <= 5 ? Colors.red : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${l10n.quantity}: ${product.quantity}',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: product.quantity <= 5 ? Colors.red : Colors.grey[700],
                                        fontWeight: product.quantity <= 5 ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (product.quantity <= 5) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                                    ],
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppDateFormatter.format(product.createdAt),
                                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${product.price} ${currentCurrency.code}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (canManageProducts)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context).viewInsets.bottom,
                                    ),
                                    child: AddProductDialog(productToEdit: product),
                                  ),
                                );
                              } else if (value == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(l10n.delete, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                    content: Text(AppLocalizations.of(context)!.text103, style: const TextStyle(fontFamily: 'Tajawal')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          ref.read(productRepositoryProvider).deleteProduct(product.id);
                                          Navigator.pop(context);
                                        },
                                        child: Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit, size: 20, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(l10n.edit, style: const TextStyle(fontFamily: 'Tajawal')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                  ],
                                ),
                              ),
                            ],
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
        error: (e, st) => Center(
          child: Text('${l10n.error}: $e', style: TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
    ),
  ],
),
floatingActionButton: canManageProducts ? FloatingActionButton.extended(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddProduct(context, ref);
          if (!canAdd) return;

          if (context.mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: const AddProductDialog(),
              ),
            );
          }
        },
        label: Text(l10n.add, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: Icon(Icons.add),
      ) : null,
    );
  }
}

