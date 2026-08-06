import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/shifts/domain/shift.dart';
import 'package:tajer/core/providers/store_profile_provider.dart';
import 'package:tajer/core/utils/date_formatter.dart';
import 'package:tajer/core/utils/zatca_qr_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  static Future<void> _requestBluetoothPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  static Future<List<BluetoothInfo>> getDevices() async {
    await _requestBluetoothPermissions();
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String macAddress) async {
    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      // It might be connected to another, but if it is, let's assume it's good or disconnect first
    }
    try {
      await _requestBluetoothPermissions();
      bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      
      if (result) {
        // Save default printer MAC
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('default_printer_mac', macAddress);
      }
      return result;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }
  
  static Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }
  
  static Future<BluetoothInfo?> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString('default_printer_mac');
    if (mac == null) return null;
    
    final devices = await getDevices();
    try {
      return devices.firstWhere((d) => d.macAdress == mac);
    } catch (e) {
      return null;
    }
  }

  static Future<void> printReceipt(
    AppOrder order, 
    String currency, {
    double? taxPercentage,
    bool defaultIsTaxInclusive = false,
    StoreProfile? storeProfile,
    bool isKitchen = false,
  }) async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    
    if (!isConnected) {
      final savedDevice = await getSavedDevice();
      if (savedDevice != null) {
        bool connected = await connect(savedDevice.macAdress);
        if (!connected) throw Exception("تعذر الاتصال بالطابعة المحفوظة");
      } else {
        throw Exception("لا توجد طابعة متصلة أو محفوظة. يرجى الاتصال بطابعة من الإعدادات.");
      }
    }

    // 1. Generate PDF
    final pdf = pw.Document();
    
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(fontBoldData);

    pw.MemoryImage? logoImage;
    if (storeProfile != null && storeProfile.logoBase64.isNotEmpty) {
      try {
        final logoBytes = base64Decode(storeProfile.logoBase64);
        logoImage = pw.MemoryImage(logoBytes);
      } catch (e) {
        // ignore
      }
    }
    
    final isOfficial = !isKitchen && storeProfile != null && storeProfile.vatNumber != null && storeProfile.vatNumber!.isNotEmpty;

    final prefs = await SharedPreferences.getInstance();
    final savedPaperSize = prefs.getString('printer_paper_size') ?? '58mm';
    final double pageWidth = (savedPaperSize == '80mm' ? 80.0 : 58.0) * PdfPageFormat.mm;

    double totalTaxAmount = 0.0;
    double grandTotal = 0.0;
    double totalBeforeTax = 0.0;
    for (var item in order.items) {
      final taxRate = item.taxPercentage ?? taxPercentage ?? 0.0;
      final isInclusive = (item.taxPercentage != null && item.taxPercentage! > 0) ? (item.isTaxInclusive ?? defaultIsTaxInclusive) : defaultIsTaxInclusive;
      if (taxRate > 0) {
        if (isInclusive) {
          totalTaxAmount += item.total - (item.total / (1 + (taxRate / 100)));
          grandTotal += item.total;
          totalBeforeTax += item.total / (1 + (taxRate / 100));
        } else {
          totalTaxAmount += item.total * (taxRate / 100);
          grandTotal += item.total + (item.total * (taxRate / 100));
          totalBeforeTax += item.total;
        }
      } else {
        grandTotal += item.total;
        totalBeforeTax += item.total;
      }
    }
    bool hasTax = totalTaxAmount > 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 40 * PdfPageFormat.mm,
                    child: pw.Image(logoImage),
                  ),
                if (logoImage != null) pw.SizedBox(height: 10),
                
                if (storeProfile != null && storeProfile.storeName.isNotEmpty)
                  pw.Text(
                    storeProfile.storeName,
                    style: pw.TextStyle(font: ttfBold, fontSize: 16),
                    textAlign: pw.TextAlign.center,
                  ),
                if (isOfficial) ...[
                  pw.Text('الرقم الضريبي: ${storeProfile.vatNumber}', style: pw.TextStyle(font: ttf, fontSize: 10), textAlign: pw.TextAlign.center),
                  if (storeProfile.crNumber != null && storeProfile.crNumber!.isNotEmpty)
                    pw.Text('س.ت: ${storeProfile.crNumber}', style: pw.TextStyle(font: ttf, fontSize: 10), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 5),
                ],
                
                pw.Text(
                  isKitchen ? 'تذكرة مطبخ (تحضير)' : (isOfficial ? 'فاتورة ضريبية مبسطة' : 'فاتورة مبيعات'),
                  style: pw.TextStyle(font: ttfBold, fontSize: 14),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),

                // Order Meta
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('رقم الطلب:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('${order.queueNumber ?? order.id.substring(0, 8)}', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('التاريخ:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text(AppDateFormatter.format(order.createdAt), style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('العميل:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text(order.customerName, style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                
                // Headers
                pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('الصنف', style: pw.TextStyle(font: ttfBold, fontSize: 10))),
                    pw.Expanded(flex: 1, child: pw.Text('الكمية', style: pw.TextStyle(font: ttfBold, fontSize: 10), textAlign: pw.TextAlign.center)),
                    if (!isKitchen)
                      pw.Expanded(flex: 2, child: pw.Text('المجموع', style: pw.TextStyle(font: ttfBold, fontSize: 10), textAlign: pw.TextAlign.left)),
                  ]
                ),
                pw.SizedBox(height: 2),
                
                // Items
                ...order.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 3, child: pw.Text(item.productName, style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', style: pw.TextStyle(font: ttfBold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        if (!isKitchen)
                          pw.Expanded(flex: 2, child: pw.Text('${item.total.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf, fontSize: 10), textAlign: pw.TextAlign.left)),
                      ]
                    )
                  );
                }).toList(),
                
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),

                // Totals
                if (!isKitchen) ...[
                  if (hasTax) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الإجمالي (بدون ضريبة):', style: pw.TextStyle(font: ttf, fontSize: 10)),
                        pw.Text('${totalBeforeTax.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ]
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الضريبة:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                        pw.Text('${totalTaxAmount.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ]
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الإجمالي الشامل:', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                        pw.Text('${grandTotal.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                      ]
                    ),
                  ] else ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الإجمالي:', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                        pw.Text('${grandTotal.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                      ]
                    ),
                  ],

                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المدفوع:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('${order.paidAmount.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ]
                  ),

                  if (order.isCredit)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المتبقي (آجل):', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                        pw.Text('${(order.total - order.paidAmount).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                      ]
                    ),
                  if (order.paymentMethod == 'cash' && order.tenderedAmount != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المبلغ المستلم:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                        pw.Text('${order.tenderedAmount!.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ]
                    ),
                    if (order.changeAmount != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('المتبقي للعميل:', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                          pw.Text('${order.changeAmount!.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                        ]
                      ),
                    ]
                  ],
                  if (order.paymentMethod == 'split') ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المدفوع نقداً:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                        pw.Text('${(order.splitCashAmount ?? 0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ]
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المدفوع شبكة:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                        pw.Text('${(order.splitNetworkAmount ?? 0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      ]
                    ),
                  ],
                ],

                pw.SizedBox(height: 10),
                
                if (isOfficial) ...[
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: ZatcaQrGenerator.generateQr(
                        sellerName: storeProfile!.storeName,
                        vatNumber: storeProfile.vatNumber!,
                        timestamp: order.createdAt,
                        invoiceTotal: taxPercentage != null ? order.total + (order.total * (taxPercentage / 100)) : order.total,
                        vatTotal: taxPercentage != null ? (order.total * (taxPercentage / 100)) : 0.0,
                      ),
                      width: 80,
                      height: 80,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],

                if (!isKitchen && storeProfile != null && storeProfile.phone.isNotEmpty)
                  pw.Text('للتواصل: ${storeProfile.phone}', style: pw.TextStyle(font: ttf, fontSize: 10), textAlign: pw.TextAlign.center),
                
                if (!isKitchen)
                  pw.Text('شكراً لتسوقكم معنا', style: pw.TextStyle(font: ttfBold, fontSize: 12), textAlign: pw.TextAlign.center),
                
                pw.SizedBox(height: 20),
              ]
            )
          );
        }
      )
    );

    // 2. Render PDF to Image
    final bytes = await pdf.save();
    
    // We rasterize the PDF. 200 DPI is a good balance for thermal printers.
    final images = <Uint8List>[];
    await for (var page in Printing.raster(bytes, dpi: 200)) {
      // The page is an image. We can convert it to PNG to feed it to image package.
      final pngBytes = await page.toPng();
      images.add(pngBytes);
    }

    // 3. Print via ESC/POS
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> printBytes = [];
    
    for (var png in images) {
      final decodedImage = img.decodeImage(png);
      if (decodedImage != null) {
        // Optional: Resize if width is larger than 384 (standard 58mm width in pixels)
        img.Image resized = decodedImage;
        if (decodedImage.width > 384) {
          resized = img.copyResize(decodedImage, width: 384);
        }
        
        printBytes += generator.imageRaster(resized);
      }
    }
    
    printBytes += generator.feed(2);
    printBytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(printBytes);
  }

  static Future<void> printZReport(
    Shift shift, 
    String currency, {
    StoreProfile? storeProfile,
    double totalCashExpenses = 0.0,
    double totalSupplierCash = 0.0,
  }) async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      final savedDevice = await getSavedDevice();
      if (savedDevice != null) {
        bool connected = await connect(savedDevice.macAdress);
        if (!connected) throw Exception("تعذر الاتصال بالطابعة المحفوظة");
      } else {
        throw Exception("لا توجد طابعة متصلة أو محفوظة.");
      }
    }

    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(fontBoldData);

    final prefs = await SharedPreferences.getInstance();
    final savedPaperSize = prefs.getString('printer_paper_size') ?? '58mm';
    final double pageWidth = (savedPaperSize == '80mm' ? 80.0 : 58.0) * PdfPageFormat.mm;

    pw.MemoryImage? logoImage;
    if (storeProfile != null && storeProfile.logoBase64.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(storeProfile.logoBase64));
      } catch (e) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          final difference = (shift.actualCash ?? 0.0) - (shift.expectedCash ?? 0.0);
          final diffText = difference == 0 
            ? 'متطابق' 
            : (difference > 0 ? 'زيادة: ${difference.toStringAsFixed(2)}' : 'عجز: ${difference.abs().toStringAsFixed(2)}');

          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (logoImage != null) pw.Container(width: 40 * PdfPageFormat.mm, child: pw.Image(logoImage)),
                if (logoImage != null) pw.SizedBox(height: 10),
                if (storeProfile != null && storeProfile.storeName.isNotEmpty)
                  pw.Text(storeProfile.storeName, style: pw.TextStyle(font: ttfBold, fontSize: 16)),
                
                pw.Text('تقرير إغلاق الوردية (Z-Report)', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                pw.SizedBox(height: 10),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الموظف:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text(shift.employeeName, style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('وقت البدء:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text(AppDateFormatter.format(shift.startTime), style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('وقت الإغلاق:', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text(AppDateFormatter.format(shift.endTime ?? DateTime.now()), style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('العهدة الافتتاحية:', style: pw.TextStyle(font: ttf, fontSize: 12)),
                  pw.Text('${shift.startCash.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 12)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('مبيعات نقدية:', style: pw.TextStyle(font: ttf, fontSize: 12)),
                  pw.Text('${(shift.cashSales ?? 0.0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 12)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('مبيعات شبكة/تحويل:', style: pw.TextStyle(font: ttf, fontSize: 12)),
                  pw.Text('${((shift.cardTotal ?? 0) + (shift.transferTotal ?? 0)).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 12)),
                ]),
                
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),

                if (totalCashExpenses > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('مصروفات تم دفعها كاش:', style: pw.TextStyle(font: ttf, fontSize: 12)),
                  pw.Text('-${totalCashExpenses.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 12)),
                ]),
                if (totalSupplierCash > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('ديون موردين تم سدادها كاش:', style: pw.TextStyle(font: ttf, fontSize: 12)),
                  pw.Text('-${totalSupplierCash.toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttf, fontSize: 12)),
                ]),

                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('الكاش المتوقع:', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                  pw.Text('${(shift.expectedCash ?? 0.0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('الكاش الفعلي في الدرج:', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                  pw.Text('${(shift.actualCash ?? 0.0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('الفرق في الكاش:', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                  pw.Text(diffText, style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                ]),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('مبيعات شبكة/مدى الفعلية:', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                  pw.Text('${(shift.actualCard ?? 0.0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('مبيعات التحويل الفعلية:', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                  pw.Text('${(shift.actualTransfer ?? 0.0).toStringAsFixed(2)} $currency', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                ]),
                
                pw.SizedBox(height: 20),
                pw.Text('توقيع المستلم: .................', style: pw.TextStyle(font: ttf, fontSize: 10)),
                pw.SizedBox(height: 10),
              ]
            )
          );
        }
      )
    );

    final bytes = await pdf.save();
    final images = <Uint8List>[];
    await for (var page in Printing.raster(bytes, dpi: 200)) {
      images.add(await page.toPng());
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> printBytes = [];
    
    for (var png in images) {
      final decodedImage = img.decodeImage(png);
      if (decodedImage != null) {
        img.Image resized = decodedImage;
        if (decodedImage.width > 384) {
          resized = img.copyResize(decodedImage, width: 384);
        }
        printBytes += generator.imageRaster(resized);
      }
    }
    
    printBytes += generator.feed(2);
    printBytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(printBytes);
  }
}
