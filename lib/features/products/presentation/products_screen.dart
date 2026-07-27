import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/product_repository.dart';
import 'add_product_dialog.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsyncValue = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: productsAsyncValue.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد منتجات بعد.\nاضغط على + لإضافة منتج جديد.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: products.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                  subtitle: Text(
                    'الكمية المتاحة: ${product.quantity}',
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                  trailing: Text(
                    '${product.price} ريال',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onLongPress: () {
                    // Delete confirmation
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('حذف المنتج', style: TextStyle(fontFamily: 'Tajawal')),
                        content: const Text('هل أنت متأكد من حذف هذا المنتج؟', style: TextStyle(fontFamily: 'Tajawal')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(productRepositoryProvider).deleteProduct(product.id);
                              Navigator.pop(context);
                            },
                            child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
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
        },
        label: const Text('إضافة منتج', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
