import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/core/providers/settings_provider.dart';
import 'package:tajer/core/utils/date_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  static Future<List<BluetoothDevice>> getDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  static Future<bool> connect(BluetoothDevice device) async {
    if (await _bluetooth.isConnected == true) return true;
    try {
      await _bluetooth.connect(device);
      
      // Save default printer MAC
      final prefs = await SharedPreferences.getInstance();
      if (device.address != null) {
        await prefs.setString('default_printer_mac', device.address!);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> disconnect() async {
    return await _bluetooth.disconnect() ?? false;
  }
  
  static Future<bool> isConnected() async {
    return await _bluetooth.isConnected ?? false;
  }
  
  static Future<BluetoothDevice?> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString('default_printer_mac');
    if (mac == null) return null;
    
    final devices = await getDevices();
    try {
      return devices.firstWhere((d) => d.address == mac);
    } catch (e) {
      return null;
    }
  }

  static Future<void> printReceipt(Order order, AppCurrency currency, {double? taxPercentage}) async {
    bool isConnected = await _bluetooth.isConnected ?? false;
    
    if (!isConnected) {
      final savedDevice = await getSavedDevice();
      if (savedDevice != null) {
        bool connected = await connect(savedDevice);
        if (!connected) throw Exception("تعذر الاتصال بالطابعة المحفوظة");
      } else {
        throw Exception("لا توجد طابعة متصلة أو محفوظة. يرجى الاتصال بطابعة من الإعدادات.");
      }
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    // Note: Printing Arabic text directly on ESC/POS can be tricky. We might need image rendering if it's garbled.
    // For now we use standard text, but if it fails, image rendering is the fallback for Arabic.
    
    bytes += generator.text('فاتورة مبيعات', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.emptyLines(1);
    bytes += generator.text('رقم الطلب: ${order.id.substring(0, 8)}');
    bytes += generator.text('التاريخ: ${DateFormatter.formatDate(order.date)}');
    bytes += generator.text('العميل: ${order.customerName ?? "عميل عام"}');
    bytes += generator.emptyLines(1);
    
    bytes += generator.hr();

    // Items
    for (var item in order.items) {
      bytes += generator.text(item.productName, styles: PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x ${item.price}',
          width: 8,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '${item.total} ${currency.code}',
          width: 4,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // Totals
    double subtotal = order.total;
    if (taxPercentage != null && taxPercentage > 0) {
      double taxAmount = subtotal * (taxPercentage / 100);
      double totalWithTax = subtotal + taxAmount;
      bytes += generator.row([
        PosColumn(text: 'الإجمالي (بدون ضريبة):', width: 8),
        PosColumn(text: '$subtotal', width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'الضريبة ($taxPercentage%):', width: 8),
        PosColumn(text: '${taxAmount.toStringAsFixed(2)}', width: 4, styles: PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'الإجمالي الشامل:', width: 8, styles: PosStyles(bold: true)),
        PosColumn(text: '${totalWithTax.toStringAsFixed(2)}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);
    } else {
      bytes += generator.row([
        PosColumn(text: 'الإجمالي:', width: 8, styles: PosStyles(bold: true)),
        PosColumn(text: '$subtotal ${currency.code}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'المدفوع:', width: 8),
      PosColumn(text: '${order.paidAmount}', width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    
    if (order.isCredit) {
      bytes += generator.row([
        PosColumn(text: 'المتبقي (آجل):', width: 8, styles: PosStyles(bold: true)),
        PosColumn(text: '${order.total - order.paidAmount}', width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    bytes += generator.emptyLines(1);
    bytes += generator.text('شكراً لتسوقكم معنا', styles: PosStyles(align: PosAlign.center));
    bytes += generator.emptyLines(2);
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    await _bluetooth.writeBytes(Uint8List.fromList(bytes));
  }
}
