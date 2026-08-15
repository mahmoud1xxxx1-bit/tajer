import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class IncomeExpenseScreen extends ConsumerStatefulWidget {
  final bool isIncome;
  const IncomeExpenseScreen({super.key, required this.isIncome});

  @override
  ConsumerState<IncomeExpenseScreen> createState() => _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends ConsumerState<IncomeExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  
  // Hardcoded book and category for V1 if not selected, but we should let user select
  // For simplicity, we just pick the first available.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isIncome ? l10n.income : l10n.expense;
    final accountsAsync = ref.watch(notebookAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.notebookAccountsCreateFirst));
          }
          if (_selectedAccountId == null) _selectedAccountId = accounts.first.id;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    decoration: InputDecoration(labelText: l10n.account),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (val) => setState(() => _selectedAccountId = val),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: l10n.amount),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(labelText: l10n.note),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final amt = double.parse(_amountController.text);
                          final svc = ref.read(accountingNotebookProvider);
                          
                          // V1 default book/category
                          final bookId = 'default_book';
                          final catId = 'default_category';
                          
                          try {
                            if (widget.isIncome) {
                              await svc.createIncome(bookId: bookId, accountId: _selectedAccountId!, amount: amt, categoryId: catId, note: _noteController.text);
                            } else {
                              await svc.createExpense(bookId: bookId, accountId: _selectedAccountId!, amount: amt, categoryId: catId, note: _noteController.text);
                            }
                            if (mounted) context.pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $e')));
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
      ),
    );
  }
}
