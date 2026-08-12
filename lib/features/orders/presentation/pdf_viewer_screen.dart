import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../orders/domain/order.dart';
import '../../../core/services/pdf_service.dart';

class PdfViewerScreen extends StatelessWidget {
  final AppOrder order;
  final String currency;
  final double? taxPercentage;
  final bool defaultIsTaxInclusive;

  const PdfViewerScreen({
    super.key,
    required this.order,
    required this.currency,
    this.taxPercentage,
    this.defaultIsTaxInclusive = false,
  });

  Future<void> _handleDirectPrint(BuildContext context) async {
    try {
      final bytes = await PdfService.generateInvoicePdf(context, order, currency, taxPercentage: taxPercentage, defaultIsTaxInclusive: defaultIsTaxInclusive);
      final fileName = 'Invoice_${order.queueNumber ?? order.id}.pdf';
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: fileName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تعذر الاتصال بطابعة النظام. حاول مشاركة الفاتورة كملف PDF بصيغة أخرى.'
                  : 'Unable to connect to system printer. Please try sharing the PDF file instead.',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleDirectShare(BuildContext context) async {
    try {
      final bytes = await PdfService.generateInvoicePdf(context, order, currency, taxPercentage: taxPercentage, defaultIsTaxInclusive: defaultIsTaxInclusive);
      final dir = await getTemporaryDirectory();
      final fileName = 'Invoice_${order.queueNumber ?? order.id}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: isAr ? 'فاتورة رقم ${order.queueNumber ?? order.id}' : 'Invoice #${order.queueNumber ?? order.id}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'خطأ أثناء تجهيز الملف للمشاركة: $e'
                  : 'Error preparing file for share: $e',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'معاينة الفاتورة (PDF)' : 'PDF Invoice Preview',
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.indigo),
            tooltip: isAr ? 'طباعة مباشرة' : 'Direct Print',
            onPressed: () => _handleDirectPrint(context),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.teal),
            tooltip: isAr ? 'مشاركة / حفظ الملف' : 'Share / Save',
            onPressed: () => _handleDirectShare(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfService.generateInvoicePdf(context, order, currency, taxPercentage: taxPercentage, defaultIsTaxInclusive: defaultIsTaxInclusive),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        maxPageWidth: 700,
        pdfFileName: 'Invoice_${order.queueNumber ?? order.id}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade600),
                const SizedBox(height: 16),
                Text(
                  isAr 
                    ? 'تعذر عرض المعاينة التلقائية على هذا الجهاز.\nيمكنك طباعة الفاتورة أو مشاركتها بأمان عبر الأزرار بالأعلى.'
                    : 'Could not render inline preview on this device.\nYou can print or share the invoice safely using the buttons above.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _handleDirectPrint(context),
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: Text(isAr ? 'طباعة مباشرة' : 'Direct Print', style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _handleDirectShare(context),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: Text(isAr ? 'مشاركة الملف' : 'Share File', style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

