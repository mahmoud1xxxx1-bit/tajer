import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../../../../core/services/guest_limit_service.dart';
import '../utils/notebook_localization_helper.dart';
import '../utils/notebook_terminology.dart';

class NotebookPersonStatementScreen extends ConsumerWidget {
  final String personId;
  const NotebookPersonStatementScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final transactionsAsync = ref.watch(notebookTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookStatement)),
      body: peopleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
        data: (people) {
          final matches = people.where((p) => p.id == personId).toList();
          if (matches.isEmpty) {
            return Center(child: Text(l10n.notebookNoData));
          }
          final person = matches.first;
          final netBalance = person.amountOwedToMe - person.amountIOwe;

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        person.isArchived
                            ? '${person.name} (${l10n.notebookArchived})'
                            : person.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (person.notes != null && person.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(person.notes!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: Column(
                              children: [
                                Text(
                                  NotebookTerminology.totalAccountsReceivable(
                                      context),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.green),
                                ),
                                const SizedBox(height: 4),
                                Text(person.amountOwedToMe.toStringAsFixed(2),
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              children: [
                                Text(
                                  NotebookTerminology.totalAccountsPayable(
                                      context),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 4),
                                Text(person.amountIOwe.toStringAsFixed(2),
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(l10n.notebookNetBalance,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        netBalance.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: netBalance > 0
                              ? Colors.green
                              : (netBalance < 0 ? Colors.red : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      Center(child: Text(l10n.genericErrorPrefix)),
                  data: (allTransactions) {
                    final transactions = allTransactions
                        .where((tx) =>
                            tx.personId == personId && tx.bookId == person.bookId)
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    if (transactions.isEmpty) {
                      return Center(
                          child: Text(l10n.notebookNoTransactionsYet));
                    }

                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isPositive = tx.type == 'receivable' ||
                            tx.type == 'payable_payment';
                        return ListTile(
                          title: Text(NotebookLocalizationHelper
                              .getNotebookLocalizedTypeCustom(tx.type, l10n)),
                          subtitle: Text(
                            '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? ' - ${tx.note}' : ''}',
                          ),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call_received),
                        onPressed: !person.isArchived && person.amountOwedToMe > 0
                            ? () async {
                                if (await GuestLimitService
                                    .canAddNotebookTransaction(context, ref)) {
                                  ref
                                      .read(notebookCurrentBookIdProvider.notifier)
                                      .state = person.bookId;
                                  if (context.mounted) {
                                    context.push(
                                        '/notebook/payment/$personId/true');
                                  }
                                }
                              }
                            : null,
                        label: Text(
                            NotebookTerminology.receivePayment(context)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call_made),
                        onPressed: !person.isArchived && person.amountIOwe > 0
                            ? () async {
                                if (await GuestLimitService
                                    .canAddNotebookTransaction(context, ref)) {
                                  ref
                                      .read(notebookCurrentBookIdProvider.notifier)
                                      .state = person.bookId;
                                  if (context.mounted) {
                                    context.push(
                                        '/notebook/payment/$personId/false');
                                  }
                                }
                              }
                            : null,
                        label:
                            Text(NotebookTerminology.makePayment(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
