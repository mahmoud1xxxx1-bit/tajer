import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_terminology.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';

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
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    NotebookTerminology.booksGuide(context),
                    style: Theme.of(context).textTheme.bodyMedium,
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
                        Icon(Icons.library_books,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(l10n.notebookNoData,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (await GuestLimitService.canAddNotebookBook(
                                context, ref)) {
                              _showAddBookDialog(context, ref);
                            }
                          },
                          child: Text(l10n.notebookAddBook),
                        ),
                      ],
                    ),
                  );
                }

                final sortedBooks = List.of(books)
                  ..sort((a, b) {
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
                          decoration: book.isArchived
                              ? TextDecoration.lineThrough
                              : null,
                          color: book.isArchived ? Colors.grey : null,
                        ),
                      ),
                      subtitle: book.isArchived
                          ? Text(l10n.notebookArchived,
                              style: const TextStyle(color: Colors.red))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!book.isArchived)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditBookDialog(
                                  context, ref, book.id, book.name),
                            ),
                          if (!book.isArchived)
                            IconButton(
                              icon: const Icon(Icons.archive),
                              onPressed: () =>
                                  _showArchiveDialog(context, ref, book.id),
                            )
                          else
                            TextButton.icon(
                              icon: const Icon(Icons.restore, size: 20),
                              label: Text(l10n.notebookRestore),
                              onPressed: () =>
                                  _showRestoreDialog(context, ref, book.id),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBookDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.notebookAddBook),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: l10n.notebookBookName),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (ctrl.text.trim().isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(accountingNotebookProvider)
                            .createBook(ctrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.genericErrorPrefix)),
                        );
                      }
                    },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBookDialog(
      BuildContext context, WidgetRef ref, String id, String oldName) {
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                await ref
                    .read(accountingNotebookProvider)
                    .updateBook(id, ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.genericErrorPrefix)),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _showArchiveDialog(
      BuildContext context, WidgetRef ref, String id) async {
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
      try {
        await ref.read(accountingNotebookProvider).archiveBook(id);
        if (ref.read(notebookCurrentBookIdProvider) == id) {
          ref.read(notebookCurrentBookIdProvider.notifier).state = null;
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.genericErrorPrefix)),
          );
        }
      }
    }
  }

  Future<void> _showRestoreDialog(
      BuildContext context, WidgetRef ref, String id) async {
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
      try {
        await ref.read(accountingNotebookProvider).restoreBook(id);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.genericErrorPrefix)),
          );
        }
      }
    }
  }
}
