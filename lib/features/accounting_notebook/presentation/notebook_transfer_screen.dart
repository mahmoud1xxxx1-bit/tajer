import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookTransferScreen extends ConsumerStatefulWidget {
  const NotebookTransferScreen({super.key});

  @override
  ConsumerState<NotebookTransferScreen> createState() => _NotebookTransferScreenState();
}

class _NotebookTransferScreenState extends ConsumerState<NotebookTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _sourceAccountId;
  String? _destAccountId;
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransfer ?? 'Transfer')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
        data: (accounts) {
          if (accounts.length < 2) {
            return Center(child: Text(l10n.notebookAccountsCreateFirst ?? 'Create at least 2 accounts first.'));
          }
          if (_sourceAccountId == null) _sourceAccountId = accounts[0].id;
          if (_destAccountId == null) _destAccountId = accounts[1].id;

          return booksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
            data: (books) {
              if (books.isEmpty) {
                return Center(child: Text(l10n.notebookCreateBookFirst ?? 'Create a book first.'));
              }
              if (_selectedBookId == null) _selectedBookId = books.first.id;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedBookId,
                        decoration: InputDecoration(labelText: l10n.notebookBooks ?? 'Book'),
                        items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                        onChanged: (val) => setState(() => _selectedBookId = val),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _sourceAccountId,
                        decoration: InputDecoration(labelText: l10n.notebookSourceAccount ?? 'Source Account'),
                        items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                        onChanged: (val) => setState(() => _sourceAccountId = val),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _destAccountId,
                        decoration: InputDecoration(labelText: l10n.notebookDestinationAccount ?? 'Destination Account'),
                        items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                        onChanged: (val) => setState(() => _destAccountId = val),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(labelText: l10n.amount),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Invalid amount';
                          if (_sourceAccountId == _destAccountId) return 'Source and destination cannot be the same';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(labelText: l10n.notebookNote ?? 'Note'),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final amt = double.parse(_amountController.text);
                              final svc = ref.read(accountingNotebookProvider);
                              try {
                                await svc.transferFunds(
                                  bookId: _selectedBookId!, 
                                  fromAccountId: _sourceAccountId!,
                                  toAccountId: _destAccountId!,
                                  amount: amt, 
                                  note: _noteController.text
                                );
                                if (mounted) context.pop();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.genericErrorPrefix}: $e')));
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
            }
          );
        }
      ),
    );
  }
}
