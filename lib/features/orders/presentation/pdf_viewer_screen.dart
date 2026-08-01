import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../orders/domain/order.dart';
import '../../../core/services/pdf_service.dart';

class PdfViewerScreen extends StatelessWidget {
  final AppOrder order;
  final String currency;

  const PdfViewerScreen({
    super.key,
    required this.order,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'معاينة الفاتورة (PDF)' : 'PDF Invoice Preview',
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (format) => PdfService.generateInvoicePdf(context, order, currency),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        maxPageWidth: 700,
        pdfFileName: 'Invoice_${order.queueNumber ?? order.id}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
