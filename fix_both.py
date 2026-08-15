import os

# 1. Fix person statement screen
file1 = "lib/features/accounting_notebook/presentation/notebook_person_statement_screen.dart"
with open(file1, "r", encoding="utf-8") as f:
    code = f.read()

# Add imports
if "firebase_ui_firestore.dart" not in code:
    code = code.replace("import 'package:intl/intl.dart';", "import 'package:intl/intl.dart';\nimport 'package:firebase_ui_firestore/firebase_ui_firestore.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';\nimport '../domain/notebook_transaction.dart';\nimport '../data/accounting_notebook_repository.dart';")
elif "accounting_notebook_repository.dart" not in code:
    code = code.replace("import '../data/accounting_notebook_provider.dart';", "import '../data/accounting_notebook_provider.dart';\nimport '../data/accounting_notebook_repository.dart';")

start_idx = code.find("              Expanded(")
end_idx = code.rfind("              Padding(")

new_body1 = """              Expanded(
                child: Builder(
                  builder: (context) {
                    final repo = ref.watch(accountingNotebookRepositoryProvider);
                    if (repo == null) return const Center(child: CircularProgressIndicator());
                    
                    final query = repo.transactionsRef
                        .where('personId', isEqualTo: personId)
                        .orderBy('date', descending: true)
                        .withConverter<NotebookTransaction>(
                          fromFirestore: (snapshot, _) => NotebookTransaction.fromMap(snapshot.data()!, snapshot.id),
                          toFirestore: (tx, _) => tx.toMap(),
                        );
                        
                    return FirestoreListView<NotebookTransaction>(
                      query: query,
                      pageSize: 50,
                      emptyBuilder: (context) => Center(child: Text(l10n.notebookNoTransactionsYet)),
                      loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) => Center(child: Text('${l10n.genericErrorPrefix}: $error')),
                      itemBuilder: (context, doc) {
                        final tx = doc.data();
                        final isPositive = tx.type == 'receivable' || tx.type == 'payable_payment';
                        return ListTile(
                          title: Text(NotebookLocalizationHelper.getNotebookLocalizedTypeCustom(tx.type, l10n)),
                          subtitle: Text('${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? ' - ${tx.note}' : ''}'),
                          trailing: Text(
                            '${isPositive ? '+' : '-'}${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
"""
if start_idx != -1 and end_idx != -1 and "Builder(" not in code[start_idx:end_idx]:
    code = code[:start_idx] + new_body1 + code[end_idx:]

with open(file1, "w", encoding="utf-8") as f:
    f.write(code)

# 2. Fix transactions screen
file2 = "lib/features/accounting_notebook/presentation/notebook_transactions_screen.dart"
with open(file2, "r", encoding="utf-8") as f:
    code = f.read()

if "firebase_ui_firestore.dart" not in code:
    code = code.replace("import 'package:intl/intl.dart';", "import 'package:intl/intl.dart';\nimport 'package:firebase_ui_firestore/firebase_ui_firestore.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';\nimport '../domain/notebook_transaction.dart';\nimport '../data/accounting_notebook_repository.dart';")
elif "accounting_notebook_repository.dart" not in code:
    code = code.replace("import '../data/accounting_notebook_provider.dart';", "import '../data/accounting_notebook_provider.dart';\nimport '../data/accounting_notebook_repository.dart';\nimport '../domain/notebook_transaction.dart';")

start_idx2 = code.find("          Expanded(", code.find("Expanded(") + 10)
end_idx2 = code.find("        ],", start_idx2)

new_body2 = """          Expanded(
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
"""

if start_idx2 != -1 and end_idx2 != -1 and "Builder(" not in code[start_idx2:end_idx2]:
    code = code[:start_idx2] + new_body2 + code[end_idx2:]

with open(file2, "w", encoding="utf-8") as f:
    f.write(code)

