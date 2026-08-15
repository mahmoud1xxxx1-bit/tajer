import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../data/notebook_flow_context.dart';

class IncomeExpenseScreen extends ConsumerStatefulWidget {
  final bool isIncome;
  const IncomeExpenseScreen({super.key, required this.isIncome});

  @override
  ConsumerState<IncomeExpenseScreen> createState() =>
      _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends ConsumerState<IncomeExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedBookId;
  String? _selectedAccountId;
  String? _selectedCategoryId;

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
      _selectedAccountId = null;
      _selectedCategoryId = null;
    });
  }

  Widget _emptyState(
    BuildContext context,
    String message,
    String buttonText,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: action, child: Text(buttonText)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isIncome ? l10n.income : l10n.expense;
    final booksAsync = ref.watch(notebookBooksProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final categoriesAsync = ref.watch(notebookCategoriesProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
        data: (books) {
          final activeBooks = books.where((b) => !b.isArchived).toList();
          if (activeBooks.isEmpty) {
            return Center(
              child: _emptyState(
                context,
                l10n.notebookEmptyBooks,
                l10n.notebookCreateBookCTA,
                () => context.push('/notebook/books'),
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
                        l10n.notebookGuideIncomeExpense,
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

                  if (accounts.isEmpty) {
                    return _emptyState(
                      context,
                      l10n.notebookEmptyAccounts,
                      l10n.notebookCreateAccountCTA,
                      () {
                        ref
                            .read(notebookCurrentBookIdProvider.notifier)
                            .state = selectedBookId;
                        context.push('/notebook/accounts');
                      },
                    );
                  }

                  if (_selectedAccountId == null ||
                      !accounts.any((a) => a.id == _selectedAccountId)) {
                    _selectedAccountId = accounts.first.id;
                  }

                  return categoriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        Center(child: Text(l10n.genericErrorPrefix)),
                    data: (allCategories) {
                      final expectedType = widget.isIncome ? 'income' : 'expense';
                      final categories = allCategories
                          .where((c) =>
                              c.bookId == selectedBookId &&
                              c.type == expectedType &&
                              !c.isArchived)
                          .toList();

                      if (categories.isEmpty) {
                        return _emptyState(
                          context,
                          l10n.notebookNoCategoriesFound,
                          l10n.notebookAddCategory,
                          () {
                            ref
                                .read(notebookCurrentBookIdProvider.notifier)
                                .state = selectedBookId;
                            ref
                                .read(notebookPendingCategoryTypeProvider.notifier)
                                .state = expectedType;
                            context.push('/notebook/categories');
                          },
                        );
                      }

                      if (_selectedCategoryId == null ||
                          !categories
                              .any((c) => c.id == _selectedCategoryId)) {
                        _selectedCategoryId = categories.first.id;
                      }

                      return Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedAccountId,
                              isExpanded: true,
                              decoration:
                                  InputDecoration(labelText: l10n.account),
                              items: accounts
                                  .map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(a.name,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(
                                  () => _selectedAccountId = value),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: l10n.notebookCategories),
                              items: categories
                                  .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(
                                  () => _selectedCategoryId = value),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _amountController,
                              decoration:
                                  InputDecoration(labelText: l10n.amount),
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
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _noteController,
                              decoration:
                                  InputDecoration(labelText: l10n.note),
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
                                    final service =
                                        ref.read(accountingNotebookProvider);
                                    if (widget.isIncome) {
                                      await service.createIncome(
                                        bookId: selectedBookId,
                                        accountId: _selectedAccountId!,
                                        amount: amount,
                                        categoryId: _selectedCategoryId!,
                                        note: _noteController.text.trim(),
                                      );
                                    } else {
                                      await service.createExpense(
                                        bookId: selectedBookId,
                                        accountId: _selectedAccountId!,
                                        amount: amount,
                                        categoryId: _selectedCategoryId!,
                                        note: _noteController.text.trim(),
                                      );
                                    }
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
