import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../../../core/services/guest_limit_service.dart';

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
            itemBuilder: (ctx, i) {
              final a = accounts[i];
              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(a.name),
                subtitle: Text('${l10n.balance}: ${a.balance.toStringAsFixed(2)} | ${AppLocalizations.of(context)!.notebookType}: ${a.type}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditAccountDialog(context, ref, a.id, a.name, a.type),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive, color: Colors.red),
                      onPressed: () => _showArchiveDialog(context, ref, a.id),
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
        onPressed: () async {
          if (await GuestLimitService.canAddNotebookAccount(context, ref)) {
            _showAddAccountDialog(context, ref);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'Cash';
    String? bookId;
    final l10n = AppLocalizations.of(context)!;
    final books = ref.read(notebookBooksProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.notebookAddAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(initialValue: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.notebookAccountName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(initialValue: type,
                  items: [
                    DropdownMenuItem(value: 'Cash', child: Text(l10n.notebookTypeCash)),
                    DropdownMenuItem(value: 'Bank', child: Text(l10n.notebookTypeBank)),
                    DropdownMenuItem(value: 'Card', child: Text(l10n.notebookTypeCard)),
                    DropdownMenuItem(value: 'Wallet', child: Text(l10n.notebookTypeWallet)),
                    DropdownMenuItem(value: 'Other', child: Text(l10n.notebookTypeOther)),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                  decoration: InputDecoration(labelText: l10n.notebookAccountType),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.notebookOpeningBalance),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  if (bookId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l10n.notebookCreateBookFirst)));
                    return;
                  }
                  final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
                  ref.read(accountingNotebookProvider).createAccount(
                    name: nameCtrl.text.trim(),
                    type: type,
                    openingBalance: bal,
                    bookId: bookId!,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context, WidgetRef ref, String id, String oldName, String oldType) {
    final nameCtrl = TextEditingController(text: oldName);
    String type = oldType.isNotEmpty ? oldType : 'Cash';
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.notebookEditAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.notebookAccountName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(initialValue: type,
                  items: [
                    DropdownMenuItem(value: 'Cash', child: Text(l10n.notebookTypeCash)),
                    DropdownMenuItem(value: 'Bank', child: Text(l10n.notebookTypeBank)),
                    DropdownMenuItem(value: 'Card', child: Text(l10n.notebookTypeCard)),
                    DropdownMenuItem(value: 'Wallet', child: Text(l10n.notebookTypeWallet)),
                    DropdownMenuItem(value: 'Other', child: Text(l10n.notebookTypeOther)),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                  decoration: InputDecoration(labelText: l10n.notebookAccountType),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  ref.read(accountingNotebookProvider).updateAccount(
                    id,
                    name: nameCtrl.text.trim(),
                    type: type,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, WidgetRef ref, String id) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notebookArchiveAccount),
        content: Text(l10n.notebookArchiveConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(accountingNotebookProvider).archiveAccount(id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.archive, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
