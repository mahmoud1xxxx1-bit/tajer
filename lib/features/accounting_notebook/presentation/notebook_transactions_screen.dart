import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../domain/notebook_account.dart';
import '../domain/notebook_book.dart';
import '../domain/notebook_category.dart';
import '../domain/notebook_person.dart';
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
    final allAccounts = ref.watch(notebookAccountsProvider).value ?? [];
    final allCategories = ref.watch(notebookCategoriesProvider).value ?? [];
    final allPeople = ref.watch(notebookPeopleProvider).value ?? [];

    String getAccountName(String? id) => allAccounts.firstWhere((a) => a.id == id, orElse: () => NotebookAccount(id: '', name: '...', type: '', balance: 0, bookId: '', createdAt: DateTime.now(), isArchived: false)).name;
    String getCategoryName(String? id) => allCategories.firstWhere((c) => c.id == id, orElse: () => NotebookCategory(id: '', name: '...', type: '', bookId: '', createdAt: DateTime.now(), isArchived: false)).name;
    String getPersonName(String? id) => allPeople.firstWhere((p) => p.id == id, orElse: () => NotebookPerson(id: '', name: '...', amountOwedToMe: 0, amountIOwe: 0, bookId: '', createdAt: DateTime.now(), isArchived: false)).name;

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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.notebookGuideTransactions,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
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
                    final isNeutral = tx.type == 'opening_balance' || tx.type == 'account_transfer';
                    
                    final typeStr = NotebookLocalizationHelper.getNotebookLocalizedTypeCustom(tx.type, l10n);
                    final bookStr = booksAsync.value?.where((b) => b.id == tx.bookId).firstOrNull?.name ?? '...';
                    final accStr = getAccountName(tx.accountId);
                    final personStr = tx.personId != null ? getPersonName(tx.personId) : null;
                    final catStr = tx.categoryId != null ? getCategoryName(tx.categoryId) : null;
                    final targetStr = personStr ?? catStr;
                    
                    // Date Format using locale
                    final dateStr = DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(tx.date);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(typeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  '${isNeutral ? '' : isPositive ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isNeutral ? Colors.blue : isPositive ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${l10n.notebookFilterBook}: $bookStr | ${l10n.notebookFilterAccount}: $accStr', style: const TextStyle(fontSize: 13)),
                            if (targetStr != null) 
                              Text('${tx.personId != null ? l10n.notebookPerson : l10n.notebookCategory}: $targetStr', style: const TextStyle(fontSize: 13)),
                            if (tx.note != null && tx.note!.isNotEmpty)
                              Text('${l10n.note}: ${tx.note}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
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