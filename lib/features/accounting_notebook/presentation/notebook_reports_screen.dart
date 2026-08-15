import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notebook_pdf_service.dart';
import '../data/accounting_notebook_provider.dart';
import '../data/notebook_csv_service.dart';

class NotebookReportsScreen extends ConsumerWidget {
  const NotebookReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final txsAsync = ref.watch(notebookTransactionsProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookReports)),
      body: txsAsync.when(
        data: (transactions) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                  onPressed: () async {
                    final pdfData = await NotebookPdfService.generateNotebookReportPdf(
                      transactions,
                      l10n.notebookReports,
                      'SAR',
                      isAr: Localizations.localeOf(context).languageCode == 'ar'
                    );
                    await Printing.sharePdf(bytes: pdfData, filename: 'accounting_report.pdf');
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export Excel (CSV)'),
                  onPressed: () async {
                    final csvData = NotebookCsvService.generateCsv(
                      transactions,
                      isAr: Localizations.localeOf(context).languageCode == 'ar'
                    );
                    await NotebookCsvService.shareCsv(csvData, 'accounting_report.csv');
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
