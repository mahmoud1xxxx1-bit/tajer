import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'reports_service.dart';

class PdfService {
  static Future<Uint8List> generateReportPdf(
      ReportsService reportsService, String title, String currency, {
        double taxPercentage = 0.0,
        bool isInclusive = false,
        String vatNumber = '',
      }) async {
    final pdf = pw.Document();
    
    // Load Arabic Font
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFontBold,
    );

    double totalTaxAmount = reportsService.totalTaxCollected;
    double totalRevenue = reportsService.totalRevenue; // This is actually Gross (Grand Total)
    double revenueBeforeTax = reportsService.netSalesRevenue;

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('تقرير الأرباح والمبيعات',
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      if (vatNumber.isNotEmpty)
                        pw.Text('الرقم الضريبي: $vatNumber', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Text(
                      intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('الفترة: $title', style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),
            _buildSummaryRow(reportsService, currency, revenueBeforeTax, totalTaxAmount, totalRevenue, taxPercentage > 0),
            pw.SizedBox(height: 20),
            pw.Text('أفضل المنتجات مبيعاً:',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildBestSellersTable(reportsService, currency),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(ReportsService service, String currency, double revenueBeforeTax, double totalTaxAmount, double grandTotal, bool hasTax) {
    if (hasTax) {
      return pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _summaryBox('المبيعات (قبل الضريبة)', '${revenueBeforeTax.toStringAsFixed(2)} $currency', PdfColors.green900),
                _summaryBox('إجمالي الضريبة', '${totalTaxAmount.toStringAsFixed(2)} $currency', PdfColors.red900),
                _summaryBox('الإجمالي الشامل', '${grandTotal.toStringAsFixed(2)} $currency', PdfColors.blue900),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _summaryBox('صافي الربح', '${service.netProfit.toStringAsFixed(2)} $currency', PdfColors.blue900),
                _summaryBox('المصروفات', '${service.totalExpenses.toStringAsFixed(2)} $currency', PdfColors.orange900),
                _summaryBox('الديون', '${service.totalDebt.toStringAsFixed(2)} $currency', PdfColors.red900),
              ],
            ),
          ),
        ]
      );
    }
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _summaryBox('المبيعات', '${service.totalRevenue.toStringAsFixed(2)} $currency', PdfColors.green900),
          _summaryBox('صافي الربح', '${service.netProfit.toStringAsFixed(2)} $currency', PdfColors.blue900),
          _summaryBox('المصروفات', '${service.totalExpenses.toStringAsFixed(2)} $currency', PdfColors.orange900),
          _summaryBox('الديون', '${service.totalDebt.toStringAsFixed(2)} $currency', PdfColors.red900),
        ],
      ),
    );
  }

  static pw.Widget _summaryBox(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildBestSellersTable(ReportsService service, String currency) {
    final bestSellers = service.getBestSellers().take(10).toList();
    if (bestSellers.isEmpty) {
      return pw.Text('لا توجد بيانات', style: const pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table.fromTextArray(
      headers: ['المنتج', 'الكمية المباعة', 'إجمالي الإيرادات'],
      data: bestSellers.map((item) {
        return [
          item.product.name,
          item.quantitySold.toString(),
          '${item.totalRevenue.toStringAsFixed(2)} $currency',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellAlignment: pw.Alignment.centerRight,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
    );
  }
}
