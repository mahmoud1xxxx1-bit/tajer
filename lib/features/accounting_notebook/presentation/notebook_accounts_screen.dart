import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_localization_helper.dart';
import '../../../../core/services/guest_limit_service.dart';
import '../../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../authentication/data/auth_repository.dart';


class NotebookAccountsScreen extends ConsumerStatefulWidget {
  const NotebookAccountsScreen({super.key});

  @override
  ConsumerState<NotebookAccountsScreen> createState() => _NotebookAccountsScreenState();
}

class _NotebookAccountsScreenState extends ConsumerState<NotebookAccountsScreen> {
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookAccounts)),
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

          final accountsAsync = ref.watch(notebookAccountsProvider);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("الحساب هو المكان الذي تحتفظ فيه بالمال، مثل: الصندوق أو البنك.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
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
                child: accountsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                  data: (allAccounts) {
                    final accounts = allAccounts.where((a) => a.bookId == _selectedBookId).toList();
                    if (accounts.isEmpty) {
                      return Center(child: Text(l10n.notebookEmptyAccounts));
                    }

                    return ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (ctx, i) {
                        final a = accounts[i];
                        return ListTile(
                          leading: const Icon(Icons.account_balance_wallet),
                          title: Text(a.name),
                          subtitle: Text('${l10n.notebookBalance}: ${a.balance.toStringAsFixed(2)} | ${l10n.notebookAccountType}: ${a.type}'),
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
                ),
              ),
            ],
          );
        },
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
    showDialog(
      context: context,
      builder: (ctx) => const _AddAccountDialog(),
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
                DropdownButtonFormField<String>(
                  value: type,
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

  void _showArchiveDialog(BuildContext context, WidgetRef ref, String id) async {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.read(appUserProvider).value;
    if (appUser == null) return;
    
    final proceed = await PinConfirmationDialog.requirePinOrSetup(
      context, 
      appUser,
      title: l10n.notebookArchiveAccount,
      warning: l10n.notebookArchiveWarning,
    );
    
    if (proceed && context.mounted) {
      ref.read(accountingNotebookProvider).archiveAccount(id);
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
      ref.read(accountingNotebookProvider).restoreAccount(id);
    }
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  const _AddAccountDialog();
  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String type = 'Cash';
  String? bookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return AlertDialog(
      title: Text(l10n.notebookAddAccount),
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
                  decoration: InputDecoration(labelText: l10n.notebookAccountName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
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
          );
        }
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            if (nameCtrl.text.trim().isNotEmpty && bookId != null) {
              final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
              ref.read(accountingNotebookProvider).createAccount(
                name: nameCtrl.text.trim(),
                type: type,
                openingBalance: bal,
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
