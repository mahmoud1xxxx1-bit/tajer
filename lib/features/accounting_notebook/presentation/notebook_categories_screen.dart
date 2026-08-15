import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../data/notebook_flow_context.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';

class NotebookCategoriesScreen extends ConsumerStatefulWidget {
  const NotebookCategoriesScreen({super.key});

  @override
  ConsumerState<NotebookCategoriesScreen> createState() =>
      _NotebookCategoriesScreenState();
}

class _NotebookCategoriesScreenState
    extends ConsumerState<NotebookCategoriesScreen> {
  String? _selectedBookId;

  @override
  void dispose() {
    ref.read(notebookPendingCategoryTypeProvider.notifier).state = null;
    super.dispose();
  }

  void _selectBook(String id) {
    ref.read(notebookCurrentBookIdProvider.notifier).state = id;
    setState(() => _selectedBookId = id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final categoriesAsync = ref.watch(notebookCategoriesProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookCategories)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
        data: (books) {
          final activeBooks = books.where((b) => !b.isArchived).toList();
          if (activeBooks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyBooks,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/books'),
                    child: Text(l10n.notebookCreateBookCTA),
                  ),
                ],
              ),
            );
          }

          final candidate = _selectedBookId ?? sharedBookId;
          final selectedBookId = activeBooks.any((b) => b.id == candidate)
              ? candidate!
              : activeBooks.first.id;
          _selectedBookId = selectedBookId;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l10n.notebookGuideCategories)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: selectedBookId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: activeBooks
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _selectBook(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      Center(child: Text(l10n.genericErrorPrefix)),
                  data: (allCategories) {
                    final categories = allCategories
                        .where((c) => c.bookId == selectedBookId)
                        .toList();
                    if (categories.isEmpty) {
                      return Center(
                          child: Text(l10n.notebookNoCategoriesFound));
                    }
                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final archived = category.isArchived;
                        return ListTile(
                          enabled: !archived,
                          leading: Icon(
                            category.type == 'income'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: archived
                                ? Colors.grey
                                : category.type == 'income'
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          title: Text(
                            archived
                                ? '${category.name} (${l10n.notebookArchived})'
                                : category.name,
                            style: TextStyle(
                              decoration: archived
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: archived ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(category.type == 'income'
                              ? l10n.income
                              : l10n.expense),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!archived)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditCategoryDialog(
                                      context, ref, category.id, category.name),
                                ),
                              IconButton(
                                icon: Icon(archived
                                    ? Icons.restore
                                    : Icons.archive),
                                onPressed: () => archived
                                    ? _showRestoreDialog(
                                        context, ref, category.id)
                                    : _showArchiveDialog(
                                        context, ref, category.id),
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
        onPressed: () {
          final id = _selectedBookId ?? ref.read(notebookCurrentBookIdProvider);
          if (id != null) {
            ref.read(notebookCurrentBookIdProvider.notifier).state = id;
          }
          showDialog(
            context: context,
            builder: (_) => const _AddCategoryDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditCategoryDialog(
      BuildContext context, WidgetRef ref, String id, String oldName) {
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref
                  .read(accountingNotebookProvider)
                  .updateCategory(id, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
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
      title: l10n.notebookArchiveCategory,
      warning: l10n.notebookArchiveWarning,
    );
    if (proceed && context.mounted) {
      await ref.read(accountingNotebookProvider).archiveCategory(id);
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
      await ref.read(accountingNotebookProvider).restoreCategory(id);
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
  bool saving = false;
  bool _intentApplied = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final preferredBookId = ref.watch(notebookCurrentBookIdProvider);
    final pendingType = ref.watch(notebookPendingCategoryTypeProvider);

    if (!_intentApplied) {
      _intentApplied = true;
      if (pendingType == 'income' || pendingType == 'expense') {
        type = pendingType!;
      }
    }

    return AlertDialog(
      title: Text(l10n.notebookAddCategory),
      content: booksAsync.when(
        loading: () => const SizedBox(
            height: 100, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text(l10n.genericErrorPrefix),
        data: (books) {
          final activeBooks = books.where((b) => !b.isArchived).toList();
          if (activeBooks.isEmpty) return Text(l10n.notebookEmptyBooks);
          if (bookId == null || !activeBooks.any((b) => b.id == bookId)) {
            bookId = activeBooks.any((b) => b.id == preferredBookId)
                ? preferredBookId
                : activeBooks.first.id;
          }
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: bookId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: activeBooks
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => bookId = value);
                    if (value != null) {
                      ref.read(notebookCurrentBookIdProvider.notifier).state =
                          value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  decoration:
                      InputDecoration(labelText: l10n.notebookCategoryName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(labelText: l10n.notebookType),
                  items: [
                    DropdownMenuItem(
                        value: 'income', child: Text(l10n.income)),
                    DropdownMenuItem(
                        value: 'expense', child: Text(l10n.expense)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => type = value);
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () {
                  ref.read(notebookPendingCategoryTypeProvider.notifier).state =
                      null;
                  Navigator.pop(context);
                },
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: saving
              ? null
              : () async {
                  if (ctrl.text.trim().isEmpty || bookId == null) return;
                  setState(() => saving = true);
                  try {
                    await ref.read(accountingNotebookProvider).createCategory(
                          bookId: bookId!,
                          name: ctrl.text.trim(),
                          type: type,
                        );
                    ref.read(notebookCurrentBookIdProvider.notifier).state =
                        bookId;
                    ref.read(notebookPendingCategoryTypeProvider.notifier).state =
                        null;
                    if (mounted) Navigator.pop(context);
                  } catch (_) {
                    if (!mounted) return;
                    setState(() => saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.genericErrorPrefix)),
                    );
                  }
                },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
