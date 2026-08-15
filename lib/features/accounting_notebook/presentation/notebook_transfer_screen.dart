import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookTransferScreen extends ConsumerStatefulWidget {
  const NotebookTransferScreen({super.key});

  @override
  ConsumerState<NotebookTransferScreen> createState() =>
      _NotebookTransferScreenState();
}

class _NotebookTransferScreenState
    extends ConsumerState<NotebookTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedBookId;
  String? _sourceAccountId;
  String? _destAccountId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransfer)),
      body: booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('${l10n.genericErrorPrefix}: $err')),
          data: (books) {
            final activeBooks =
                books.where((b) => !(b.isArchived)).toList();
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
                    )
                  ],
                ),
              );
            }

            if (_selectedBookId == null ||
                !activeBooks.any((b) => b.id == _selectedBookId)) {
              _selectedBookId = activeBooks.first.id;
            }

            final accountsAsync = ref.watch(notebookAccountsProvider);
            return accountsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                data: (allAccounts) {
                  final accounts = allAccounts
                      .where((a) =>
                          a.bookId == _selectedBookId &&
                          !(a.isArchived))
                      .toList();

                  if (accounts.length < 2) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.notebookAccountsCreateFirst,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push('/notebook/accounts'),
                            child: Text(l10n.notebookCreateAccountCTA),
                          )
                        ],
                      ),
                    );
                  }

                  if (_sourceAccountId == null ||
                      !accounts.any((a) => a.id == _sourceAccountId)) {
                    _sourceAccountId = accounts[0].id;
                  }
                  if (_destAccountId == null ||
                      !accounts.any((a) => a.id == _destAccountId)) {
                    _destAccountId = accounts[1].id;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.notebookGuideTransferPayment,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedBookId,
                            decoration:
                                InputDecoration(labelText: l10n.notebookBooks),
                            items: books
                                .map((b) => DropdownMenuItem(
                                    value: b.id, child: Text(b.name)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedBookId = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _sourceAccountId,
                            decoration: InputDecoration(
                                labelText: l10n.notebookSourceAccount),
                            items: accounts
                                .map((a) => DropdownMenuItem(
                                    value: a.id, child: Text(a.name)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _sourceAccountId = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _destAccountId,
                            decoration: InputDecoration(
                                labelText: l10n.notebookDestinationAccount),
                            items: accounts
                                .map((a) => DropdownMenuItem(
                                    value: a.id, child: Text(a.name)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _destAccountId = val),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(labelText: l10n.amount),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return l10n.notebookRequired;
                              if (double.tryParse(val) == null ||
                                  double.parse(val) <= 0)
                                return l10n.notebookInvalidAmount;
                              if (_sourceAccountId == _destAccountId)
                                return l10n.notebookSourceDestSame;
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _noteController,
                            decoration:
                                InputDecoration(labelText: l10n.notebookNote),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  final amt =
                                      double.parse(_amountController.text);
                                  final svc =
                                      ref.read(accountingNotebookProvider);
                                  try {
                                    await svc.transferFunds(
                                        bookId: _selectedBookId!,
                                        fromAccountId: _sourceAccountId!,
                                        toAccountId: _destAccountId!,
                                        amount: amt,
                                        note: _noteController.text);
                                    if (mounted) context.pop();
                                  } catch (e) {
                                    if (e
                                        .toString()
                                        .contains('insufficient_balance')) {
                                      final selectedAccount =
                                          accounts.firstWhere(
                                              (a) => a.id == _sourceAccountId);
                                      final msg =
                                          l10n.notebookInsufficientBalance(
                                        amt.toStringAsFixed(2),
                                        selectedAccount.balance
                                            .toStringAsFixed(2),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(msg),
                                              backgroundColor: Colors.red));
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  '${l10n.genericErrorPrefix}: $e')));
                                    }
                                  }
                                }
                              },
                              child: Text(l10n.save),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                });
          }),
    );
  }
}
