import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_localization_helper.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/notebook_account.dart';

class NotebookAccountsScreen extends ConsumerStatefulWidget {
  const NotebookAccountsScreen({super.key});

  @override
  ConsumerState<NotebookAccountsScreen> createState() =>
      _NotebookAccountsScreenState();
}

class _NotebookAccountsScreenState
    extends ConsumerState<NotebookAccountsScreen> {
  String? _selectedBookId;

  void _selectBook(String id) {
    ref.read(notebookCurrentBookIdProvider.notifier).state = id;
    setState(() => _selectedBookId = id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookAccounts)),
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
                      Expanded(child: Text(l10n.notebookGuideAccounts)),
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
                child: accountsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      Center(child: Text(l10n.genericErrorPrefix)),
                  data: (allAccounts) {
                    final accounts = allAccounts
                        .where((a) => a.bookId == selectedBookId)
                        .toList();
                    if (accounts.isEmpty) {
                      return Center(child: Text(l10n.notebookEmptyAccounts));
                    }
                    return ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final archived = account.isArchived;
                        return ListTile(
                          enabled: !archived,
                          leading: Icon(Icons.account_balance_wallet,
                              color: archived ? Colors.grey : null),
                          title: Text(
                            archived
                                ? '${account.name} (${l10n.notebookArchived})'
                                : account.name,
                            style: TextStyle(
                              decoration: archived
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: archived ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Text(
                            '${l10n.notebookBalance}: ${account.balance.toStringAsFixed(2)} | ${l10n.notebookAccountType}: ${NotebookLocalizationHelper.getAccountTypeName(context, account.type)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!archived)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditAccountDialog(
                                      context, ref, account),
                                ),
                              IconButton(
                                icon: Icon(archived
                                    ? Icons.restore
                                    : Icons.archive),
                                onPressed: () => archived
                                    ? _showRestoreDialog(
                                        context, ref, account.id)
                                    : _showArchiveDialog(
                                        context, ref, account.id),
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
            final id = _selectedBookId ??
                ref.read(notebookCurrentBookIdProvider);
            if (id != null) {
              ref.read(notebookCurrentBookIdProvider.notifier).state = id;
            }
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (_) => const _AddAccountDialog(),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditAccountDialog(
      BuildContext context, WidgetRef ref, NotebookAccount account) {
    final nameCtrl = TextEditingController(text: account.name);
    final noteCtrl = TextEditingController(text: account.notes ?? '');
    String type = account.type.isNotEmpty ? account.type : 'Cash';
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.notebookEditAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.notebookAccountName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    DropdownMenuItem(
                        value: 'Cash', child: Text(l10n.notebookTypeCash)),
                    DropdownMenuItem(
                        value: 'Bank', child: Text(l10n.notebookTypeBank)),
                    DropdownMenuItem(
                        value: 'Card', child: Text(l10n.notebookTypeCard)),
                    DropdownMenuItem(
                        value: 'Wallet', child: Text(l10n.notebookTypeWallet)),
                    DropdownMenuItem(
                        value: 'Other', child: Text(l10n.notebookTypeOther)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                  decoration:
                      InputDecoration(labelText: l10n.notebookAccountType),
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
                await ref.read(accountingNotebookProvider).updateAccount(
                      account.id,
                      name: nameCtrl.text.trim(),
                      type: type,
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
      title: l10n.notebookArchiveAccount,
      warning: l10n.notebookArchiveWarning,
    );
    if (proceed && context.mounted) {
      await ref.read(accountingNotebookProvider).archiveAccount(id);
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
      await ref.read(accountingNotebookProvider).restoreAccount(id);
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
  bool saving = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    balanceCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final preferredBookId = ref.watch(notebookCurrentBookIdProvider);

    return AlertDialog(
      title: Text(l10n.notebookAddAccount),
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
                      InputDecoration(labelText: l10n.notebookAccountName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    DropdownMenuItem(
                        value: 'Cash', child: Text(l10n.notebookTypeCash)),
                    DropdownMenuItem(
                        value: 'Bank', child: Text(l10n.notebookTypeBank)),
                    DropdownMenuItem(
                        value: 'Card', child: Text(l10n.notebookTypeCard)),
                    DropdownMenuItem(
                        value: 'Wallet', child: Text(l10n.notebookTypeWallet)),
                    DropdownMenuItem(
                        value: 'Other', child: Text(l10n.notebookTypeOther)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => type = value);
                  },
                  decoration:
                      InputDecoration(labelText: l10n.notebookAccountType),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: l10n.notebookOpeningBalance),
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
            child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: saving
              ? null
              : () async {
                  if (nameCtrl.text.trim().isEmpty || bookId == null) return;
                  final balance =
                      double.tryParse(balanceCtrl.text.trim().isEmpty
                              ? '0'
                              : balanceCtrl.text.trim()) ??
                          -1;
                  if (balance < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.notebookInvalidAmount)),
                    );
                    return;
                  }
                  setState(() => saving = true);
                  try {
                    await ref.read(accountingNotebookProvider).createAccount(
                          name: nameCtrl.text.trim(),
                          type: type,
                          openingBalance: balance,
                          bookId: bookId!,
                          notes: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
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
