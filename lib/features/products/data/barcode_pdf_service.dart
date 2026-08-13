import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/product.dart';

class BarcodePdfService {
  static Future<Uint8List> generateA4BarcodeSheet({
    required Product product,
    required String storeName,
    required String currency,
    required int quantity,
    required bool isAr,
  }) async {
    final pdf = pw.Document();
    
    // Load Fonts for Arabic support
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFontBold,
    );

    // A4 sheet has dimensions: 210 x 297 mm.
    // Let's create a grid. Standard sticker sheets usually have e.g. 3 columns and 10 rows (30 labels).
    const int cols = 3;
    const int rows = 10;
    const int perPage = cols * rows;

    int remaining = quantity;

    while (remaining > 0) {
      final currentCount = remaining > perPage ? perPage : remaining;
      remaining -= currentCount;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(10), // Minimal margin
          build: (context) {
            final List<pw.Widget> cells = [];
            for (int i = 0; i < currentCount; i++) {
              cells.add(_buildSingleLabel(product, storeName, currency, isAr));
            }
            
            // Fill the rest of the row with empty containers to keep the grid aligned
            while (cells.length % cols != 0) {
              cells.add(pw.Container());
            }

            return pw.GridView(
              crossAxisCount: cols,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 2.2, // Width / Height ratio for the sticker
              children: cells,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static Future<Uint8List> generateThermalBarcode({
    required Product product,
    required String storeName,
    required String currency,
    required int quantity,
    required bool isAr,
  }) async {
    final pdf = pw.Document();
    
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFontBold,
    );

    // Standard Thermal Roll Sticker: 50mm x 30mm
    final format = PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);

    for (int i = 0; i < quantity; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          theme: theme,
          textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          build: (context) {
            return _buildSingleLabel(product, storeName, currency, isAr, isThermal: true);
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildSingleLabel(Product product, String storeName, String currency, bool isAr, {bool isThermal = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(isThermal ? 2 : 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Store Name
          pw.Text(
            storeName,
            style: pw.TextStyle(fontSize: isThermal ? 6 : 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
          
          // Product Name
          pw.Text(
            product.name,
            style: pw.TextStyle(fontSize: isThermal ? 8 : 10, fontWeight: pw.FontWeight.bold),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
          
          pw.SizedBox(height: 2),
          
          // Barcode
          pw.Expanded(
            child: pw.BarcodeWidget(
              data: product.barcode ?? product.id.substring(0, 8), // Fallback if no barcode
              barcode: pw.Barcode.code128(),
              width: double.infinity,
              drawText: true,
              textStyle: pw.TextStyle(fontSize: isThermal ? 6 : 8),
            ),
          ),
          
          pw.SizedBox(height: 2),
          
          // Price
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Text(
              '${product.price.toStringAsFixed(2)} $currency',
              style: pw.TextStyle(fontSize: isThermal ? 8 : 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
