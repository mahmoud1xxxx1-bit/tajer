import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../data/accounting_notebook_repository.dart';
import '../utils/notebook_localization_helper.dart';
import '../utils/notebook_terminology.dart';

class NotebookTransactionsScreen extends ConsumerStatefulWidget {
  const NotebookTransactionsScreen({super.key});

  @override
  ConsumerState<NotebookTransactionsScreen> createState() =>
      _NotebookTransactionsScreenState();
}

class _NotebookTransactionsScreenState
    extends ConsumerState<NotebookTransactionsScreen> {
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPersonId;
  String? _selectedAccountId;
  String? _selectedBookId;
  String? _selectedCategoryId;
  bool _initializedBook = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final categoriesAsync = ref.watch(notebookCategoriesProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final repository = ref.watch(accountingNotebookRepositoryProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    final books = booksAsync.value ?? [];
    final activeBooks = books.where((b) => !b.isArchived).toList();
    if (!_initializedBook && activeBooks.isNotEmpty) {
      _initializedBook = true;
      if (sharedBookId != null &&
          activeBooks.any((b) => b.id == sharedBookId)) {
        _selectedBookId = sharedBookId;
      } else {
        _selectedBookId = activeBooks.first.id;
      }
    }

    final accounts = (accountsAsync.value ?? [])
        .where((a) => _selectedBookId == null || a.bookId == _selectedBookId)
        .toList();
    final categories = (categoriesAsync.value ?? [])
        .where((c) => _selectedBookId == null || c.bookId == _selectedBookId)
        .toList();
    final people = (peopleAsync.value ?? [])
        .where((p) => _selectedBookId == null || p.bookId == _selectedBookId)
        .toList();

    String accountName(String? id) => (accountsAsync.value ?? [])
            .where((a) => a.id == id)
            .map((a) => a.name)
            .firstOrNull ??
        '...';
    String categoryName(String? id) => (categoriesAsync.value ?? [])
            .where((c) => c.id == id)
            .map((c) => c.name)
            .firstOrNull ??
        '...';
    String personName(String? id) => (peopleAsync.value ?? [])
            .where((p) => p.id == id)
            .map((p) => p.name)
            .firstOrNull ??
        '...';
    String bookName(String id) => books
            .where((b) => b.id == id)
            .map((b) => b.name)
            .firstOrNull ??
        '...';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransactions)),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.notebookGuideTransactions,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(l10n.notebookFilterType,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.filter_list),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _filterBox(
                        context,
                        DropdownButtonFormField<String?>(
                          value: _selectedBookId,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: l10n.notebookFilterBook),
                          items: activeBooks
                              .map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedBookId = value;
                              _selectedAccountId = null;
                              _selectedPersonId = null;
                              _selectedCategoryId = null;
                            });
                            ref
                                .read(notebookCurrentBookIdProvider.notifier)
                                .state = value;
                          },
                        ),
                      ),
                      _filterBox(
                        context,
                        DropdownButtonFormField<String?>(
                          value: _selectedType,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: l10n.notebookFilterType),
                          items: [
                            DropdownMenuItem(
                                value: null, child: Text(l10n.notebookAll)),
                            DropdownMenuItem(
                                value: 'income', child: Text(l10n.income)),
                            DropdownMenuItem(
                                value: 'expense', child: Text(l10n.expense)),
                            DropdownMenuItem(
                                value: 'receivable',
                                child: Text(
                                    NotebookTerminology.accountsReceivable(
                                        context))),
                            DropdownMenuItem(
                                value: 'payable',
                                child: Text(
                                    NotebookTerminology.accountsPayable(
                                        context))),
                            DropdownMenuItem(
                                value: 'receivable_payment',
                                child: Text(
                                    NotebookTerminology.receivePayment(
                                        context))),
                            DropdownMenuItem(
                                value: 'payable_payment',
                                child: Text(NotebookTerminology.makePayment(
                                    context))),
                            DropdownMenuItem(
                                value: 'account_transfer',
                                child: Text(l10n.notebookTransfer)),
                            DropdownMenuItem(
                                value: 'opening_balance',
                                child: Text(l10n.notebookOpeningBalance)),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedType = value),
                        ),
                      ),
                      _filterBox(
                        context,
                        DropdownButtonFormField<String?>(
                          value: _selectedAccountId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: l10n.notebookFilterAccount),
                          items: [
                            DropdownMenuItem(
                                value: null, child: Text(l10n.notebookAll)),
                            ...accounts.map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name,
                                    overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedAccountId = value),
                        ),
                      ),
                      _filterBox(
                        context,
                        DropdownButtonFormField<String?>(
                          value: _selectedPersonId,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: l10n.notebookPerson),
                          items: [
                            DropdownMenuItem(
                                value: null, child: Text(l10n.notebookAll)),
                            ...people.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedPersonId = value),
                        ),
                      ),
                      _filterBox(
                        context,
                        DropdownButtonFormField<String?>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: l10n.notebookCategory),
                          items: [
                            DropdownMenuItem(
                                value: null, child: Text(l10n.notebookAll)),
                            ...categories.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name,
                                    overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCategoryId = value),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width < 600
                            ? MediaQuery.of(context).size.width * 0.42
                            : 260,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.date_range),
                              tooltip: l10n.notebookDateRange,
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDateRange:
                                      _startDate != null && _endDate != null
                                          ? DateTimeRange(
                                              start: _startDate!,
                                              end: _endDate!
                                                  .subtract(const Duration(days: 1)))
                                          : null,
                                );
                                if (range != null) {
                                  setState(() {
                                    _startDate = range.start;
                                    _endDate =
                                        range.end.add(const Duration(days: 1));
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l10n.notebookClearFilters,
                              onPressed: () => setState(() {
                                _selectedType = null;
                                _startDate = null;
                                _endDate = null;
                                _selectedPersonId = null;
                                _selectedAccountId = null;
                                _selectedCategoryId = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedBookId == null || repository == null
                ? Center(child: Text(l10n.notebookNoTransactionsYet))
                : FirestoreListView(
                    key: ValueKey(_selectedBookId),
                    query: repository.queryTransactions(
                        bookId: _selectedBookId!),
                    pageSize: 50,
                    padding: const EdgeInsets.only(bottom: 16),
                    emptyBuilder: (context) =>
                        Center(child: Text(l10n.notebookNoTransactionsYet)),
                    errorBuilder: (context, _, __) =>
                        Center(child: Text(l10n.genericErrorPrefix)),
                    loadingBuilder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                    itemBuilder: (context, doc) {
                      final tx = doc.data();
                      if (!_matchesFilters(tx)) {
                        return const SizedBox.shrink();
                      }

                      final isPositive = tx.type == 'income' ||
                          tx.type == 'receivable_payment';
                      final isNeutral = tx.type == 'opening_balance' ||
                          tx.type == 'account_transfer' ||
                          tx.type == 'receivable' ||
                          tx.type == 'payable';
                      final typeText = tx.type == 'receivable'
                          ? NotebookTerminology.accountsReceivable(context)
                          : tx.type == 'payable'
                              ? NotebookTerminology.accountsPayable(context)
                              : tx.type == 'receivable_payment'
                                  ? NotebookTerminology.receivePayment(context)
                                  : tx.type == 'payable_payment'
                                      ? NotebookTerminology.makePayment(context)
                                      : NotebookLocalizationHelper
                                          .getNotebookLocalizedTypeCustom(
                                              tx.type, l10n);
                      final dateText = DateFormat.yMMMd(
                              Localizations.localeOf(context).languageCode)
                          .format(tx.date);

                      String? detail;
                      if (tx.type == 'account_transfer') {
                        detail =
                            '${accountName(tx.accountId)} → ${accountName(tx.toAccountId)}';
                      } else if (tx.personId != null) {
                        detail = personName(tx.personId);
                      } else if (tx.categoryId != null) {
                        detail = categoryName(tx.categoryId);
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          title: Text(typeText,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${bookName(tx.bookId)} • $dateText${detail == null ? '' : ' • $detail'}${tx.note == null || tx.note!.isEmpty ? '' : '\n${tx.note}'}',
                          ),
                          isThreeLine: tx.note != null && tx.note!.isNotEmpty,
                          trailing: Text(
                            '${isNeutral ? '' : isPositive ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isNeutral
                                  ? Theme.of(context).colorScheme.primary
                                  : isPositive
                                      ? Colors.green
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(dynamic tx) {
    if (_selectedType != null && tx.type != _selectedType) return false;
    if (_selectedAccountId != null &&
        tx.accountId != _selectedAccountId &&
        tx.toAccountId != _selectedAccountId) return false;
    if (_selectedPersonId != null && tx.personId != _selectedPersonId) {
      return false;
    }
    if (_selectedCategoryId != null &&
        tx.categoryId != _selectedCategoryId) return false;
    if (_startDate != null && tx.date.isBefore(_startDate!)) return false;
    if (_endDate != null && !tx.date.isBefore(_endDate!)) return false;
    return true;
  }

  Widget _filterBox(BuildContext context, Widget child) {
    return SizedBox(
      width: MediaQuery.of(context).size.width < 600
          ? MediaQuery.of(context).size.width * 0.42
          : 260,
      child: child,
    );
  }
}
