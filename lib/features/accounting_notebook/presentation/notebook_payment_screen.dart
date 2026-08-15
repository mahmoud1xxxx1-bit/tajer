import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_terminology.dart';

class NotebookPaymentScreen extends ConsumerStatefulWidget {
  final String personId;
  final bool isReceivablePayment;

  const NotebookPaymentScreen({
    super.key,
    required this.personId,
    required this.isReceivablePayment,
  });

  @override
  ConsumerState<NotebookPaymentScreen> createState() =>
      _NotebookPaymentScreenState();
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
    final title = widget.isReceivablePayment
        ? NotebookTerminology.receivePayment(context)
        : NotebookTerminology.makePayment(context);
    final partialLabel = widget.isReceivablePayment
        ? NotebookTerminology.partialReceivePayment(context)
        : NotebookTerminology.partialMakePayment(context);
    final fullLabel = widget.isReceivablePayment
        ? NotebookTerminology.fullReceivePayment(context)
        : NotebookTerminology.fullMakePayment(context);
    final peopleAsync = ref.watch(notebookPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: peopleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
        data: (people) {
          final matches =
              people.where((p) => p.id == widget.personId).toList();
          if (matches.isEmpty) {
            return Center(child: Text(l10n.notebookNoData));
          }
          final person = matches.first;
          final bookId = person.bookId;
          final maxAmount = widget.isReceivablePayment
              ? person.amountOwedToMe
              : person.amountIOwe;

          if (maxAmount <= 0) {
            return Center(child: Text(l10n.notebookNoData));
          }

          final accountsAsync = ref.watch(notebookAccountsProvider);
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
            data: (allAccounts) {
              final accounts = allAccounts
                  .where((a) => a.bookId == bookId && !a.isArchived)
                  .toList();
              if (accounts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.notebookEmptyAccounts,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(notebookCurrentBookIdProvider.notifier)
                              .state = bookId;
                          context.push('/notebook/accounts');
                        },
                        child: Text(l10n.notebookCreateAccountCTA),
                      ),
                    ],
                  ),
                );
              }

              if (_selectedAccountId == null ||
                  !accounts.any((a) => a.id == _selectedAccountId)) {
                _selectedAccountId = accounts.first.id;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('${l10n.notebookPersonName}: ${person.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${l10n.amount}: ${maxAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedAccountId,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l10n.account),
                          items: accounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedAccountId = value),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _amountController.clear(),
                                child: Text(partialLabel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _amountController.text =
                                    maxAmount.toStringAsFixed(2),
                                child: Text(fullLabel),
                              ),
                            ),
                          ],
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
                            if (amount > maxAmount) {
                              return l10n.notebookOverpaymentError;
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
                        ElevatedButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            final amount = double.parse(_amountController.text);
                            try {
                              await ref
                                  .read(accountingNotebookProvider)
                                  .recordDebtPayment(
                                    bookId: bookId,
                                    personId: widget.personId,
                                    accountId: _selectedAccountId!,
                                    amount: amount,
                                    isReceivablePayment:
                                        widget.isReceivablePayment,
                                    note: _noteController.text.trim(),
                                  );
                              if (mounted) context.pop();
                            } catch (error) {
                              if (!mounted) return;
                              if (error
                                  .toString()
                                  .contains('insufficient_balance')) {
                                final account = accounts.firstWhere(
                                    (a) => a.id == _selectedAccountId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.notebookInsufficientBalance(
                                        account.balance.toStringAsFixed(2),
                                        amount.toStringAsFixed(2),
                                      ),
                                    ),
                                  ),
                                );
                              } else if (error
                                  .toString()
                                  .contains('overpayment')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(l10n.notebookOverpaymentError)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(l10n.genericErrorPrefix)),
                                );
                              }
                            }
                          },
                          child: Text(title),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
