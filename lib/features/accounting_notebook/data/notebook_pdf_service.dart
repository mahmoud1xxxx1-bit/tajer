import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../domain/notebook_transaction.dart';
import '../../../l10n/app_localizations.dart';
import '../utils/notebook_localization_helper.dart';

class NotebookPdfService {
  static Future<Uint8List> generateNotebookReportPdf(
      List<NotebookTransaction> transactions, String title, String currency, AppLocalizations l10n, bool isAr) async {
    final pdf = pw.Document();
    
    // Load Arabic Font
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFontBold,
    );

    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else if (t.type == 'expense') {
        totalExpense += t.amount;
      }
    }
    double netBalance = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      intl.DateFormat('yyyy/MM/dd HH:mm', isAr ? 'ar' : 'en').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            _buildSummaryRow(currency, totalIncome, totalExpense, netBalance, l10n),
            pw.SizedBox(height: 20),
            pw.Text(l10n.notebookTransactionsHeader, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildTransactionsTable(transactions, currency, l10n, isAr),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String currency, double totalIncome, double totalExpense, double netBalance, AppLocalizations l10n) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _summaryBox(l10n.notebookTotalIncome, '${totalIncome.toStringAsFixed(2)} $currency', PdfColors.green900),
          _summaryBox(l10n.notebookTotalExpenses, '${totalExpense.toStringAsFixed(2)} $currency', PdfColors.red900),
          _summaryBox(l10n.notebookNetBalance, '${netBalance.toStringAsFixed(2)} $currency', netBalance >= 0 ? PdfColors.blue900 : PdfColors.red900),
        ],
      ),
    );
  }

  static pw.Widget _summaryBox(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 4),
        pw.Directionality(
          textDirection: pw.TextDirection.ltr,
          child: pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable(List<NotebookTransaction> transactions, String currency, AppLocalizations l10n, bool isAr) {
    if (transactions.isEmpty) {
      return pw.Text(l10n.notebookNoData, style: const pw.TextStyle(color: PdfColors.grey));
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        l10n.notebookDate,
        l10n.notebookType,
        l10n.amount,
        l10n.note,
      ],
      data: transactions.map((t) {
        return [
          intl.DateFormat('yyyy/MM/dd', isAr ? 'ar' : 'en').format(t.date),
          NotebookLocalizationHelper.getNotebookLocalizedTypeCustom(t.type, l10n),
          '$currency ${t.amount.toStringAsFixed(2)}',
          t.note ?? '',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
    );
  }
}
