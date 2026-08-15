import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookPaymentScreen extends ConsumerStatefulWidget {
  final String personId;
  final bool isReceivablePayment; // true = they are paying me back, false = I am paying them back
  const NotebookPaymentScreen({super.key, required this.personId, required this.isReceivablePayment});

  @override
  ConsumerState<NotebookPaymentScreen> createState() => _NotebookPaymentScreenState();
}

class _NotebookPaymentScreenState extends ConsumerState<NotebookPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isReceivablePayment ? (l10n.notebookPaymentOfDebt ?? 'Payment') : (l10n.notebookPaymentOfDebt ?? 'Payment');
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final booksAsync = ref.watch(notebookBooksProvider);
    
    // We should fetch the person to know max amount, but for now we just allow any amount.
    final peopleAsync = ref.watch(notebookPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(child: Text(l10n.notebookAccountsCreateFirst ?? 'Create an account first.'));
          }
          if (_selectedAccountId == null) _selectedAccountId = accounts.first.id;

          return booksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
            data: (books) {
              if (books.isEmpty) {
                return Center(child: Text(l10n.notebookCreateBookFirst ?? 'Create a book first.'));
              }
              if (_selectedBookId == null) _selectedBookId = books.first.id;

              return peopleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                data: (people) {
                  final person = people.firstWhere((p) => p.id == widget.personId);
                  final double maxAmount = widget.isReceivablePayment ? person.amountOwedToMe : person.amountIOwe;

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${l10n.notebookPersonName ?? 'Person'}: ${person.name}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('${l10n.amount ?? 'Debt Amount'}: ${maxAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedBookId,
                            decoration: InputDecoration(labelText: l10n.notebookBooks ?? 'Book'),
                            items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                            onChanged: (val) => setState(() => _selectedBookId = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: InputDecoration(labelText: l10n.account),
                            items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                            onChanged: (val) => setState(() => _selectedAccountId = val),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _amountController.text = (maxAmount / 2).toStringAsFixed(2);
                                  },
                                  child: Text(l10n.notebookPartialPayment ?? 'Partial Payment'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _amountController.text = maxAmount.toStringAsFixed(2);
                                  },
                                  child: Text(l10n.notebookFullPayment ?? 'Full Payment'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(labelText: l10n.amount),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Invalid amount';
                              if (double.parse(val) > maxAmount) return 'Amount exceeds debt';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _noteController,
                            decoration: InputDecoration(labelText: l10n.notebookNote ?? 'Note'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                final amt = double.parse(_amountController.text);
                                final svc = ref.read(accountingNotebookProvider);
                                try {
                                  await svc.recordDebtPayment(
                                    bookId: _selectedBookId!, 
                                    personId: widget.personId,
                                    accountId: _selectedAccountId!,
                                    amount: amt, 
                                    isReceivablePayment: widget.isReceivablePayment,
                                    note: _noteController.text
                                  );
                                  if (mounted) context.pop();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.genericErrorPrefix}: $e')));
                                }
                              }
                            },
                            child: Text(l10n.save),
                          )
                        ],
                      ),
                    ),
                  );
                }
              );
            }
          );
        }
      ),
    );
  }
}
