import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/core/providers/settings_provider.dart';
import 'package:tajer/core/utils/date_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static Future<List<BluetoothInfo>> getDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String macAddress) async {
    bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      // It might be connected to another, but if it is, let's assume it's good or disconnect first
    }
    try {
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

  static Future<void> printReceipt(AppOrder order, AppCurrency currency, {double? taxPercentage}) async {
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

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text('فاتورة مبيعات', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.emptyLines(1);
    bytes += generator.text('رقم الطلب: ${order.id.substring(0, 8)}');
    bytes += generator.text('التاريخ: ${DateFormatter.formatDate(order.createdAt)}');
    bytes += generator.text('العميل: ${order.customerName}');
    bytes += generator.emptyLines(1);
    
    bytes += generator.hr();

    // Item
    bytes += generator.text(order.productName, styles: PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(
        text: '${order.quantity} x ${order.price}',
        width: 8,
        styles: PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: '${order.total} ${currency.code}',
        width: 4,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

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

    await PrintBluetoothThermal.writeBytes(bytes);
  }
}
