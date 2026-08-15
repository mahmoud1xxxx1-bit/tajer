import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_localization_helper.dart';

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
  

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final txAsync = ref.watch(notebookTransactionsProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final booksAsync = ref.watch(notebookBooksProvider);
    final categoriesAsync = ref.watch(notebookCategoriesProvider);

    final accounts = accountsAsync.value?.where((a) => _selectedBookId == null || a.bookId == _selectedBookId).toList() ?? [];
    final people = peopleAsync.value?.where((p) => _selectedBookId == null || p.bookId == _selectedBookId).toList() ?? [];
    final categories = categoriesAsync.value?.where((c) => _selectedBookId == null || c.bookId == _selectedBookId).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransactions)),
      body: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(l10n.notebookFilterType, style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.filter_list),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // TYPE FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedType,
                          decoration: InputDecoration(labelText: l10n.notebookFilterType, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'income', child: Text(l10n.income, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'expense', child: Text(l10n.expense, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'receivable', child: Text(l10n.moneyOwedToMe, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'payable', child: Text(l10n.moneyIOwe, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'receivable_payment', child: Text(l10n.notebookReceivePayment, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'payable_payment', child: Text(l10n.notebookPayPayment, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'account_transfer', child: Text(l10n.notebookTransfer, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => _selectedType = val),
                        ),
                      ),
                      // BOOK FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedBookId,
                          decoration: InputDecoration(labelText: l10n.notebookFilterBook, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...booksAsync.maybeWhen(
                              data: (books) => books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )
                          ],
                          onChanged: (val) => setState(() => _selectedBookId = val),
                        ),
                      ),
                      // ACCOUNT FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedAccountId,
                          decoration: InputDecoration(labelText: l10n.notebookFilterAccount, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (val) => setState(() => _selectedAccountId = val),
                        ),
                      ),
                      // PERSON FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedPersonId,
                          decoration: InputDecoration(labelText: l10n.notebookPerson, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (val) => setState(() => _selectedPersonId = val),
                        ),
                      ),
                      // CATEGORY FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(labelText: l10n.notebookCategory, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                      // ACTIONS
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.date_range, color: Colors.blue),
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
                                icon: const Icon(Icons.clear, color: Colors.red),
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
                    ],
                  ),
                ),
              ],
            ),
          ),          const Divider(),
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
                        title: Text(tx.note ?? getNotebookLocalizedType(context, tx.type)),
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