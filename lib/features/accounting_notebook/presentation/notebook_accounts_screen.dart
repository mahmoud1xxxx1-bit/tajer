import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookAccountsScreen extends ConsumerWidget {
  const NotebookAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(notebookAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookAccounts)),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.notebookNoAccountsFound));
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final acc = accounts[index];
              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(acc.name),
                trailing: Text(
                  acc.balance.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
          // TODO: Add account dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
