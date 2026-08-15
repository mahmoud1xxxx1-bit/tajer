import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';

class NotebookCategoriesScreen extends ConsumerStatefulWidget {
  const NotebookCategoriesScreen({super.key});

  @override
  ConsumerState<NotebookCategoriesScreen> createState() => _NotebookCategoriesScreenState();
}

class _NotebookCategoriesScreenState extends ConsumerState<NotebookCategoriesScreen> {
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookCategories)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
        data: (books) {
          final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();
          if (activeBooks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/books'),
                    child: Text(l10n.notebookCreateBookCTA),
                  )
                ],
              ),
            );
          }

          if (_selectedBookId == null || !activeBooks.any((b) => b.id == _selectedBookId)) {
            _selectedBookId = activeBooks.first.id;
          }

          final catsAsync = ref.watch(notebookCategoriesProvider);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.notebookGuideCategories,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedBookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: activeBooks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => _selectedBookId = val),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: catsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                  data: (allCats) {
                    final cats = allCats.where((c) => c.bookId == _selectedBookId).toList();
                    if (cats.isEmpty) {
                      return Center(child: Text(l10n.notebookNoCategoriesFound));
                    }

                    return ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        final isArchived = cat.isArchived ?? false;
                        return ListTile(
                          enabled: !isArchived,
                          title: Text(
                            isArchived ? '${cat.name} (${l10n.notebookArchived})' : cat.name,
                            style: TextStyle(
                              decoration: isArchived ? TextDecoration.lineThrough : null,
                              color: isArchived ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            cat.type == 'income' ? (l10n.income) : (l10n.expense),
                            style: TextStyle(color: isArchived ? Colors.grey : null),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isArchived)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditCategoryDialog(context, ref, cat.id, cat.name),
                                ),
                              if (!isArchived)
                                IconButton(
                                  icon: const Icon(Icons.archive, color: Colors.red),
                                  onPressed: () => _showArchiveDialog(context, ref, cat.id),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.green),
                                  onPressed: () => _showRestoreDialog(context, ref, cat.id),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddCategoryDialog(),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, String id, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookEditCategory),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.notebookCategoryName),
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

  void _showArchiveDialog(BuildContext context, WidgetRef ref, String id) async {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.read(appUserProvider).value;
    if (appUser == null) return;
    
    final proceed = await PinConfirmationDialog.requirePinOrSetup(
      context, 
      appUser,
      title: l10n.notebookArchiveCategory,
      warning: l10n.notebookArchiveWarning,
    );
    
    if (proceed && context.mounted) {
      ref.read(accountingNotebookProvider).archiveCategory(id);
    }
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref, String id) async {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.read(appUserProvider).value;
    if (appUser == null) return;
    
    final proceed = await PinConfirmationDialog.requirePinOrSetup(
      context, 
      appUser,
      title: l10n.notebookRestore,
      warning: l10n.notebookRestoreWarning,
    );
    
    if (proceed && context.mounted) {
      ref.read(accountingNotebookProvider).restoreCategory(id);
    }
  }
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();
  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final ctrl = TextEditingController();
  String type = 'income';
  String? bookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return AlertDialog(
      title: Text(l10n.notebookAddCategory),
      content: booksAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Text('${l10n.genericErrorPrefix}: $err'),
        data: (books) {
          final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();
          if (activeBooks.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.notebookEmptyBooks),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/notebook/books');
                  },
                  child: Text(l10n.notebookCreateBookCTA),
                )
              ],
            );
          }

          if (bookId == null || !activeBooks.any((b) => b.id == bookId)) {
            bookId = activeBooks.first.id;
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  value: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: activeBooks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(labelText: l10n.notebookCategoryName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    DropdownMenuItem(value: 'income', child: Text(l10n.income)),
                    DropdownMenuItem(value: 'expense', child: Text(l10n.expense)),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                  decoration: InputDecoration(labelText: l10n.notebookCategoryName),
                ),
              ],
            ),
          );
        }
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty && bookId != null) {
              ref.read(accountingNotebookProvider).createCategory(
                bookId: bookId!,
                name: ctrl.text.trim(),
                type: type,
              );
              Navigator.pop(context);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
