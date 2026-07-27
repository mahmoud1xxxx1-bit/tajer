import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'reports_service.dart';
import 'package:printing/printing.dart';

class PdfService {
  static Future<Uint8List> generateReportPdf({
    required String period,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required List<SalesData> dailySales,
    required List<ProductSales> bestSellers,
    required String currency,
  }) async {
    final pdf = pw.Document();

    // Load Arabic font from Google Fonts using printing package
    final ttf = await PdfGoogleFonts.tajawalRegular();
    final ttfBold = await PdfGoogleFonts.tajawalBold();

    final theme = pw.ThemeData.withFont(
      base: ttf,
      bold: ttfBold,
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(AppLocalizations.of(context)!.text_0793bf, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('الفترة المحددة: $period', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            
            // Financial Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(AppLocalizations.of(context)!.text_4c33ae, style: const pw.TextStyle(fontSize: 16)),
                      pw.Text('$totalRevenue $currency', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(AppLocalizations.of(context)!.text_fab5a8, style: const pw.TextStyle(fontSize: 16)),
                      pw.Text('$totalExpenses $currency', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(AppLocalizations.of(context)!.text_577535, style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('$netProfit $currency', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                    ],
                  ),
                ],
              )
            ),
            pw.SizedBox(height: 30),

            // Best Sellers
            pw.Text(AppLocalizations.of(context)!.text_e5a09c, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerRight,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: <List<String>>[
                [AppLocalizations.of(context)!.text_1ab391, AppLocalizations.of(context)!.text_17831d, AppLocalizations.of(context)!.text_cd39bd],
                ...bestSellers.take(10).map((p) => [
                  p.product.name,
                  p.quantitySold.toString(),
                  '${p.totalRevenue} $currency',
                ]),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
