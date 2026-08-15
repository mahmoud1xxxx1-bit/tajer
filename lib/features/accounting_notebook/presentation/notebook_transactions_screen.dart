import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookTransactionsScreen extends ConsumerStatefulWidget {
  const NotebookTransactionsScreen({super.key});

  @override
  ConsumerState<NotebookTransactionsScreen> createState() => _NotebookTransactionsScreenState();
}

class _NotebookTransactionsScreenState extends ConsumerState<NotebookTransactionsScreen> {
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPersonId;
  String? _selectedAccountId;
  String? _selectedBookId;
  String? _selectedCategoryId;

  @override
    String _getLocalizedType(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'income': return l10n.income;
      case 'expense': return l10n.expense;
      case 'receivable': return l10n.notebookReceivable ?? 'Receivable';
      case 'payable': return l10n.notebookPayable ?? 'Payable';
      case 'receivable_payment': return l10n.notebookPayment ?? 'Receivable Payment';
      case 'payable_payment': return l10n.notebookPaymentOfDebt ?? 'Payable Payment';
      case 'account_transfer': return l10n.notebookTransfer ?? 'Transfer';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final txAsync = ref.watch(notebookTransactionsProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final booksAsync = ref.watch(notebookBooksProvider);
    final categoriesAsync = ref.watch(notebookCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransactions)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // TYPE FILTER
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(initialValue: _selectedType,
                      decoration: InputDecoration(labelText: l10n.notebookTransactionType, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.notebookAll)),
                        DropdownMenuItem(value: 'income', child: Text(l10n.income)),
                        DropdownMenuItem(value: 'expense', child: Text(l10n.expense)),
                        DropdownMenuItem(value: 'receivable', child: Text(l10n.moneyOwedToMe)),
                        DropdownMenuItem(value: 'payable', child: Text(l10n.moneyIOwe)),
                        DropdownMenuItem(value: 'receivable_payment', child: Text(l10n.notebookPayment)),
                        DropdownMenuItem(value: 'account_transfer', child: Text(l10n.notebookTransfer)),
                      ],
                      onChanged: (val) => setState(() => _selectedType = val),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // BOOK FILTER
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(initialValue: _selectedBookId,
                      decoration: InputDecoration(labelText: l10n.notebookBook, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.notebookAll)),
                        ...booksAsync.maybeWhen(
                          data: (books) => books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                          orElse: () => [],
                        )
                      ],
                      onChanged: (val) => setState(() => _selectedBookId = val),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ACCOUNT FILTER
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(initialValue: _selectedAccountId,
                      decoration: InputDecoration(labelText: l10n.notebookAccount, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.notebookAll)),
                        ...accountsAsync.maybeWhen(
                          data: (accs) => accs.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                          orElse: () => [],
                        )
                      ],
                      onChanged: (val) => setState(() => _selectedAccountId = val),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // PERSON FILTER
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(initialValue: _selectedPersonId,
                      decoration: InputDecoration(labelText: l10n.notebookPerson, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.notebookAll)),
                        ...peopleAsync.maybeWhen(
                          data: (pep) => pep.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                          orElse: () => [],
                        )
                      ],
                      onChanged: (val) => setState(() => _selectedPersonId = val),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // CATEGORY FILTER
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(initialValue: _selectedCategoryId,
                      decoration: InputDecoration(labelText: l10n.notebookCategory, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.notebookAll)),
                        ...categoriesAsync.maybeWhen(
                          data: (cats) => cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          orElse: () => [],
                        )
                      ],
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                  ),
                  const SizedBox(width: 8),

                  IconButton(
                    icon: const Icon(Icons.date_range),
                    tooltip: l10n.notebookDateRange,
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: _startDate != null && _endDate != null
                            ? DateTimeRange(start: _startDate!, end: _endDate!)
                            : null,
                      );
                      if (range != null) {
                        setState(() {
                          _startDate = range.start;
                          _endDate = range.end.add(const Duration(days: 1)); // inclusive
                        });
                      }
                    },
                  ),
                  if (_selectedType != null || _startDate != null || _selectedPersonId != null || _selectedAccountId != null || _selectedBookId != null || _selectedCategoryId != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.notebookClearFilters,
                      onPressed: () => setState(() {
                        _selectedType = null;
                        _startDate = null;
                        _endDate = null;
                        _selectedPersonId = null;
                        _selectedAccountId = null;
                        _selectedBookId = null;
                        _selectedCategoryId = null;
                      }),
                    )
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: txAsync.when(
              data: (transactions) {
                var filtered = transactions;
                if (_selectedType != null) {
                  filtered = filtered.where((t) => t.type == _selectedType).toList();
                }
                if (_startDate != null && _endDate != null) {
                  filtered = filtered.where((t) => t.date.isAfter(_startDate!) && t.date.isBefore(_endDate!)).toList();
                }
                if (_selectedPersonId != null) {
                  filtered = filtered.where((t) => t.personId == _selectedPersonId).toList();
                }
                if (_selectedAccountId != null) {
                  filtered = filtered.where((t) => t.accountId == _selectedAccountId).toList();
                }
                if (_selectedBookId != null) {
                  filtered = filtered.where((t) => t.bookId == _selectedBookId).toList();
                }
                if (_selectedCategoryId != null) {
                  filtered = filtered.where((t) => t.categoryId == _selectedCategoryId).toList();
                }

                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.notebookNoTransactionsYet));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final isPositive = tx.type == 'income' || tx.type == 'receivable_payment';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(tx.note ?? _getLocalizedType(context, tx.type)),
                        subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                        trailing: Text(
                          '${isPositive ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('${l10n.genericErrorPrefix}: $e')),
            ),
          ),
        ],
      ),
    );
  }
}