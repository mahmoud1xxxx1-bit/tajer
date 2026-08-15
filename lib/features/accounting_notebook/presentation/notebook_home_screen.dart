import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookHomeScreen extends ConsumerWidget {
  const NotebookHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final transactionsAsync = ref.watch(notebookTransactionsProvider);
    
    double netBalance = 0.0;
    accountsAsync.whenData((accounts) {
      for (var acc in accounts) {
        netBalance += acc.balance;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notebookTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backToTajer,
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(l10n.netBalance, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    accountsAsync.when(
                      data: (_) => Text(
                        NumberFormat.currency(symbol: 'SAR ').format(netBalance),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: netBalance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (err, stack) => Text('Error: $err'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildActionCard(context, Icons.arrow_downward, l10n.income, Colors.green, () => context.push('/notebook/income'))),
                const SizedBox(width: 16),
                Expanded(child: _buildActionCard(context, Icons.arrow_upward, l10n.expense, Colors.red, () => context.push('/notebook/expense'))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildActionCard(context, Icons.person_add, l10n.moneyOwedToMe, Colors.blue, () => context.push('/notebook/debt/me'))),
                const SizedBox(width: 16),
                Expanded(child: _buildActionCard(context, Icons.person_remove, l10n.moneyIOwe, Colors.orange, () => context.push('/notebook/debt/owe'))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildActionCard(context, Icons.account_balance, l10n.notebookAccounts, Colors.purple, () => context.push('/notebook/accounts'))),
                const SizedBox(width: 16),
                Expanded(child: _buildActionCard(context, Icons.people, l10n.notebookPeople, Colors.teal, () => context.push('/notebook/people'))),
                const SizedBox(width: 16),
                Expanded(child: _buildActionCard(context, Icons.bar_chart, l10n.notebookReports, Colors.brown, () => context.push('/notebook/reports'))),
              ],
            ),
            const SizedBox(height: 32),
            Text(l10n.recentTransactions, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) return const Center(child: Text('No transactions yet'));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length > 5 ? 5 : transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isPositive = tx.type == 'income' || tx.type == 'receivable_payment';
                    return ListTile(
                      title: Text(tx.note ?? tx.type),
                      subtitle: Text(DateFormat.yMMMd().format(tx.date)),
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
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
