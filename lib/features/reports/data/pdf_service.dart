import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'reports_service.dart';

class PdfService {
  static Future<Uint8List> generateReportPdf(
    ReportsService reportsService,
    String title,
    String currency, {
    double taxPercentage = 0.0,
    bool isInclusive = false,
    String vatNumber = '',
    bool isAr = true,
    String? scopeLabel,
    bool canViewCost = false,
  }) async {
    final pdf = pw.Document();

    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFontBold,
    );

    final totalTaxAmount = reportsService.totalTaxCollected;
    final totalRevenue = reportsService.totalRevenue;
    final revenueBeforeTax = reportsService.netSalesRevenue;

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
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isAr ? 'تقرير المبيعات' : 'Sales Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (scopeLabel != null && scopeLabel.trim().isNotEmpty)
                        pw.Text(
                          isAr ? 'نطاق التقرير: $scopeLabel' : 'Report scope: $scopeLabel',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                      if (vatNumber.isNotEmpty)
                        pw.Text(
                          isAr ? 'الرقم الضريبي: $vatNumber' : 'VAT Number: $vatNumber',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                  pw.Text(
                    intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              isAr ? 'الفترة: $title' : 'Period: $title',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 20),
            _buildSummaryRow(
              reportsService,
              currency,
              revenueBeforeTax,
              totalTaxAmount,
              totalRevenue,
              taxPercentage > 0 || totalTaxAmount > 0,
              isAr,
              canViewCost,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              isAr ? 'الأموال المستلمة حسب طريقة الدفع:' : 'Money received by payment method:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              isAr
                  ? 'يشمل المبالغ المستلمة من المبيعات وتحصيلات ديون العملاء خلال الفترة.'
                  : 'Includes money received from sales and customer debt collections during the period.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            _buildPaymentMethodsTable(reportsService, currency, isAr),
            if (reportsService.getDailySales().length > 1) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                isAr ? 'الملخص اليومي:' : 'Daily Summary:',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildDailySummaryTable(reportsService, currency, isAr),
            ],
            pw.SizedBox(height: 20),
            pw.Text(
              isAr ? 'أفضل المنتجات مبيعاً:' : 'Best Sellers:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildBestSellersTable(reportsService, currency, isAr),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(
    ReportsService service,
    String currency,
    double revenueBeforeTax,
    double totalTaxAmount,
    double grandTotal,
    bool hasTax,
    bool isAr,
    bool canViewCost,
  ) {
    final primaryBoxes = <pw.Widget>[
      _summaryBox(
        hasTax ? (isAr ? 'المبيعات قبل الضريبة' : 'Sales Before Tax') : (isAr ? 'المبيعات' : 'Sales'),
        '${(hasTax ? revenueBeforeTax : service.totalRevenue).toStringAsFixed(2)} $currency',
        PdfColors.green900,
      ),
      if (hasTax)
        _summaryBox(
          isAr ? 'إجمالي الضريبة' : 'Total Tax',
          '${totalTaxAmount.toStringAsFixed(2)} $currency',
          PdfColors.red900,
        ),
      if (hasTax)
        _summaryBox(
          isAr ? 'الإجمالي الشامل' : 'Grand Total',
          '${grandTotal.toStringAsFixed(2)} $currency',
          PdfColors.blue900,
        ),
    ];

    final secondaryBoxes = <pw.Widget>[
      if (canViewCost)
        _summaryBox(
          isAr ? 'صافي الربح' : 'Net Profit',
          '${service.netProfit.toStringAsFixed(2)} $currency',
          PdfColors.blue900,
        ),
      _summaryBox(
        isAr ? 'المصروفات' : 'Expenses',
        '${service.totalExpenses.toStringAsFixed(2)} $currency',
        PdfColors.orange900,
      ),
      _summaryBox(
        isAr ? 'الدين الناتج عن مبيعات النطاق' : 'Debt from scoped sales',
        '${service.totalDebt.toStringAsFixed(2)} $currency',
        PdfColors.red900,
      ),
    ];

    return pw.Column(
      children: [
        _summaryContainer(primaryBoxes),
        pw.SizedBox(height: 10),
        _summaryContainer(secondaryBoxes),
      ],
    );
  }

  static pw.Widget _summaryContainer(List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }

  static pw.Widget _summaryBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBestSellersTable(
    ReportsService service,
    String currency,
    bool isAr,
  ) {
    final bestSellers = service.getBestSellers().take(10).toList();
    if (bestSellers.isEmpty) {
      return pw.Text(
        isAr ? 'لا توجد بيانات' : 'No data',
        style: const pw.TextStyle(color: PdfColors.grey),
      );
    }

    return pw.Table.fromTextArray(
      headers: [
        isAr ? 'المنتج' : 'Product',
        isAr ? 'الكمية المباعة' : 'Quantity Sold',
        isAr ? 'إجمالي الإيرادات' : 'Total Revenue',
      ],
      data: bestSellers.map((item) {
        return [
          item.product.name,
          item.quantitySold.toString(),
          '$currency ${item.totalRevenue.toStringAsFixed(2)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
    );
  }

  static pw.Widget _buildPaymentMethodsTable(
    ReportsService service,
    String currency,
    bool isAr,
  ) {
    final breakdown = service.paymentMethodsBreakdown;
    if (breakdown.isEmpty) {
      return pw.Text(
        isAr ? 'لا توجد بيانات' : 'No data',
        style: const pw.TextStyle(color: PdfColors.grey),
      );
    }

    String getMethodName(String code) {
      switch (code) {
        case 'cash':
          return isAr ? 'نقدي (كاش)' : 'Cash';
        case 'card':
        case 'network':
          return isAr ? 'بطاقة / شبكة' : 'Card / Network';
        case 'transfer':
        case 'bank_transfer':
          return isAr ? 'تحويل بنكي' : 'Bank Transfer';
        default:
          return code;
      }
    }

    return pw.Table.fromTextArray(
      headers: [
        isAr ? 'طريقة الدفع' : 'Payment Method',
        isAr ? 'المبلغ المستلم' : 'Amount Received',
      ],
      data: breakdown.entries.map((e) {
        return [
          getMethodName(e.key),
          '$currency ${e.value.toStringAsFixed(2)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
    );
  }

  static pw.Widget _buildDailySummaryTable(
    ReportsService service,
    String currency,
    bool isAr,
  ) {
    final dailySales = service.getDailySales();
    if (dailySales.isEmpty) {
      return pw.Text(
        isAr ? 'لا توجد بيانات' : 'No data',
        style: const pw.TextStyle(color: PdfColors.grey),
      );
    }

    return pw.Table.fromTextArray(
      headers: [
        isAr ? 'التاريخ' : 'Date',
        isAr ? 'إجمالي المبيعات' : 'Total Sales',
      ],
      data: dailySales.map((item) {
        return [
          intl.DateFormat('yyyy/MM/dd').format(item.date),
          '$currency ${item.amount.toStringAsFixed(2)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
    );
  }
}
