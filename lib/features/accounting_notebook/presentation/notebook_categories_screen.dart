import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookCategoriesScreen extends ConsumerWidget {
  const NotebookCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catsAsync = ref.watch(notebookCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookCategories ?? 'التصنيفات')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: catsAsync.when(
        data: (cats) {
          if (cats.isEmpty) {
            return Center(child: Text(l10n.notebookNoData ?? 'لا توجد بيانات'));
          }
          return ListView.builder(
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              return ListTile(
                title: Text(cat.name),
                subtitle: Text(cat.type == 'income' ? (l10n.income) : (l10n.expense)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditCategoryDialog(context, ref, cat.id, cat.name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive, color: Colors.red),
                      onPressed: () => _showArchiveDialog(context, ref, cat.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.genericErrorPrefix}: $e')),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    String type = 'income';
    String? bookId;
    final l10n = AppLocalizations.of(context)!;
    final books = ref.read(notebookBooksProvider).value ?? [];
    if (books.isNotEmpty) bookId = books.first.id;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.notebookAddCategory ?? 'إضافة تصنيف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(labelText: l10n.notebookCategoryName ?? 'اسم التصنيف'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                items: [
                  DropdownMenuItem(value: 'income', child: Text(l10n.income)),
                  DropdownMenuItem(value: 'expense', child: Text(l10n.expense)),
                ],
                onChanged: (v) => setState(() => type = v!),
                decoration: InputDecoration(labelText: l10n.notebookCategoryName ?? 'النوع'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  ref.read(accountingNotebookProvider).createCategory(bookId: bookId ?? 'default_book', name: ctrl.text.trim(), type: type);
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, String id, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookEditCategory ?? 'تعديل التصنيف'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.notebookCategoryName ?? 'اسم التصنيف'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref.read(accountingNotebookProvider).updateCategory(id, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
  
  void _showArchiveDialog(BuildContext context, WidgetRef ref, String id) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookArchiveCategory ?? 'أرشفة التصنيف'),
        content: Text(l10n.notebookArchiveConfirm ?? 'هل أنت متأكد من أرشفة التصنيف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(accountingNotebookProvider).archiveCategory(id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.archive ?? 'أرشفة', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
