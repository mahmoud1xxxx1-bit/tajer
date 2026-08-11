import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/orders/domain/order.dart';
import '../../features/customers/domain/customer.dart';
import '../utils/date_formatter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/zatca_qr_generator.dart';

class PdfService {
  static Future<pw.Font> _getFont() async {
    try {
      return await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      return pw.Font.ttf(fontData);
    }
  }

  static Future<pw.Font> _getBoldFont() async {
    try {
      return await PdfGoogleFonts.cairoBold();
    } catch (_) {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      return pw.Font.ttf(fontData);
    }
  }

  static Future<pw.Font> _getEmojiFont() async {
    try {
      return await PdfGoogleFonts.notoColorEmoji();
    } catch (_) {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      return pw.Font.ttf(fontData);
    }
  }

  static Future<Uint8List> generateInvoicePdf(
    BuildContext buildContext,
    AppOrder order,
    String currency, {
    double? taxPercentage,
    bool defaultIsTaxInclusive = false,
  }) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    final emojiFont = await _getEmojiFont();

    bool isAr = true;
    try {
      isAr = Localizations.localeOf(buildContext).languageCode == 'ar';
    } catch (_) {
      isAr = true;
    }

    final prefs = await SharedPreferences.getInstance();
    final profileStr = prefs.getString('store_profile');
    Map<String, dynamic>? profile;
    if (profileStr != null) {
      try {
        profile = jsonDecode(profileStr);
      } catch (_) {}
    }

    final storeNameFallback = isAr ? 'المتجر التجاري' : 'Retail Store';
    final storeName = profile?['storeName'] as String? ?? storeNameFallback;
    final storePhone = profile?['phone'] as String? ?? '';
    final storeAddress = profile?['address'] as String? ?? '';
    final logoBase64 = profile?['logoBase64'] as String? ?? '';
    final vatNumber = profile?['vatNumber'] as String? ?? '';
    final crNumber = profile?['crNumber'] as String? ?? '';

    pw.MemoryImage? logoImage;
    if (logoBase64.isNotEmpty) {
      try {
        final decodedBytes = base64Decode(logoBase64);
        logoImage = pw.MemoryImage(decodedBytes);
      } catch (_) {
        logoImage = null;
      }
    }

    // Attempt to generate and save PDF with logoImage; if pdf package throws any exception (such as Null check operator on unsupported image formats), rebuild cleanly without image.
    try {
      final pdf = _buildInvoiceDoc(
        order,
        currency,
        taxPercentage ?? 0.0,
        defaultIsTaxInclusive,
        font,
        boldFont,
        emojiFont,
        isAr,
        storeName,
        storePhone,
        storeAddress,
        logoImage,
        vatNumber,
        crNumber,
      );
      return await pdf.save();
    } catch (e) {
      final fallbackPdf = _buildInvoiceDoc(
        order,
        currency,
        taxPercentage ?? 0.0,
        defaultIsTaxInclusive,
        font,
        boldFont,
        emojiFont,
        isAr,
        storeName,
        storePhone,
        storeAddress,
        null,
        vatNumber,
        crNumber,
      );
      return await fallbackPdf.save();
    }
  }

  static pw.Document _buildInvoiceDoc(
    AppOrder order,
    String currency,
    double defaultTaxPercentage,
    bool defaultIsTaxInclusive,
    pw.Font font,
    pw.Font boldFont,
    pw.Font emojiFont,
    bool isAr,
    String storeName,
    String storePhone,
    String storeAddress,
    pw.MemoryImage? logoImage,
    String vatNumber,
    String crNumber,
  ) {
    final lblCustomer = isAr ? 'بيانات العميل' : 'Customer Details';
    final lblColProduct = isAr ? 'الصنف / المنتج' : 'Product / Item';
    final lblColQty = isAr ? 'الكمية' : 'Qty';
    final lblColPrice = isAr ? 'السعر' : 'Price';
    final lblColTotal = isAr ? 'الإجمالي' : 'Total';
    final lblGrandTotal = isAr ? 'المجموع الكلي' : 'Grand Total';
    final lblPaid = isAr ? 'المبلغ المدفوع' : 'Paid Amount';
    final lblRemaining = isAr ? 'المتبقي (دين على العميل)' : 'Remaining (Debt)';
    final lblFooter = isAr
        ? 'شكراً لتعاملكم معنا - نسعد بزيارتكم دائماً'
        : 'Thank you for your business!';

    final creator = order.creatorName ?? '';
    final orderRef = order.queueNumber != null
        ? "#${order.queueNumber}"
        : (order.id.length >= 8
              ? order.id.substring(0, 8).toUpperCase()
              : order.id.toUpperCase());

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
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
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (logoImage != null)
                              pw.Container(
                                width: 60,
                                height: 60,
                                margin: const pw.EdgeInsets.only(bottom: 8),
                                child: pw.Image(
                                  logoImage,
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            pw.Text(
                              storeName,
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                            if (storeAddress.isNotEmpty)
                              pw.Text(
                                storeAddress,
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            if (storePhone.isNotEmpty)
                              pw.Text(
                                '${isAr ? "هاتف:" : "Phone:"} $storePhone',
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            if (vatNumber.isNotEmpty)
                              pw.Text(
                                '${isAr ? "الرقم الضريبي:" : "VAT No:"} $vatNumber',
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            if (crNumber.isNotEmpty)
                              pw.Text(
                                '${isAr ? "السجل التجاري:" : "CR No:"} $crNumber',
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            if (vatNumber.isNotEmpty)
                              pw.Text(
                                isAr
                                    ? 'فاتورة ضريبية مبسطة'
                                    : 'Simplified Tax Invoice',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800,
                                ),
                              ),
                            pw.Text(
                              '${isAr ? "فاتورة رقم" : "Invoice #"} $orderRef',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              AppDateFormatter.format(order.createdAt),
                              style: const pw.TextStyle(fontSize: 14),
                            ),
                            if (creator.isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              pw.Text(
                                '${isAr ? "المنفذ:" : "By:"} $creator',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.blue700,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                          pw.Text(
                            lblCustomer,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            '${isAr ? "الاسم:" : "Name:"} ${order.customerName}',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  if (vatNumber.isNotEmpty) ...[
                    pw.Builder(
                      builder: (context) {
                        double totalTaxAmount = 0.0;
                        double grandTotal = 0.0;
                        for (var item in order.items) {
                          final taxRate = item.getEffectiveTax(
                            taxPercentage ?? 0.0,
                          );
                          final isInclusive =
                              item.isTaxInclusive ?? defaultIsTaxInclusive;
                          final taxableTotal = item.total - item.discountAmount;
                          if (taxRate > 0) {
                            if (isInclusive) {
                              totalTaxAmount +=
                                  taxableTotal -
                                  (taxableTotal / (1 + (taxRate / 100)));
                              grandTotal += taxableTotal;
                            } else {
                              totalTaxAmount += taxableTotal * (taxRate / 100);
                              grandTotal +=
                                  taxableTotal +
                                  (taxableTotal * (taxRate / 100));
                            }
                          } else {
                            grandTotal += taxableTotal;
                          }
                        }

                        return pw.BarcodeWidget(
                          color: PdfColor.fromHex('#000000'),
                          barcode: pw.Barcode.qrCode(),
                          data: ZatcaQrGenerator.generateQr(
                            sellerName: storeName,
                            vatNumber: vatNumber,
                            timestamp: order.createdAt,
                            invoiceTotal: grandTotal,
                            vatTotal: totalTaxAmount,
                          ),
                          width: 80,
                          height: 80,
                        );
                      },
                    ),
                    pw.SizedBox(height: 20),
                  ],

                  // Table
                  pw.Table.fromTextArray(
                    headers: [
                      lblColProduct,
                      lblColQty,
                      lblColPrice,
                      lblColTotal,
                    ],
                    data: order.items
                        .map(
                          (item) => [
                            item.productName,
                            '${item.quantity}',
                            '${item.price}',
                            '${item.total}',
                          ],
                        )
                        .toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blue800,
                    ),
                    rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
                    cellAlignment: pw.Alignment.center,
                    cellPadding: const pw.EdgeInsets.all(8),
                  ),
                  pw.SizedBox(height: 20),

                  // Totals
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Builder(
                        builder: (context) {
                          double totalTaxAmount = 0.0;
                          double grandTotal = 0.0;
                          bool hasTax = false;
                          for (var item in order.items) {
                            final taxRate = item.getEffectiveTax(
                              taxPercentage ?? 0.0,
                            );
                            final isInclusive =
                                item.isTaxInclusive ?? defaultIsTaxInclusive;
                            final taxableTotal =
                                item.total - item.discountAmount;
                            if (taxRate > 0) {
                              hasTax = true;
                              if (isInclusive) {
                                totalTaxAmount +=
                                    taxableTotal -
                                    (taxableTotal / (1 + (taxRate / 100)));
                                grandTotal += taxableTotal;
                              } else {
                                totalTaxAmount +=
                                    taxableTotal * (taxRate / 100);
                                grandTotal +=
                                    taxableTotal +
                                    (taxableTotal * (taxRate / 100));
                              }
                            } else {
                              grandTotal += taxableTotal;
                            }
                          }

                          String paymentMethodText = '';
                          if (order.paymentMethod == 'cash') {
                            paymentMethodText = isAr
                                ? 'دفع نقدي 💵'
                                : 'Cash 💵';
                          } else if (order.paymentMethod == 'card' ||
                              order.paymentMethod == 'mada' ||
                              order.paymentMethod == 'apple_pay') {
                            paymentMethodText = isAr
                                ? 'دفع شبكة 💳'
                                : 'Card 💳';
                          } else if (order.paymentMethod == 'transfer') {
                            paymentMethodText = isAr
                                ? 'تحويل بنكي 🏦'
                                : 'Bank Transfer 🏦';
                          } else if (order.paymentMethod == 'split') {
                            paymentMethodText = isAr
                                ? 'دفع متعدد 🔀'
                                : 'Split 🔀';
                          }

                          return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (paymentMethodText.isNotEmpty) ...[
                                pw.Text(
                                  '${isAr ? "طريقة الدفع: " : "Payment Method: "}$paymentMethodText',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 14,
                                    fontFallback: [emojiFont],
                                  ),
                                ),
                                pw.SizedBox(height: 12),
                              ],
                              if (hasTax) ...[
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      isAr
                                          ? 'الإجمالي (قبل الضريبة)'
                                          : 'Total (Before Tax)',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${(grandTotal - totalTaxAmount).toStringAsFixed(2)} $currency',
                                    ),
                                  ],
                                ),
                                if (order.discountAmount > 0) ...[
                                  pw.SizedBox(height: 8),
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        isAr
                                            ? 'إجمالي الخصم'
                                            : 'Total Discount',
                                        style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(width: 20),
                                      pw.Text(
                                        '-${order.discountAmount.toStringAsFixed(2)} $currency',
                                        style: const pw.TextStyle(
                                          color: PdfColors.red700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      '${isAr ? "إجمالي الضريبة" : "Total Tax"}',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${totalTaxAmount.toStringAsFixed(2)} $currency',
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      lblGrandTotal,
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.blue800,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${grandTotal.toStringAsFixed(2)} $currency',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.blue800,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      lblGrandTotal,
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text('${order.total} $currency'),
                                  ],
                                ),
                                if (order.discountAmount > 0) ...[
                                  pw.SizedBox(height: 8),
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        isAr
                                            ? 'إجمالي الخصم'
                                            : 'Total Discount',
                                        style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(width: 20),
                                      pw.Text(
                                        '-${order.discountAmount.toStringAsFixed(2)} $currency',
                                        style: const pw.TextStyle(
                                          color: PdfColors.red700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                              if (order.isCredit) ...[
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      lblPaid,
                                      style: const pw.TextStyle(
                                        color: PdfColors.green700,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${order.paidAmount} $currency',
                                      style: const pw.TextStyle(
                                        color: PdfColors.green700,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      lblRemaining,
                                      style: pw.TextStyle(
                                        color: PdfColors.red700,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${(grandTotal - order.paidAmount).toStringAsFixed(2)} $currency',
                                      style: pw.TextStyle(
                                        color: PdfColors.red700,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (order.paymentMethod == 'cash' &&
                                  order.tenderedAmount != null) ...[
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      isAr ? 'المبلغ المستلم' : 'Tendered Cash',
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${order.tenderedAmount} $currency',
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.changeAmount != null) ...[
                                  pw.SizedBox(height: 8),
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        '${isAr ? "المتبقي للعميل" : "Change"}',
                                        style: pw.TextStyle(
                                          color: PdfColors.green700,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(width: 20),
                                      pw.Text(
                                        '${order.changeAmount} $currency',
                                        style: pw.TextStyle(
                                          color: PdfColors.green700,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else if (order.paymentMethod == 'split') ...[
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      isAr ? 'المدفوع نقداً' : 'Cash Paid',
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${order.splitCashAmount ?? 0} $currency',
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      isAr ? 'المدفوع شبكة' : 'Network Paid',
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                    pw.SizedBox(width: 20),
                                    pw.Text(
                                      '${order.splitNetworkAmount ?? 0} $currency',
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      lblFooter,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static Future<void> printInvoice(
    BuildContext buildContext,
    AppOrder order,
    String currency, {
    double? taxPercentage,
    bool defaultIsTaxInclusive = false,
  }) async {
    final bytes = await generateInvoicePdf(
      buildContext,
      order,
      currency,
      taxPercentage: taxPercentage,
      defaultIsTaxInclusive: defaultIsTaxInclusive,
    );
    final orderRef = order.queueNumber != null
        ? "#${order.queueNumber}"
        : (order.id.length >= 8
              ? order.id.substring(0, 8).toUpperCase()
              : order.id.toUpperCase());
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Invoice_$orderRef.pdf',
    );
  }

  static Future<void> printCustomerStatement(
    BuildContext buildContext,
    Customer customer,
    List<AppOrder> orders,
    String currency,
  ) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();

    bool isAr = true;
    try {
      isAr = Localizations.localeOf(buildContext).languageCode == 'ar';
    } catch (_) {
      isAr = true;
    }

    final lblTitle = isAr ? 'كشف حساب عميل' : 'Customer Statement';
    final lblOrdersHistory = isAr
        ? 'سجل الفواتير والطلبات'
        : 'Orders & Invoices History';
    final lblDate = isAr ? 'التاريخ' : 'Date';
    final lblItems = isAr ? 'الأصناف' : 'Items';
    final lblTotal = isAr ? 'الإجمالي' : 'Total';
    final lblPaid = isAr ? 'المدفوع' : 'Paid';
    final lblDebt = isAr ? 'الدين' : 'Debt';
    final lblStatus = isAr ? 'الحالة' : 'Status';
    final lblCancelled = isAr ? 'ملغى' : 'Cancelled';
    final lblCompleted = isAr ? 'مكتمل' : 'Completed';

    final pdf = pw.Document();

    // Filter orders to only this customer
    final customerOrders = orders
        .where((o) => o.customerId == customer.id)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      lblTitle,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Customer Info
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '${isAr ? "الاسم:" : "Name:"} ${customer.name}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${isAr ? "رقم الهاتف:" : "Phone:"} ${customer.phone}',
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              '${isAr ? "إجمالي المشتريات:" : "Total Purchases:"} ${customer.totalPurchases} $currency',
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${isAr ? "إجمالي الديون:" : "Total Debt:"} ${customer.totalDebt} $currency',
                              style: pw.TextStyle(
                                color: PdfColors.red800,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),
                  pw.Text(
                    lblOrdersHistory,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // Orders Table
                  pw.Table.fromTextArray(
                    headers: [
                      lblDate,
                      lblItems,
                      lblTotal,
                      lblPaid,
                      lblDebt,
                      lblStatus,
                    ],
                    data: customerOrders
                        .map(
                          (o) => [
                            AppDateFormatter.format(o.createdAt),
                            o.items
                                .map((i) => '${i.productName} (x${i.quantity})')
                                .join('\n'),
                            '${o.total}',
                            '${o.paidAmount}',
                            '${o.isCredit ? (o.total - o.paidAmount) : 0}',
                            o.status == 'cancelled'
                                ? lblCancelled
                                : lblCompleted,
                          ],
                        )
                        .toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blue800,
                    ),
                    rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
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
      onLayout: (format) async => pdf.save(),
      name: 'Statement_${customer.name}.pdf',
    );
  }
}
