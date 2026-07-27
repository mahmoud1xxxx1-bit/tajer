import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
        title: Text(AppLocalizations.of(context)!.text_39, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text_40, style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GlassCard(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.category, color: Colors.blue),
                  title: Text(category.name, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
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
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.text_41, style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_42),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text_43),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null || nameController.text.isEmpty) return;

                final category = Category(
                  id: const Uuid().v4(),
                  merchantId: userId,
                  name: nameController.text,
                  createdAt: DateTime.now(),
                );

                ref.read(categoryRepositoryProvider)?.addCategory(category);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text_44),
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
          title: Text(AppLocalizations.of(context)!.text_45, style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_42),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text_43),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;

                final updatedCategory = category.copyWith(name: nameController.text);
                ref.read(categoryRepositoryProvider)?.updateCategory(updatedCategory);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text_46),
            ),
          ],
        );
      },
    );
  }
}

