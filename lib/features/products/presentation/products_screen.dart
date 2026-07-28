import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/product_repository.dart';
import 'add_product_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/data/auth_repository.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsyncValue = ref.watch(productsStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: productsAsyncValue.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.text_102,
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
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(4),
                onLongPress: () {
                  // Delete confirmation
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.delete, style: TextStyle(fontFamily: 'Tajawal')),
                      content: Text(AppLocalizations.of(context)!.text_103, style: TextStyle(fontFamily: 'Tajawal')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel, style: TextStyle(fontFamily: 'Tajawal')),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(productRepositoryProvider).deleteProduct(product.id);
                            Navigator.pop(context);
                          },
                          child: Text(l10n.delete, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                        ),
                      ],
                    ),
                  );
                },
                child: ListTile(
                  title: Text(
                    product.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2, 
                          size: 16, 
                          color: product.quantity <= 5 ? Colors.red : Theme.of(context).colorScheme.secondary
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${l10n.quantity}: ${product.quantity}',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: product.quantity <= 5 ? Colors.red : null,
                            fontWeight: product.quantity <= 5 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (product.quantity <= 5) ...[
                          SizedBox(width: 4),
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                        ],
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${product.price} ${currentCurrency.code}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert),
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
                                title: Text(l10n.delete, style: TextStyle(fontFamily: 'Tajawal')),
                                content: Text(AppLocalizations.of(context)!.text_103, style: TextStyle(fontFamily: 'Tajawal')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(l10n.cancel, style: TextStyle(fontFamily: 'Tajawal')),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(productRepositoryProvider).deleteProduct(product.id);
                                      Navigator.pop(context);
                                    },
                                    child: Text(l10n.delete, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
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
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text(l10n.edit, style: TextStyle(fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                          if (ref.read(appUserProvider).value?.role != 'cashier')
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(l10n.delete, style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                ],
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
        error: (e, st) => Center(
          child: Text('${l10n.error}: $e', style: TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      ),
    );
  }
}
