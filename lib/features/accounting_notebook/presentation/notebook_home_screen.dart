import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_localization_helper.dart';
import '../../../../core/services/guest_limit_service.dart';
import '../../../../core/providers/settings_provider.dart';

class NotebookHomeScreen extends ConsumerWidget {
  const NotebookHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final transactionsAsync = ref.watch(notebookTransactionsProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final booksAsync = ref.watch(notebookBooksProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final hasDismissedWelcome =
        prefs.getBool('notebook_welcome_dismissed') ?? false;

    double netBalance = 0.0;
    accountsAsync.whenData((accounts) {
      for (var acc in accounts) {
        netBalance += acc.balance;
      }
    });

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    transactionsAsync.whenData((transactions) {
      for (var tx in transactions) {
        if (tx.type == 'income') totalIncome += tx.amount;
        if (tx.type == 'expense') totalExpense += tx.amount;
      }
    });

    double totalOwedToMe = 0.0;
    double totalIOwe = 0.0;
    peopleAsync.whenData((people) {
      for (var p in people) {
        totalOwedToMe += p.amountOwedToMe;
        totalIOwe += p.amountIOwe;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.notebookGuide,
            onPressed: () => context.push('/notebook/guide'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            booksAsync.when(
              data: (books) {
                if (books.isEmpty && !hasDismissedWelcome) {
                  return Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.notebookWelcomeTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.notebookWelcomeDesc,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  ref.read(sharedPreferencesProvider).setBool(
                                      'notebook_welcome_dismissed', true);
                                },
                                child: Text(l10n.notebookLater),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  context.push('/notebook/books');
                                },
                                child: Text(l10n.notebookSetupNow),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(l10n.netBalance,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    accountsAsync.when(
                      data: (_) => Text(
                        NumberFormat.currency(symbol: 'SAR ')
                            .format(netBalance),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  netBalance >= 0 ? Colors.green : Colors.red,
                            ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (err, stack) => Text(
                          '${AppLocalizations.of(context)!.genericErrorPrefix}: $err'),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                            context, l10n.income, totalIncome, Colors.green),
                        _buildSummaryItem(
                            context, l10n.expense, totalExpense, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(context, l10n.notebookReceivable,
                            totalOwedToMe, Colors.blue),
                        _buildSummaryItem(context, l10n.notebookPayable,
                            totalIOwe, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: _buildActionCard(context, Icons.arrow_downward,
                        l10n.income, Colors.green, () async {
                  if (await GuestLimitService.canAddNotebookTransaction(
                      context, ref)) {
                    if (await _checkPrereqs(context, ref,
                        needAccount: true,
                        needCategory: true)) context.push('/notebook/income');
                  }
                })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(
                        context, Icons.arrow_upward, l10n.expense, Colors.red,
                        () async {
                  if (await GuestLimitService.canAddNotebookTransaction(
                      context, ref)) {
                    if (await _checkPrereqs(context, ref,
                        needAccount: true,
                        needCategory: true)) context.push('/notebook/expense');
                  }
                })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(context, Icons.swap_horiz,
                        l10n.notebookTransfer, Colors.blueGrey, () async {
                  if (await GuestLimitService.canAddNotebookTransaction(
                      context, ref)) {
                    if (await _checkPrereqs(context, ref,
                        needTwoAccounts: true))
                      context.push('/notebook/transfer');
                  }
                })),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildActionCard(context, Icons.person_add,
                        l10n.moneyOwedToMe, Colors.blue, () async {
                  if (await GuestLimitService.canAddNotebookTransaction(
                      context, ref)) {
                    if (await _checkPrereqs(context, ref))
                      context.push('/notebook/debt/me');
                  }
                })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(context, Icons.person_remove,
                        l10n.moneyIOwe, Colors.orange, () async {
                  if (await GuestLimitService.canAddNotebookTransaction(
                      context, ref)) {
                    if (await _checkPrereqs(context, ref))
                      context.push('/notebook/debt/owe');
                  }
                })),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildActionCard(
                        context,
                        Icons.account_balance,
                        l10n.notebookAccounts,
                        Colors.purple,
                        () => context.push('/notebook/accounts'))),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(
                        context,
                        Icons.people,
                        l10n.notebookPeople,
                        Colors.teal,
                        () => context.push('/notebook/people'))),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(
                        context,
                        Icons.bar_chart,
                        l10n.notebookReports,
                        Colors.brown,
                        () => context.push('/notebook/reports'))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildActionCard(
                        context,
                        Icons.book,
                        l10n.notebookBooks,
                        Colors.indigo,
                        () => context.push('/notebook/books'))),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(
                        context,
                        Icons.category,
                        l10n.notebookCategories,
                        Colors.cyan,
                        () => context.push('/notebook/categories'))),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildActionCard(
                        context,
                        Icons.list_alt,
                        l10n.notebookTransactions,
                        Colors.grey,
                        () => context.push('/notebook/transactions'))),
              ],
            ),
            const SizedBox(height: 32),
            Text(l10n.recentTransactions,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty)
                  return Center(
                      child: Text(AppLocalizations.of(context)!
                          .notebookNoTransactionsYet));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length > 5 ? 5 : transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isPositive =
                        tx.type == 'income' || tx.type == 'receivable_payment';
                    return ListTile(
                      title: Text(tx.note ??
                          NotebookLocalizationHelper.getNotebookLocalizedType(
                              context, tx.type)),
                      subtitle: Text(DateFormat.yMMMd(
                              Localizations.localeOf(context).languageCode)
                          .format(tx.date)),
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
              error: (err, stack) => Text(
                  '${AppLocalizations.of(context)!.genericErrorPrefix}: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkPrereqs(
    BuildContext context,
    WidgetRef ref, {
    bool needAccount = false,
    bool needTwoAccounts = false,
    bool needCategory = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.read(notebookBooksProvider);
    final hasBooks = booksAsync.valueOrNull?.isNotEmpty ?? false;

    if (!hasBooks) {
      _showPrereqDialog(context, l10n.notebookNeedBookFirst,
          l10n.notebookCreateBook, () => context.push('/notebook/books'));
      return false;
    }

    if (needAccount || needTwoAccounts) {
      final accountsAsync = ref.read(notebookAccountsProvider);
      final count = accountsAsync.valueOrNull?.length ?? 0;
      if (needTwoAccounts && count < 2) {
        _showPrereqDialog(context, l10n.notebookNeedTwoAccountsFirst,
            l10n.notebookAddAccount, () => context.push('/notebook/accounts'));
        return false;
      }
      if (needAccount && count < 1) {
        _showPrereqDialog(context, l10n.notebookNeedAccountFirst,
            l10n.notebookAddAccount, () => context.push('/notebook/accounts'));
        return false;
      }
    }

    if (needCategory) {
      final categoriesAsync = ref.read(notebookCategoriesProvider);
      final hasCategories = categoriesAsync.valueOrNull?.isNotEmpty ?? false;
      if (!hasCategories) {
        _showPrereqDialog(
            context,
            l10n.notebookNeedCategoryFirst,
            l10n.notebookAddCategory,
            () => context.push('/notebook/categories'));
        return false;
      }
    }

    return true;
  }

  void _showPrereqDialog(BuildContext context, String message, String btnText,
      VoidCallback onAction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.notebookCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            child: Text(btnText),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title,
      Color color, VoidCallback onTap) {
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
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      BuildContext context, String label, double amount, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          NumberFormat.currency(symbol: 'SAR ').format(amount),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
      ],
    );
  }
}
