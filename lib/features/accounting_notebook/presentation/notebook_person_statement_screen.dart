import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/notebook_transaction.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../../../core/services/guest_limit_service.dart';
import '../utils/notebook_localization_helper.dart';

class NotebookPersonStatementScreen extends ConsumerWidget {
  final String personId;
  const NotebookPersonStatementScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final txsAsync = ref.watch(notebookTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookStatement )),
      body: peopleAsync.when(
        data: (people) {
          final person = people.firstWhere((p) => p.id == personId);
          final netBalance = person.amountOwedToMe - person.amountIOwe;
          
          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(person.name, style: Theme.of(context).textTheme.headlineSmall),
                      if (person.notes != null && person.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          person.notes!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(l10n.notebookTotalOwedToMe, style: const TextStyle(color: Colors.green)),
                              const SizedBox(height: 4),
                              Text(person.amountOwedToMe.toStringAsFixed(2), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(l10n.notebookTotalIOwe, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 4),
                              Text(person.amountIOwe.toStringAsFixed(2), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          Text(l10n.notebookNetBalance, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            netBalance.toStringAsFixed(2), 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 20,
                              color: netBalance > 0 ? Colors.green : (netBalance < 0 ? Colors.red : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
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

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: person.amountOwedToMe > 0
                              ? () async { if (await GuestLimitService.canAddNotebookTransaction(context, ref)) context.push('/notebook/payment/$personId/true'); }
                              : null,
                        child: Text(l10n.notebookPayment),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: person.amountIOwe > 0
                              ? () async { if (await GuestLimitService.canAddNotebookTransaction(context, ref)) context.push('/notebook/payment/$personId/false'); }
                              : null,
                        child: Text(l10n.notebookPayment),
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.genericErrorPrefix}: $e')),
      ),
    );
  }
}
