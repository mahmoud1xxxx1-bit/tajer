import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                trailing: Text(
                  net.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: net >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add person dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
