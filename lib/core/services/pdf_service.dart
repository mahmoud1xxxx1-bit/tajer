import 'package:tajer/l10n/app_localizations.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../features/orders/domain/order.dart';
import '../../features/customers/domain/customer.dart';
import '../utils/date_formatter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PdfService {
  static Future<pw.Font> _getFont() async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  static Future<pw.Font> _getBoldFont() async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    return pw.Font.ttf(fontData);
  }

  static Future<void> printInvoice(BuildContext buildContext, AppOrder order, String currency, {double? taxPercentage}) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    
    final prefs = await SharedPreferences.getInstance();
    final profileStr = prefs.getString('store_profile');
    Map<String, dynamic>? profile;
    if (profileStr != null) {
      try {
        profile = jsonDecode(profileStr);
      } catch (_) {}
    }
    
    final storeName = profile?['storeName'] as String? ?? AppLocalizations.of(buildContext)!.text6;
    final storePhone = profile?['phone'] as String? ?? '';
    final storeAddress = profile?['address'] as String? ?? '';
    final logoBase64 = profile?['logoBase64'] as String? ?? '';
    
    pw.MemoryImage? logoImage;
    if (logoBase64.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(logoBase64));
      } catch (_) {}
    }

    final pdf = pw.Document();
    


    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with Branding
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 60,
                              height: 60,
                              margin: const pw.EdgeInsets.only(bottom: 8),
                              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                            ),
                          pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                          if (storeAddress.isNotEmpty)
                            pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                          if (storePhone.isNotEmpty)
                            pw.Text('هاتف: $storePhone', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('فاتورة رقم: #${order.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                          pw.SizedBox(height: 4),
                          pw.Text(AppDateFormatter.format(order.createdAt), style: const pw.TextStyle(fontSize: 14)),
                        ],
                      ),
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
                          pw.Text(AppLocalizations.of(buildContext)!.text7, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 8),
                          pw.Text('الاسم: ${order.customerName}', style: const pw.TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  
                  // Table
                  pw.Table.fromTextArray(
                    headers: [AppLocalizations.of(buildContext)!.text9, AppLocalizations.of(buildContext)!.text10, AppLocalizations.of(buildContext)!.text11, AppLocalizations.of(buildContext)!.text12],
                    data: order.items.map((item) => [
                      item.productName,
                      '${item.quantity}',
                      '${item.price}',
                      '${item.total}',
                    ]).toList(),
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
                              pw.Text(AppLocalizations.of(buildContext)!.text13, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(width: 20),
                              pw.Text('${order.total} $currency'),
                            ],
                          ),
                          if (taxPercentage != null && taxPercentage > 0) ...[
                            pw.SizedBox(height: 8),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('الضريبة ($taxPercentage%)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(width: 20),
                                pw.Text('${(order.total * (taxPercentage / 100)).toStringAsFixed(2)} $currency'),
                              ],
                            ),
                            pw.SizedBox(height: 8),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('الإجمالي بعد الضريبة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                                pw.SizedBox(width: 20),
                                pw.Text('${(order.total + (order.total * (taxPercentage / 100))).toStringAsFixed(2)} $currency', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                              ],
                            ),
                          ],
                          if (order.isCredit) ...[
                            pw.SizedBox(height: 8),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(AppLocalizations.of(buildContext)!.text14, style: const pw.TextStyle(color: PdfColors.green700)),
                                pw.SizedBox(width: 20),
                                pw.Text('${order.paidAmount} $currency', style: const pw.TextStyle(color: PdfColors.green700)),
                              ],
                            ),
                            pw.SizedBox(height: 8),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(AppLocalizations.of(buildContext)!.text15, style: pw.TextStyle(color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(width: 20),
                                pw.Text('${order.total - order.paidAmount} $currency', style: pw.TextStyle(color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(AppLocalizations.of(buildContext)!.text16, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ),
                ],
              ),
            ),
          ];
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


    // Filter orders to only this customer
    final customerOrders = orders.where((o) => o.customerId == customer.id).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(AppLocalizations.of(buildContext)!.text17, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
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
                  pw.Text(AppLocalizations.of(buildContext)!.text18, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  
                  // Orders Table
                  pw.Table.fromTextArray(
                    headers: [AppLocalizations.of(buildContext)!.text19, AppLocalizations.of(buildContext)!.text9, AppLocalizations.of(buildContext)!.text12, AppLocalizations.of(buildContext)!.text20, AppLocalizations.of(buildContext)!.text21, AppLocalizations.of(buildContext)!.text22],
                    data: customerOrders.map((o) => [
                      AppDateFormatter.format(o.createdAt),
                      o.items.map((i) => '${i.productName} (x${i.quantity})').join('\n'), // Support multiple items
                      '${o.total}',
                      '${o.paidAmount}',
                      '${o.isCredit ? (o.total - o.paidAmount) : 0}',
                      o.status == 'cancelled' ? AppLocalizations.of(buildContext)!.text98 : AppLocalizations.of(buildContext)!.text24,
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
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Statement_${customer.name}.pdf',
    );
  }
}
