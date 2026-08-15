import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';


class NotebookPeopleScreen extends ConsumerStatefulWidget {
  const NotebookPeopleScreen({super.key});

  @override
  ConsumerState<NotebookPeopleScreen> createState() => _NotebookPeopleScreenState();
}

class _NotebookPeopleScreenState extends ConsumerState<NotebookPeopleScreen> {
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookPeople)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
        data: (books) {
          if (books.isEmpty) {
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

          if (_selectedBookId == null || !books.any((b) => b.id == _selectedBookId)) {
            _selectedBookId = books.first.id;
          }

          final peopleAsync = ref.watch(notebookPeopleProvider);

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
                          l10n.notebookGuidePeople,
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
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => _selectedBookId = val),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: peopleAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                  data: (allPeople) {
                    final people = allPeople.where((p) => p.bookId == _selectedBookId).toList();
                    if (people.isEmpty) {
                      return Center(child: Text(l10n.notebookEmptyPeople));
                    }

                    return ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final p = people[index];
                        final net = p.amountOwedToMe - p.amountIOwe;
                        final isArchived = p.isArchived ?? false;
                        return ListTile(
                          enabled: !isArchived,
                          leading: Icon(
                            Icons.person,
                            color: isArchived ? Colors.grey : null,
                          ),
                          title: Text(
                            isArchived ? '${p.name} (${l10n.notebookArchived})' : p.name,
                            style: TextStyle(
                              decoration: isArchived ? TextDecoration.lineThrough : null,
                              color: isArchived ? Colors.grey : null,
                            ),
                          ),
                          subtitle: (p.phone != null && p.phone!.isNotEmpty) 
                            ? Text(p.phone!, style: TextStyle(color: isArchived ? Colors.grey : null)) 
                            : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                net.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isArchived ? Colors.grey : (net >= 0 ? Colors.green : Colors.red),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isArchived)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditPersonDialog(context, ref, p.id, p.name, p.phone),
                                ),
                              if (!isArchived)
                                IconButton(
                                  icon: const Icon(Icons.archive, color: Colors.red),
                                  onPressed: () => _showArchiveDialog(context, ref, p.id),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.green),
                                  onPressed: () => _showRestoreDialog(context, ref, p.id),
                                ),
                              IconButton(
                                icon: Icon(Icons.assignment, color: isArchived ? Colors.grey : Colors.teal),
                                onPressed: () => context.push('/notebook/people/${p.id}'), // Statement
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
            _showAddPersonDialog(context, ref);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddPersonDialog(),
    );
  }

  void _showEditPersonDialog(BuildContext context, WidgetRef ref, String id, String oldName, String? oldPhone) {
    final nameCtrl = TextEditingController(text: oldName);
    final phoneCtrl = TextEditingController(text: oldPhone ?? '');
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
                decoration: InputDecoration(labelText: l10n.notebookPersonPhone),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(accountingNotebookProvider).updatePerson(
                  id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
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
      title: l10n.notebookArchivePerson,
      warning: l10n.notebookArchiveWarning,
    );
    
    if (proceed && context.mounted) {
      ref.read(accountingNotebookProvider).archivePerson(id);
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
      ref.read(accountingNotebookProvider).restorePerson(id);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return AlertDialog(
      title: Text(l10n.notebookAddPerson),
      content: booksAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Text('${l10n.genericErrorPrefix}: $err'),
        data: (books) {
          if (books.isEmpty) {
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

          if (bookId == null || !books.any((b) => b.id == bookId)) {
            bookId = books.first.id;
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  value: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.notebookPersonName),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(labelText: l10n.notebookPersonPhone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(labelText: l10n.notebookNote),
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
            if (nameCtrl.text.trim().isNotEmpty && bookId != null) {
              ref.read(accountingNotebookProvider).createPerson(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                notes: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                bookId: bookId!,
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
