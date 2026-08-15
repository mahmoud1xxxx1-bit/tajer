import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.notebookTotalOwedToMe),
                          Text(person.amountOwedToMe.toStringAsFixed(2), style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.notebookTotalIOwe),
                          Text(person.amountIOwe.toStringAsFixed(2), style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.notebookNetBalance),
                          Text(
                            netBalance.toStringAsFixed(2), 
                            style: TextStyle(fontWeight: FontWeight.bold, color: netBalance >= 0 ? Colors.green : Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: txsAsync.when(
                  data: (txs) {
                    final personTxs = txs.where((t) => t.personId == personId).toList();
                    if (personTxs.isEmpty) return Center(child: Text(l10n.notebookNoTransactionsYet));
                    return ListView.builder(
                      itemCount: personTxs.length,
                      itemBuilder: (context, index) {
                        final tx = personTxs[index];
                        final isPositive = tx.type == 'receivable' || tx.type == 'payable_payment';
                        return ListTile(
                          title: Text(getNotebookLocalizedType(context, tx.type)),
                          subtitle: Text('${DateFormat.yMMMd().format(tx.date)} - ${tx.note }'),
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
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('${l10n.genericErrorPrefix}: $e')),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: person.amountOwedToMe > 0 
                          ? () => context.push('/notebook/payment/$personId/true') // Receive payment
                          : null,
                        child: Text(l10n.notebookPayment),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: person.amountIOwe > 0 
                          ? () => context.push('/notebook/payment/$personId/false') // Make payment
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
