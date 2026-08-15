import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notebook_pdf_service.dart';
import '../data/accounting_notebook_provider.dart';
import '../data/notebook_csv_service.dart';
import '../utils/notebook_terminology.dart';
import '../../../core/providers/settings_provider.dart';

class NotebookReportsScreen extends ConsumerStatefulWidget {
  const NotebookReportsScreen({super.key});

  @override
  ConsumerState<NotebookReportsScreen> createState() =>
      _NotebookReportsScreenState();
}

class _NotebookReportsScreenState extends ConsumerState<NotebookReportsScreen> {
  String _period = 'all';
  String? _selectedBookId;

  bool _isWithinPeriod(DateTime date) {
    final now = DateTime.now();
    if (_period == 'today') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
    if (_period == 'week') {
      final today = DateTime(now.year, now.month, now.day);
      final weekStart =
          today.subtract(Duration(days: today.weekday - DateTime.monday));
      return !date.isBefore(weekStart);
    }
    if (_period == 'month') {
      return date.year == now.year && date.month == now.month;
    }
    return true;
  }

  Widget _buildPeriodSelector(BuildContext context, AppLocalizations l10n) {
    final options = <(String, String)>[
      ('all', l10n.notebookAll),
      ('today', l10n.notebookToday),
      ('week', l10n.notebookWeek),
      ('month', l10n.notebookMonth),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth < 430 ? 2 : 4;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: options.map((option) {
            final selected = _period == option.$1;
            return SizedBox(
              width: itemWidth,
              child: ChoiceChip(
                selected: selected,
                showCheckmark: selected,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    option.$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onSelected: (_) => setState(() => _period = option.$1),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final txsAsync = ref.watch(notebookTransactionsProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final currencyCode = currentCurrency.code;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookReports)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyBooks,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/books'),
                    child: Text(l10n.notebookCreateBookCTA),
                  ),
                ],
              ),
            );
          }

          final candidate = _selectedBookId ?? sharedBookId;
          final selectedBookId = books.any((b) => b.id == candidate)
              ? candidate!
              : (books.where((b) => !b.isArchived).firstOrNull ?? books.first).id;
          _selectedBookId = selectedBookId;

          return txsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
            data: (allTransactions) {
              final transactions = allTransactions
                  .where((t) =>
                      t.bookId == selectedBookId && _isWithinPeriod(t.date))
                  .toList();

              double income = 0;
              double expense = 0;
              for (final tx in transactions) {
                if (tx.type == 'income') income += tx.amount;
                if (tx.type == 'expense') expense += tx.amount;
              }
              final netIncome = income - expense;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l10n.notebookGuideReports,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedBookId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.notebookBook),
                      items: books
                          .map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  b.isArchived
                                      ? '${b.name} (${l10n.notebookArchived})'
                                      : b.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        ref.read(notebookCurrentBookIdProvider.notifier).state =
                            value;
                        setState(() => _selectedBookId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPeriodSelector(context, l10n),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(l10n.notebookNetIncome,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                              NumberFormat.currency(symbol: '$currencyCode ')
                                  .format(netIncome),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: netIncome >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(children: [
                                  Text(l10n.income,
                                      style:
                                          const TextStyle(color: Colors.green)),
                                  Text(NumberFormat.currency(symbol: '')
                                      .format(income)),
                                ]),
                                Column(children: [
                                  Text(l10n.expense,
                                      style: const TextStyle(color: Colors.red)),
                                  Text(NumberFormat.currency(symbol: '')
                                      .format(expense)),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              NotebookTerminology.receivablesPayablesSection(
                                  context),
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            peopleAsync.when(
                              loading: () =>
                                  const CircularProgressIndicator(),
                              error: (_, __) => Text(l10n.genericErrorPrefix),
                              data: (allPeople) {
                                final people = allPeople
                                    .where((p) => p.bookId == selectedBookId)
                                    .toList();
                                final owed = people.fold<double>(0,
                                    (sum, p) => sum + p.amountOwedToMe);
                                final iOwe = people.fold<double>(
                                    0, (sum, p) => sum + p.amountIOwe);
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Flexible(
                                      child: Column(children: [
                                        Text(
                                          NotebookTerminology
                                              .accountsReceivable(context),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.blue),
                                        ),
                                        Text(NumberFormat.currency(symbol: '')
                                            .format(owed)),
                                      ]),
                                    ),
                                    Flexible(
                                      child: Column(children: [
                                        Text(
                                          NotebookTerminology.accountsPayable(
                                              context),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.orange),
                                        ),
                                        Text(NumberFormat.currency(symbol: '')
                                            .format(iOwe)),
                                      ]),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const Divider(),
                            accountsAsync.when(
                              loading: () =>
                                  const CircularProgressIndicator(),
                              error: (_, __) => Text(l10n.genericErrorPrefix),
                              data: (allAccounts) {
                                final accounts = allAccounts
                                    .where((a) => a.bookId == selectedBookId)
                                    .toList();
                                return Column(
                                  children: accounts
                                      .map((a) => ListTile(
                                            title: Text(
                                              a.isArchived
                                                  ? '${a.name} (${l10n.notebookArchived})'
                                                  : a.name,
                                            ),
                                            trailing: Text(
                                              NumberFormat.currency(
                                                      symbol: '$currencyCode ')
                                                  .format(a.balance),
                                            ),
                                            dense: true,
                                          ))
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(l10n.notebookExportPdf),
                          onPressed: () async {
                            final pdfData = await NotebookPdfService
                                .generateNotebookReportPdf(
                              transactions,
                              l10n.notebookReports,
                              currencyCode,
                              l10n,
                              Localizations.localeOf(context).languageCode ==
                                  'ar',
                            );
                            await Printing.sharePdf(
                              bytes: pdfData,
                              filename: 'accounting_report.pdf',
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.table_chart),
                          label: Text(l10n.notebookExportCsv),
                          onPressed: () async {
                            final csvData = NotebookCsvService.generateCsv(
                              transactions,
                              l10n,
                              Localizations.localeOf(context).languageCode ==
                                  'ar',
                              currencyCode,
                            );
                            await NotebookCsvService.shareCsv(
                              csvData,
                              'accounting_report.csv',
                              l10n,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
