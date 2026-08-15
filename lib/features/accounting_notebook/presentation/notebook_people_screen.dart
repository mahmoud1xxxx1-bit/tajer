import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookPeopleScreen extends ConsumerWidget {
  const NotebookPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peopleAsync = ref.watch(notebookPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookPeople)),
      body: peopleAsync.when(
        data: (people) {
          if (people.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.notebookNoPeopleFound));
          return ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) {
              final p = people[index];
              final net = p.amountOwedToMe - p.amountIOwe;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(p.name),
                subtitle: Text(p.phone ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      net.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: net >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditPersonDialog(context, ref, p.id, p.name, p.phone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive, color: Colors.red),
                      onPressed: () => _showArchiveDialog(context, ref, p.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.assignment, color: Colors.teal),
                      onPressed: () => context.push('/notebook/people/${p.id}'), // Statement
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookAddPerson ?? 'Add Person'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.notebookPersonName ?? 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: l10n.notebookPersonPhone ?? 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(labelText: l10n.notebookNote ?? 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(accountingNotebookProvider).createPerson(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim()
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

  void _showEditPersonDialog(BuildContext context, WidgetRef ref, String id, String oldName, String? oldPhone) {
    final nameCtrl = TextEditingController(text: oldName);
    final phoneCtrl = TextEditingController(text: oldPhone ?? '');
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookEditPerson ?? 'Edit Person'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.notebookPersonName ?? 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: l10n.notebookPersonPhone ?? 'Phone'),
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

  void _showArchiveDialog(BuildContext context, WidgetRef ref, String id) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookArchivePerson ?? 'Archive Person'),
        content: Text(l10n.notebookArchiveConfirm ?? 'Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(accountingNotebookProvider).archivePerson(id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.archive ?? 'Archive', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
