import 'package:tajer/l10n/app_localizations.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../features/orders/domain/order.dart';
import '../../features/customers/domain/customer.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfService {
  static Future<pw.Font> _getFont() async {
    return await PdfGoogleFonts.tajawalRegular();
  }

  static Future<pw.Font> _getBoldFont() async {
    return await PdfGoogleFonts.tajawalBold();
  }

  static Future<void> printInvoice(BuildContext buildContext, AppOrder order, String currency) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    
    final pdf = pw.Document();
    
    final dateFormat = DateFormat('yyyy/MM/dd hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(AppLocalizations.of(buildContext)!.text_6, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('فاتورة رقم: #${order.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                
                // Customer Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(AppLocalizations.of(buildContext)!.text_7, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('الاسم: ${order.customerName}', style: const pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(AppLocalizations.of(buildContext)!.text_8, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(dateFormat.format(order.createdAt), style: const pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Table
                pw.Table.fromTextArray(
                  headers: [AppLocalizations.of(buildContext)!.text_9, AppLocalizations.of(buildContext)!.text_10, AppLocalizations.of(buildContext)!.text_11, AppLocalizations.of(buildContext)!.text_12],
                  data: [
                    [order.productName, '${order.quantity}', '${order.price}', '${order.total}'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.center,
                  cellPadding: const pw.EdgeInsets.all(8),
                ),
                pw.SizedBox(height: 20),
                
                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(AppLocalizations.of(buildContext)!.text_13, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(width: 20),
                            pw.Text('${order.total} $currency'),
                          ],
                        ),
                        if (order.isCredit) ...[
                          pw.SizedBox(height: 8),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(AppLocalizations.of(buildContext)!.text_14, style: const pw.TextStyle(color: PdfColors.green700)),
                              pw.SizedBox(width: 20),
                              pw.Text('${order.paidAmount} $currency', style: const pw.TextStyle(color: PdfColors.green700)),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(AppLocalizations.of(buildContext)!.text_15, style: pw.TextStyle(color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(width: 20),
                              pw.Text('${order.total - order.paidAmount} $currency', style: pw.TextStyle(color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
                
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(AppLocalizations.of(buildContext)!.text_16, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${order.id}.pdf',
    );
  }

  static Future<void> printCustomerStatement(BuildContext buildContext, Customer customer, List<AppOrder> orders, String currency) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy/MM/dd hh:mm a');

    // Filter orders to only this customer
    final customerOrders = orders.where((o) => o.customerId == customer.id).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(AppLocalizations.of(buildContext)!.text_17, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ),
                pw.SizedBox(height: 20),
                
                // Customer Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('الاسم: ${customer.name}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('رقم الهاتف: ${customer.phone}'),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('إجمالي المشتريات: ${customer.totalPurchases} $currency'),
                          pw.SizedBox(height: 4),
                          pw.Text('إجمالي الديون: ${customer.totalDebt} $currency', style: pw.TextStyle(color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                pw.Text(AppLocalizations.of(buildContext)!.text_18, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                
                // Orders Table
                pw.Table.fromTextArray(
                  headers: [AppLocalizations.of(buildContext)!.text_19, AppLocalizations.of(buildContext)!.text_9, AppLocalizations.of(buildContext)!.text_12, AppLocalizations.of(buildContext)!.text_20, AppLocalizations.of(buildContext)!.text_21, AppLocalizations.of(buildContext)!.text_22],
                  data: customerOrders.map((o) => [
                    dateFormat.format(o.createdAt),
                    '${o.productName} (x${o.quantity})',
                    '${o.total}',
                    '${o.paidAmount}',
                    '${o.isCredit ? (o.total - o.paidAmount) : 0}',
                    o.status == 'cancelled' ? AppLocalizations.of(buildContext)!.text_98 : AppLocalizations.of(buildContext)!.text_24,
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.center,
                  cellPadding: const pw.EdgeInsets.all(6),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Statement_${customer.name}.pdf',
    );
  }
}
