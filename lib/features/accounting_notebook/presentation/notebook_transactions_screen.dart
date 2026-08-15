import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            child: Builder(
              builder: (context) {
                final repo = ref.watch(accountingNotebookRepositoryProvider);
                if (repo == null) return const Center(child: CircularProgressIndicator());
                
                var query = repo.transactionsRef.orderBy('date', descending: true);
                
                if (_selectedType != null) query = query.where('type', isEqualTo: _selectedType);
                if (_selectedBookId != null) query = query.where('bookId', isEqualTo: _selectedBookId);
                if (_selectedAccountId != null) query = query.where('accountId', isEqualTo: _selectedAccountId);
                if (_selectedPersonId != null) query = query.where('personId', isEqualTo: _selectedPersonId);
                if (_selectedCategoryId != null) query = query.where('categoryId', isEqualTo: _selectedCategoryId);
                if (_startDate != null) query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
                if (_endDate != null) query = query.where('date', isLessThan: Timestamp.fromDate(_endDate!));
                
                final typedQuery = query.withConverter<NotebookTransaction>(
                  fromFirestore: (snapshot, _) => NotebookTransaction.fromMap(snapshot.data()!, snapshot.id),
                  toFirestore: (tx, _) => tx.toMap(),
                );
                
                return FirestoreListView<NotebookTransaction>(
                  query: typedQuery,
                  pageSize: 50,
                  emptyBuilder: (context) => Center(child: Text(l10n.notebookNoTransactionsYet)),
                  loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stackTrace) => Center(child: Text('${l10n.genericErrorPrefix}: $error')),
                  itemBuilder: (context, doc) {
                    final tx = doc.data();
                    final isPositive = tx.type == 'income' || tx.type == 'receivable_payment';
                    final isNeutral = tx.type == 'opening_balance' || tx.type == 'account_transfer';
                    
                    final typeStr = NotebookLocalizationHelper.getNotebookLocalizedTypeCustom(tx.type, l10n);
                    final bookStr = booksAsync.value?.where((b) => b.id == tx.bookId).firstOrNull?.name ?? '...';
                    final accStr = getAccountName(tx.accountId);
                    
                    String? targetStr;
                    if (tx.type == 'account_transfer') {
                      final toAccStr = getAccountName(tx.toAccountId);
                      targetStr = '${l10n.notebookTransfer}: $accStr -> $toAccStr';
                    } else if (tx.personId != null) {
                      targetStr = '${l10n.notebookPerson}: ${getPersonName(tx.personId)}';
                    } else if (tx.categoryId != null) {
                      targetStr = '${l10n.notebookCategory}: ${getCategoryName(tx.categoryId)}';
                    }
                    
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
                            if (targetStr != null && tx.type != 'account_transfer') 
                              Text(targetStr, style: const TextStyle(fontSize: 13)),
                            if (tx.type == 'account_transfer')
                              Text(targetStr ?? '', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
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
              }
            ),
          ),
        ],
      ),
    );
  }
}