import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class NotebookTransactionsScreen extends ConsumerStatefulWidget {
  const NotebookTransactionsScreen({super.key});

  @override
  ConsumerState<NotebookTransactionsScreen> createState() => _NotebookTransactionsScreenState();
}

class _NotebookTransactionsScreenState extends ConsumerState<NotebookTransactionsScreen> {
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final txAsync = ref.watch(notebookTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTransactions ?? 'Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedType,
                    decoration: InputDecoration(labelText: l10n.notebookTransactionType ?? 'Type', isDense: true),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.notebookAll ?? 'All')),
                      DropdownMenuItem(value: 'income', child: Text(l10n.income)),
                      DropdownMenuItem(value: 'expense', child: Text(l10n.expense)),
                      DropdownMenuItem(value: 'receivable', child: Text(l10n.moneyOwedToMe)),
                      DropdownMenuItem(value: 'payable', child: Text(l10n.moneyIOwe)),
                      DropdownMenuItem(value: 'receivable_payment', child: Text(l10n.notebookPayment ?? 'Payment')),
                      DropdownMenuItem(value: 'account_transfer', child: Text(l10n.notebookTransfer ?? 'Transfer')),
                    ],
                    onChanged: (val) => setState(() => _selectedType = val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  tooltip: l10n.notebookDateRange ?? 'Date Range',
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: _startDate != null && _endDate != null
                          ? DateTimeRange(start: _startDate!, end: _endDate!)
                          : null,
                    );
                    if (range != null) {
                      setState(() {
                        _startDate = range.start;
                        _endDate = range.end.add(const Duration(days: 1)); // inclusive
                      });
                    }
                  },
                ),
                if (_selectedType != null || _startDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.notebookClearFilters ?? 'Clear',
                    onPressed: () => setState(() {
                      _selectedType = null;
                      _startDate = null;
                      _endDate = null;
                    }),
                  )
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: txAsync.when(
              data: (transactions) {
                var filtered = transactions;
                if (_selectedType != null) {
                  filtered = filtered.where((t) => t.type == _selectedType).toList();
                }
                if (_startDate != null && _endDate != null) {
                  filtered = filtered.where((t) => t.date.isAfter(_startDate!) && t.date.isBefore(_endDate!)).toList();
                }

                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.notebookNoTransactionsYet));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
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
          ),
        ],
      ),
    );
  }
}