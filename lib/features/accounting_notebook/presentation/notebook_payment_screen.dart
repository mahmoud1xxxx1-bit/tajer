import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookPaymentScreen extends ConsumerStatefulWidget {
  final String personId;
  final bool isReceivablePayment;
  
  const NotebookPaymentScreen({
    super.key,
    required this.personId,
    required this.isReceivablePayment,
  });

  @override
  ConsumerState<NotebookPaymentScreen> createState() => _NotebookPaymentScreenState();
}

class _NotebookPaymentScreenState extends ConsumerState<NotebookPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isReceivablePayment ? l10n.notebookPayment : l10n.notebookPaymentOfDebt;
    
    final peopleAsync = ref.watch(notebookPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: peopleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
        data: (people) {
          final personOpt = people.where((p) => p.id == widget.personId).toList();
          if (personOpt.isEmpty) {
            return Center(child: Text(l10n.notebookNoData));
          }
          final person = personOpt.first;
          final bookId = person.bookId;
          final double maxAmount = widget.isReceivablePayment ? person.amountOwedToMe : person.amountIOwe;

          final accountsAsync = ref.watch(notebookAccountsProvider);
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
            data: (allAccounts) {
              final accounts = allAccounts.where((a) => a.bookId == bookId && !(a.isArchived ?? false)).toList();
              if (accounts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.notebookEmptyAccounts, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/notebook/accounts'),
                        child: Text(l10n.notebookCreateAccountCTA),
                      )
                    ],
                  ),
                );
              }

              if (_selectedAccountId == null || !accounts.any((a) => a.id == _selectedAccountId)) {
                _selectedAccountId = accounts.first.id;
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${l10n.notebookPersonName}: ${person.name}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${l10n.amount}: ${maxAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
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
                                _amountController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.notebookPartialPaymentHint)));
                              },
                              child: Text(l10n.notebookPartialPayment ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _amountController.text = maxAmount.toStringAsFixed(2);
                              },
                              child: Text(l10n.notebookFullPayment ),
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
                          if (val == null || val.isEmpty) return l10n.notebookRequired;
                          if (double.tryParse(val) == null || double.parse(val) <= 0) return l10n.notebookInvalidAmount;
                          if (double.parse(val) > maxAmount) return l10n.notebookOverpaymentError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(labelText: l10n.notebookNote),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final amt = double.parse(_amountController.text);
                            final svc = ref.read(accountingNotebookProvider);
                            try {
                              await svc.recordDebtPayment(
                                bookId: bookId, 
                                personId: widget.personId,
                                accountId: _selectedAccountId!,
                                amount: amt, 
                                isReceivablePayment: widget.isReceivablePayment,
                                note: _noteController.text
                              );
                              if (mounted) context.pop();
                            } catch (e) {
                              if (e.toString().contains('insufficient_balance')) {
                                final selectedAccount = accounts.firstWhere((a) => a.id == _selectedAccountId);
                                final msg = l10n.notebookInsufficientBalance
                                    .replaceAll('{balance}', selectedAccount.balance.toStringAsFixed(2))
                                    .replaceAll('{amount}', amt.toStringAsFixed(2));
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.genericErrorPrefix}: $e')));
                              }
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
      ),
    );
  }
}
