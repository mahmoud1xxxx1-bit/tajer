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

  void _selectBook(String id) {
    ref.read(notebookCurrentBookIdProvider.notifier).state = id;
    setState(() {
      _selectedBookId = id;
      _sourceAccountId = null;
      _destAccountId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransfer)),
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

          return ListView(
            padding: const EdgeInsets.all(16),
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
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.notebookGuideTransferPayment,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
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
              const SizedBox(height: 16),
              accountsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
                data: (allAccounts) {
                  final accounts = allAccounts
                      .where((a) =>
                          a.bookId == selectedBookId && !a.isArchived)
                      .toList();

                  if (accounts.length < 2) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Text(l10n.notebookAccountsCreateFirst,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(notebookCurrentBookIdProvider.notifier)
                                  .state = selectedBookId;
                              context.push('/notebook/accounts');
                            },
                            child: Text(l10n.notebookCreateAccountCTA),
                          ),
                        ],
                      ),
                    );
                  }

                  if (_sourceAccountId == null ||
                      !accounts.any((a) => a.id == _sourceAccountId)) {
                    _sourceAccountId = accounts.first.id;
                  }
                  if (_destAccountId == null ||
                      !accounts.any((a) => a.id == _destAccountId) ||
                      _destAccountId == _sourceAccountId) {
                    _destAccountId =
                        accounts.firstWhere((a) => a.id != _sourceAccountId).id;
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _sourceAccountId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: l10n.notebookSourceAccount),
                          items: accounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _sourceAccountId = value;
                              if (_destAccountId == value) {
                                _destAccountId = accounts
                                    .firstWhere((a) => a.id != value)
                                    .id;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _destAccountId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: l10n.notebookDestinationAccount),
                          items: accounts
                              .where((a) => a.id != _sourceAccountId)
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _destAccountId = value),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(labelText: l10n.amount),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');
                            if (value == null || value.trim().isEmpty) {
                              return l10n.notebookRequired;
                            }
                            if (amount == null || amount <= 0) {
                              return l10n.notebookInvalidAmount;
                            }
                            if (_sourceAccountId == _destAccountId) {
                              return l10n.notebookSourceDestSame;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(labelText: l10n.notebookNote),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!_formKey.currentState!.validate()) return;
                              final amount =
                                  double.parse(_amountController.text);
                              try {
                                await ref
                                    .read(accountingNotebookProvider)
                                    .transferFunds(
                                      bookId: selectedBookId,
                                      fromAccountId: _sourceAccountId!,
                                      toAccountId: _destAccountId!,
                                      amount: amount,
                                      note: _noteController.text.trim(),
                                    );
                                if (mounted) context.pop();
                              } catch (error) {
                                if (!mounted) return;
                                if (error
                                    .toString()
                                    .contains('insufficient_balance')) {
                                  final account = accounts.firstWhere(
                                      (a) => a.id == _sourceAccountId);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.notebookInsufficientBalance(
                                          amount.toStringAsFixed(2),
                                          account.balance.toStringAsFixed(2),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text(l10n.genericErrorPrefix)),
                                  );
                                }
                              }
                            },
                            child: Text(l10n.save),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
