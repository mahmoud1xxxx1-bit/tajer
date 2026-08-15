import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../../../core/services/guest_limit_service.dart';
import '../../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../authentication/data/auth_repository.dart';

class NotebookBooksScreen extends ConsumerWidget {
  const NotebookBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookBooks)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (await GuestLimitService.canAddNotebookBook(context, ref)) {
            _showAddBookDialog(context, ref);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.notebookGuideBooks,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: booksAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books, size: 80, color: Colors.indigo.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.notebookNoData,
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 20, color: Colors.indigo.shade900),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (await GuestLimitService.canAddNotebookBook(context, ref)) {
                              _showAddBookDialog(context, ref);
                            }
                          },
                          child: Text(l10n.notebookAddBook),
                        )
                      ],
                    ),
                  );
                }

                // Sort: active first, archived last
                final sortedBooks = List.of(books)..sort((a, b) {
                  if (a.isArchived && !b.isArchived) return 1;
                  if (!a.isArchived && b.isArchived) return -1;
                  return a.name.compareTo(b.name);
                });

                return ListView.builder(
                  itemCount: sortedBooks.length,
                  itemBuilder: (context, index) {
                    final book = sortedBooks[index];
                    return ListTile(
                      title: Text(
                        book.name,
                        style: TextStyle(
                          decoration: book.isArchived ? TextDecoration.lineThrough : null,
                          color: book.isArchived ? Colors.grey : null,
                        ),
                      ),
                      subtitle: book.isArchived ? Text(l10n.notebookArchived, style: const TextStyle(color: Colors.red)) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!book.isArchived)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditBookDialog(context, ref, book.id, book.name),
                            ),
                          if (!book.isArchived)
                            IconButton(
                              icon: const Icon(Icons.archive, color: Colors.red),
                              onPressed: () => _showArchiveDialog(context, ref, book.id),
                            )
                          else
                            TextButton.icon(
                              icon: const Icon(Icons.restore, color: Colors.green, size: 20),
                              label: Text(l10n.notebookRestore, style: const TextStyle(color: Colors.green)),
                              onPressed: () => _showRestoreDialog(context, ref, book.id),
                            )
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('${l10n.genericErrorPrefix}: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBookDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookAddBook),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.notebookBookName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref.read(accountingNotebookProvider).createBook(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
  
  void _showEditBookDialog(BuildContext context, WidgetRef ref, String id, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookEditBook),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.notebookBookName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref.read(accountingNotebookProvider).updateBook(id, ctrl.text.trim());
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
      title: l10n.notebookArchiveBook,
      warning: l10n.notebookArchiveWarning,
    );
    
    if (proceed && context.mounted) {
      ref.read(accountingNotebookProvider).archiveBook(id);
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
      warning: l10n.localeName == 'ar' ? 'استرجاع هذا العنصر سيجعله متاحًا في العمليات الجديدة.' : 'Restoring this item will make it available for new operations.',
    );
    
    if (proceed && context.mounted) {
      ref.read(accountingNotebookProvider).restoreBook(id);
    }
  }
}
