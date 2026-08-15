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
  String? _selectedBookId;
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isIncome ? l10n.income : l10n.expense;
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final booksAsync = ref.watch(notebookBooksProvider);
    final categoriesAsync = ref.watch(notebookCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
        data: (accounts) {
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
          if (_selectedAccountId == null) _selectedAccountId = accounts.first.id;

          return booksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
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
              if (_selectedBookId == null) _selectedBookId = books.first.id;

              return categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                data: (allCats) {
                  final cats = allCats.where((c) => c.type == (widget.isIncome ? 'income' : 'expense')).toList();
                  if (cats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.notebookNoCategoriesFound, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push('/notebook/categories'),
                            child: Text(l10n.add),
                          )
                        ],
                      ),
                    );
                  }
                  if (_selectedCategoryId == null || !cats.any((c) => c.id == _selectedCategoryId)) {
                    _selectedCategoryId = cats.first.id;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(widget.isIncome ? l10n.notebookIncomeHint : l10n.notebookExpenseHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(initialValue: _selectedBookId,
                            decoration: InputDecoration(labelText: l10n.notebookBooks),
                            items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                            onChanged: (val) => setState(() => _selectedBookId = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(initialValue: _selectedAccountId,
                            decoration: InputDecoration(labelText: l10n.account),
                            items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                            onChanged: (val) => setState(() => _selectedAccountId = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(initialValue: _selectedCategoryId,
                            decoration: InputDecoration(labelText: l10n.notebookCategories),
                            items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (val) => setState(() => _selectedCategoryId = val),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(labelText: l10n.amount),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty) return l10n.notebookRequired;
                              if (double.tryParse(val) == null || double.parse(val) <= 0) return l10n.notebookInvalidAmount;
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
                                  
                                  try {
                                    if (widget.isIncome) {
                                      await svc.createIncome(bookId: _selectedBookId!, accountId: _selectedAccountId!, amount: amt, categoryId: _selectedCategoryId!,  note: _noteController.text);
                                    } else {
                                      await svc.createExpense(bookId: _selectedBookId!, accountId: _selectedAccountId!, amount: amt, categoryId: _selectedCategoryId!,  note: _noteController.text);
                                    }
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
          );
        }
      ),
    );
  }
}
