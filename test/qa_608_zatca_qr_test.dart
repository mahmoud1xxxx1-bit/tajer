import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/utils/zatca_qr_generator.dart';

Map<int, String> _decodeTlv(String encoded) {
  final bytes = base64Decode(encoded);
  final values = <int, String>{};
  var i = 0;
  while (i < bytes.length) {
    final tag = bytes[i++];
    final length = bytes[i++];
    final end = i + length;
    expect(end, lessThanOrEqualTo(bytes.length), reason: 'TLV length must stay within payload');
    values[tag] = utf8.decode(bytes.sublist(i, end));
    i = end;
  }
  return values;
}

void main() {
  test('TEST 11/34 - ZATCA QR TLV payload and thermal official receipt contract', () {
    final timestamp = DateTime.utc(2026, 8, 16, 10, 30, 45);
    final encoded = ZatcaQrGenerator.generateQr(
      sellerName: 'متجر تاجر',
      vatNumber: '310123456700003',
      timestamp: timestamp,
      invoiceTotal: 115.00,
      vatTotal: 15.00,
    );

    expect(encoded, isNotEmpty);
    final decoded = _decodeTlv(encoded);
    expect(decoded.keys.toList(), [1, 2, 3, 4, 5]);
    expect(decoded[1], 'متجر تاجر');
    expect(decoded[2], '310123456700003');
    expect(decoded[3], '2026-08-16T10:30:45Z');
    expect(decoded[4], '115.00');
    expect(decoded[5], '15.00');

    // Guard the actual thermal receipt path: official receipts must embed the
    // production ZATCA generator into a QR BarcodeWidget before raster/ESC-POS.
    final printerSource = File('lib/core/services/printer_service.dart').readAsStringSync();
    expect(printerSource, contains('if (isOfficial)'));
    expect(printerSource, contains('pw.Barcode.qrCode()'));
    expect(printerSource, contains('data: ZatcaQrGenerator.generateQr('));
    expect(printerSource, contains('Printing.raster(bytes, dpi: 200)'));
    expect(printerSource, contains('Generator(PaperSize.mm58, profile)'));
    expect(printerSource, contains('PrintBluetoothThermal.writeBytes(printBytes)'));
  });
}
