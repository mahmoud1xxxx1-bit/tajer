import 'dart:convert';
import 'dart:typed_data';

class ZatcaQrGenerator {
  /// Generates a ZATCA compliant Base64 TLV string for the QR Code
  static String generateQr({
    required String sellerName,
    required String vatNumber,
    required DateTime timestamp,
    required double invoiceTotal,
    required double vatTotal,
  }) {
    final builder = BytesBuilder();
    
    // 1. Seller Name (Tag 1)
    _appendTlv(builder, 1, sellerName);
    
    // 2. VAT Registration Number (Tag 2)
    _appendTlv(builder, 2, vatNumber);
    
    // 3. Timestamp (Tag 3)
    // ZATCA expects ISO 8601. Example: 2022-04-25T15:30:00Z
    final timeStr = "${timestamp.toIso8601String().split('.').first}Z"; 
    _appendTlv(builder, 3, timeStr);
    
    // 4. Invoice Total with VAT (Tag 4)
    _appendTlv(builder, 4, invoiceTotal.toStringAsFixed(2));
    
    // 5. VAT Total (Tag 5)
    _appendTlv(builder, 5, vatTotal.toStringAsFixed(2));
    
    // Encode the entire byte array to Base64
    return base64Encode(builder.toBytes());
  }

  static void _appendTlv(BytesBuilder builder, int tag, String value) {
    final valueBytes = utf8.encode(value);
    builder.addByte(tag);
    builder.addByte(valueBytes.length);
    builder.add(valueBytes);
  }
}
