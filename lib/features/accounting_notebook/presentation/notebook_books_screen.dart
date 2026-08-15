import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookBooksScreen extends ConsumerWidget {
  const NotebookBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookBooks)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBookDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return Center(child: Text(l10n.notebookNoData));
          }
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                title: Text(book.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditBookDialog(context, ref, book.id, book.name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive, color: Colors.red),
                      onPressed: () => _showArchiveDialog(context, ref, book.id),
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
  
  void _showArchiveDialog(BuildContext context, WidgetRef ref, String id) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookArchiveBook),
        content: Text(l10n.notebookArchiveConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(accountingNotebookProvider).archiveBook(id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.archive, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
