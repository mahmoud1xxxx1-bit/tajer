import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notebook_pdf_service.dart';
import '../data/accounting_notebook_provider.dart';
import '../data/notebook_csv_service.dart';
import '../domain/notebook_transaction.dart';

class NotebookReportsScreen extends ConsumerStatefulWidget {
  const NotebookReportsScreen({super.key});

  @override
  ConsumerState<NotebookReportsScreen> createState() => _NotebookReportsScreenState();
}

class _NotebookReportsScreenState extends ConsumerState<NotebookReportsScreen> {
  String _period = 'all'; // all, today, week, month
  String? _selectedBookId;

  bool _isWithinPeriod(DateTime date) {
    final now = DateTime.now();
    if (_period == 'today') {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    } else if (_period == 'week') {
      return now.difference(date).inDays <= 7;
    } else if (_period == 'month') {
      return date.year == now.year && date.month == now.month;
    }
    return true; // all
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);
    final txsAsync = ref.watch(notebookTransactionsProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final accountsAsync = ref.watch(notebookAccountsProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookReports)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/books'),
                    child: Text(l10n.notebookCreateBookCTA),
                  )
                ],
              ),
            );
          }

          if (_selectedBookId == null || !books.any((b) => b.id == _selectedBookId)) {
            _selectedBookId = books.first.id;
          }

          return txsAsync.when(
            data: (allTransactions) {
              final transactions = allTransactions.where((t) => t.bookId == _selectedBookId && _isWithinPeriod(t.date)).toList();
              
              double income = 0.0;
              double expense = 0.0;
              for (var tx in transactions) {
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.notebookGuideReports,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBookId,
                      decoration: InputDecoration(labelText: l10n.notebookBook),
                      items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setState(() => _selectedBookId = val),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'all', label: Text(l10n.notebookAll)),
                        ButtonSegment(value: 'today', label: Text(l10n.notebookToday)),
                        ButtonSegment(value: 'week', label: Text(l10n.notebookWeek)),
                        ButtonSegment(value: 'month', label: Text(l10n.notebookMonth)),
                      ],
                      selected: {_period},
                      onSelectionChanged: (set) => setState(() => _period = set.first),
                    ),
                    const SizedBox(height: 16),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(l10n.notebookNetIncome, style: Theme.of(context).textTheme.titleLarge),
                            Text(
                              NumberFormat.currency(symbol: 'SAR ').format(netIncome),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: netIncome >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(children: [
                                  Text(l10n.income, style: const TextStyle(color: Colors.green)),
                                  Text(NumberFormat.currency(symbol: '').format(income)),
                                ]),
                                Column(children: [
                                  Text(l10n.expense, style: const TextStyle(color: Colors.red)),
                                  Text(NumberFormat.currency(symbol: '').format(expense)),
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
                            Text(l10n.notebookDebtAndAccounts, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            peopleAsync.when(
                              data: (allPeople) {
                                final people = allPeople.where((p) => p.bookId == _selectedBookId && !(p.isArchived ?? false)).toList();
                                double owed = 0;
                                double iOwe = 0;
                                for (var p in people) {
                                  owed += p.amountOwedToMe;
                                  iOwe += p.amountIOwe;
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(children: [
                                      Text(l10n.notebookReceivable, style: const TextStyle(color: Colors.blue)),
                                      Text(NumberFormat.currency(symbol: '').format(owed)),
                                    ]),
                                    Column(children: [
                                      Text(l10n.notebookPayable, style: const TextStyle(color: Colors.orange)),
                                      Text(NumberFormat.currency(symbol: '').format(iOwe)),
                                    ]),
                                  ],
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (_, __) => const SizedBox(),
                            ),
                            const Divider(),
                            accountsAsync.when(
                              data: (allAccs) {
                                final accs = allAccs.where((a) => a.bookId == _selectedBookId && !(a.isArchived ?? false)).toList();
                                return Column(
                                  children: accs.map((a) => ListTile(
                                    title: Text(a.name),
                                    trailing: Text(NumberFormat.currency(symbol: 'SAR ').format(a.balance)),
                                    dense: true,
                                  )).toList(),
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (_, __) => const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(l10n.notebookExportPdf),
                          onPressed: () async {
                            final pdfData = await NotebookPdfService.generateNotebookReportPdf(
                              transactions,
                              l10n.notebookReports,
                              'SAR',
                              l10n, Localizations.localeOf(context).languageCode == 'ar'
                            );
                            await Printing.sharePdf(bytes: pdfData, filename: 'accounting_report.pdf');
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.table_chart),
                          label: Text(l10n.notebookExportCsv),
                          onPressed: () async {
                            final csvData = NotebookCsvService.generateCsv(
                              transactions,
                              l10n, Localizations.localeOf(context).languageCode == 'ar'
                            );
                            await NotebookCsvService.shareCsv(
                              csvData, 
                              'accounting_report.csv',
                              l10n
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('${l10n.genericErrorPrefix}: $err')),
          );
        }
      )
    );
  }
}
