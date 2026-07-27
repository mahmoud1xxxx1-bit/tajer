import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('لا يوجد تصنيفات حالياً', style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.category, color: Colors.blue),
                  title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref.read(categoryRepositoryProvider)?.deleteCategory(category.id);
                    },
                  ),
                  onTap: () {
                    _showEditCategoryDialog(context, ref, category);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة تصنيف جديد', style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم التصنيف'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null || nameController.text.isEmpty) return;

                final category = Category(
                  id: const Uuid().v4(),
                  merchantId: user.uid,
                  name: nameController.text,
                  createdAt: DateTime.now(),
                );

                ref.read(categoryRepositoryProvider)?.addCategory(category);
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, Category category) {
    final nameController = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل التصنيف', style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم التصنيف'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;

                final updatedCategory = category.copyWith(name: nameController.text);
                ref.read(categoryRepositoryProvider)?.updateCategory(updatedCategory);
                Navigator.pop(context);
              },
              child: const Text('تحديث'),
            ),
          ],
        );
      },
    );
  }
}
