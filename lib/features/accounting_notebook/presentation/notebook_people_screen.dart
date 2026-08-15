import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/notebook_person.dart';

class NotebookPeopleScreen extends ConsumerStatefulWidget {
  const NotebookPeopleScreen({super.key});

  @override
  ConsumerState<NotebookPeopleScreen> createState() =>
      _NotebookPeopleScreenState();
}

class _NotebookPeopleScreenState extends ConsumerState<NotebookPeopleScreen> {
  String? _selectedBookId;

  void _selectBook(String id) {
    ref.read(notebookCurrentBookIdProvider.notifier).state = id;
    setState(() => _selectedBookId = id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookPeople)),
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
                      Expanded(child: Text(l10n.notebookGuidePeople)),
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
                child: peopleAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      Center(child: Text(l10n.genericErrorPrefix)),
                  data: (allPeople) {
                    final people = allPeople
                        .where((p) => p.bookId == selectedBookId)
                        .toList();
                    if (people.isEmpty) {
                      return Center(child: Text(l10n.notebookEmptyPeople));
                    }
                    return ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final person = people[index];
                        final net =
                            person.amountOwedToMe - person.amountIOwe;
                        final archived = person.isArchived;
                        return ListTile(
                          leading: Icon(Icons.person,
                              color: archived ? Colors.grey : null),
                          title: Text(
                            archived
                                ? '${person.name} (${l10n.notebookArchived})'
                                : person.name,
                            style: TextStyle(
                              decoration: archived
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: archived ? Colors.grey : null,
                            ),
                          ),
                          subtitle: person.phone != null &&
                                  person.phone!.isNotEmpty
                              ? Text(person.phone!)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                net.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: archived
                                      ? Colors.grey
                                      : net >= 0
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (!archived)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditPersonDialog(
                                      context, ref, person),
                                ),
                              IconButton(
                                icon: Icon(archived
                                    ? Icons.restore
                                    : Icons.archive),
                                onPressed: () => archived
                                    ? _showRestoreDialog(
                                        context, ref, person.id)
                                    : _showArchiveDialog(
                                        context, ref, person.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.assignment),
                                onPressed: () {
                                  ref
                                      .read(notebookCurrentBookIdProvider.notifier)
                                      .state = person.bookId;
                                  context.push('/notebook/people/${person.id}');
                                },
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
        onPressed: () async {
          if (await GuestLimitService.canAddNotebookPerson(context, ref)) {
            final id = _selectedBookId ?? ref.read(notebookCurrentBookIdProvider);
            if (id != null) {
              ref.read(notebookCurrentBookIdProvider.notifier).state = id;
            }
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (_) => const _AddPersonDialog(),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditPersonDialog(
      BuildContext context, WidgetRef ref, NotebookPerson person) {
    final nameCtrl = TextEditingController(text: person.name);
    final phoneCtrl = TextEditingController(text: person.phone ?? '');
    final noteCtrl = TextEditingController(text: person.notes ?? '');
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookEditPerson),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.notebookPersonName),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    InputDecoration(labelText: l10n.notebookPersonPhone),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(labelText: l10n.notebookNote),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(accountingNotebookProvider).updatePerson(
                    person.id,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    notes: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                  );
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
      title: l10n.notebookArchivePerson,
      warning: l10n.notebookArchiveWarning,
    );
    if (proceed && context.mounted) {
      await ref.read(accountingNotebookProvider).archivePerson(id);
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
      await ref.read(accountingNotebookProvider).restorePerson(id);
    }
  }
}

class _AddPersonDialog extends ConsumerStatefulWidget {
  const _AddPersonDialog();

  @override
  ConsumerState<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends ConsumerState<_AddPersonDialog> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? bookId;
  bool saving = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final preferredBookId = ref.watch(notebookCurrentBookIdProvider);

    return AlertDialog(
      title: Text(l10n.notebookAddPerson),
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
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.notebookPersonName),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: l10n.notebookPersonPhone),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(labelText: l10n.notebookNote),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: saving
              ? null
              : () async {
                  if (nameCtrl.text.trim().isEmpty || bookId == null) return;
                  setState(() => saving = true);
                  try {
                    await ref.read(accountingNotebookProvider).createPerson(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          notes: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                          bookId: bookId!,
                        );
                    ref.read(notebookCurrentBookIdProvider.notifier).state =
                        bookId;
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
