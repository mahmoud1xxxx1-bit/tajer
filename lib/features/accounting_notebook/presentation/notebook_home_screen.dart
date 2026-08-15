import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';
import '../utils/notebook_localization_helper.dart';
import '../utils/notebook_terminology.dart';
import '../../../../core/services/guest_limit_service.dart';
import '../../../../core/providers/settings_provider.dart';

final _welcomeDismissedProvider = StateProvider<bool?>((ref) => null);

class NotebookHomeScreen extends ConsumerWidget {
  const NotebookHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final transactionsAsync = ref.watch(notebookTransactionsProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final booksAsync = ref.watch(notebookBooksProvider);
    final currentBookId = ref.watch(notebookCurrentBookIdProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final localDismissed = ref.watch(_welcomeDismissedProvider);
    final hasDismissedWelcome = localDismissed ??
        (prefs.getBool('notebook_welcome_dismissed') ?? false);

    final books = booksAsync.value ?? [];
    final activeBooks = books.where((b) => !b.isArchived).toList();
    final selectedBookId = activeBooks.any((b) => b.id == currentBookId)
        ? currentBookId
        : activeBooks.firstOrNull?.id;

    final accounts = (accountsAsync.value ?? [])
        .where((a) => a.bookId == selectedBookId)
        .toList();
    final transactions = (transactionsAsync.value ?? [])
        .where((tx) => tx.bookId == selectedBookId)
        .toList();
    final people = (peopleAsync.value ?? [])
        .where((p) => p.bookId == selectedBookId)
        .toList();

    final totalAccountBalance =
        accounts.fold<double>(0, (sum, account) => sum + account.balance);
    final totalIncome = transactions
        .where((tx) => tx.type == 'income')
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final totalExpense = transactions
        .where((tx) => tx.type == 'expense')
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final totalOwedToMe =
        people.fold<double>(0, (sum, p) => sum + p.amountOwedToMe);
    final totalIOwe =
        people.fold<double>(0, (sum, p) => sum + p.amountIOwe);

    void selectCurrentBook(String id) {
      ref.read(notebookCurrentBookIdProvider.notifier).state = id;
    }

    Future<bool> canStartOperation() async {
      if (activeBooks.isNotEmpty && selectedBookId != null) {
        selectCurrentBook(selectedBookId);
        return true;
      }
      if (!context.mounted) return false;
      _showPrereqDialog(
        context,
        l10n.notebookNeedBookFirst,
        l10n.notebookCreateBookCTA,
        () => context.push('/notebook/books'),
      );
      return false;
    }

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (books.isEmpty && !hasDismissedWelcome)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                            child: Text(
                              l10n.notebookWelcomeTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.notebookWelcomeDesc,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              ref.read(sharedPreferencesProvider).setBool(
                                  'notebook_welcome_dismissed', true);
                              ref
                                  .read(_welcomeDismissedProvider.notifier)
                                  .state = true;
                            },
                            child: Text(l10n.notebookLater),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/notebook/books'),
                            child: Text(l10n.notebookSetupNow),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (activeBooks.isNotEmpty)
              DropdownButtonFormField<String>(
                value: selectedBookId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.notebookBook),
                items: activeBooks
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) selectCurrentBook(value);
                },
              ),
            if (activeBooks.isNotEmpty) const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      NotebookTerminology.totalAccountBalance(context),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      NumberFormat.currency(symbol: 'SAR ')
                          .format(totalAccountBalance),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: totalAccountBalance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
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
                        _buildSummaryItem(
                          context,
                          NotebookTerminology.accountsReceivable(context),
                          totalOwedToMe,
                          Colors.blue,
                        ),
                        _buildSummaryItem(
                          context,
                          NotebookTerminology.accountsPayable(context),
                          totalIOwe,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _actionRow([
              _buildActionCard(context, Icons.arrow_downward, l10n.income,
                  Colors.green, () async {
                if (await GuestLimitService.canAddNotebookTransaction(
                        context, ref) &&
                    await canStartOperation() &&
                    context.mounted) {
                  context.push('/notebook/income');
                }
              }),
              _buildActionCard(context, Icons.arrow_upward, l10n.expense,
                  Colors.red, () async {
                if (await GuestLimitService.canAddNotebookTransaction(
                        context, ref) &&
                    await canStartOperation() &&
                    context.mounted) {
                  context.push('/notebook/expense');
                }
              }),
              _buildActionCard(context, Icons.swap_horiz,
                  l10n.notebookTransfer, Colors.blueGrey, () async {
                if (await GuestLimitService.canAddNotebookTransaction(
                        context, ref) &&
                    await canStartOperation() &&
                    context.mounted) {
                  context.push('/notebook/transfer');
                }
              }),
            ]),
            const SizedBox(height: 16),
            _actionRow([
              _buildActionCard(
                  context,
                  Icons.person_add,
                  NotebookTerminology.accountsReceivable(context),
                  Colors.blue, () async {
                if (await GuestLimitService.canAddNotebookTransaction(
                        context, ref) &&
                    await canStartOperation() &&
                    context.mounted) {
                  context.push('/notebook/debt/me');
                }
              }),
              _buildActionCard(
                  context,
                  Icons.person_remove,
                  NotebookTerminology.accountsPayable(context),
                  Colors.orange, () async {
                if (await GuestLimitService.canAddNotebookTransaction(
                        context, ref) &&
                    await canStartOperation() &&
                    context.mounted) {
                  context.push('/notebook/debt/owe');
                }
              }),
            ]),
            const SizedBox(height: 16),
            _actionRow([
              _buildActionCard(context, Icons.account_balance,
                  l10n.notebookAccounts, Colors.purple, () {
                if (selectedBookId != null) selectCurrentBook(selectedBookId);
                context.push('/notebook/accounts');
              }),
              _buildActionCard(context, Icons.people, l10n.notebookPeople,
                  Colors.teal, () {
                if (selectedBookId != null) selectCurrentBook(selectedBookId);
                context.push('/notebook/people');
              }),
              _buildActionCard(context, Icons.bar_chart, l10n.notebookReports,
                  Colors.brown, () {
                if (selectedBookId != null) selectCurrentBook(selectedBookId);
                context.push('/notebook/reports');
              }),
            ]),
            const SizedBox(height: 16),
            _actionRow([
              _buildActionCard(context, Icons.book, l10n.notebookBooks,
                  Colors.indigo, () => context.push('/notebook/books')),
              _buildActionCard(context, Icons.category,
                  l10n.notebookCategories, Colors.cyan, () {
                if (selectedBookId != null) selectCurrentBook(selectedBookId);
                context.push('/notebook/categories');
              }),
              _buildActionCard(context, Icons.list_alt,
                  l10n.notebookTransactions, Colors.grey, () {
                if (selectedBookId != null) selectCurrentBook(selectedBookId);
                context.push('/notebook/transactions');
              }),
            ]),
            const SizedBox(height: 32),
            Text(l10n.recentTransactions,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (transactions.isEmpty)
              Center(child: Text(l10n.notebookNoTransactionsYet))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length > 5 ? 5 : transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final isPositive =
                      tx.type == 'income' || tx.type == 'receivable_payment';
                  final isNeutral = tx.type == 'opening_balance' ||
                      tx.type == 'account_transfer' ||
                      tx.type == 'receivable' ||
                      tx.type == 'payable';
                  return ListTile(
                    title: Text(tx.note ??
                        NotebookLocalizationHelper.getNotebookLocalizedType(
                            context, tx.type)),
                    subtitle: Text(DateFormat.yMMMd(
                            Localizations.localeOf(context).languageCode)
                        .format(tx.date)),
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
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static void _showPrereqDialog(BuildContext context, String message,
      String buttonText, VoidCallback onAction) {
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
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(List<Widget> cards) {
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ],
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      BuildContext context, String label, double amount, Color color) {
    return Flexible(
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(symbol: 'SAR ').format(amount),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
