import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookTransactionsScreen extends ConsumerWidget {
  const NotebookTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final txAsync = ref.watch(notebookTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransactions ?? 'الحركات')),
      body: txAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(child: Text(l10n.notebookNoTransactionsYet));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isPositive = tx.type == 'income' || tx.type == 'receivable_payment';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(tx.note ?? tx.type),
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
    );
  }
}
