import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/glass_card.dart';
import '../domain/product.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../data/barcode_pdf_service.dart';

class BarcodePrintDialog extends ConsumerStatefulWidget {
  final Product product;

  const BarcodePrintDialog({super.key, required this.product});

  @override
  ConsumerState<BarcodePrintDialog> createState() => _BarcodePrintDialogState();
}

class _BarcodePrintDialogState extends ConsumerState<BarcodePrintDialog> {
  final _qtyController = TextEditingController();
  String _paperType = 'a4'; // 'a4' or 'thermal'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default quantity to current stock (if greater than 0) or 10.
    final defaultQty = widget.product.quantity > 0 ? widget.product.quantity : 10;
    _qtyController.text = defaultQty.toString();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _generateAndPrint() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final qty = int.tryParse(_qtyController.text) ?? 1;
    
    if (qty <= 0 || qty > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'الرجاء إدخال كمية صحيحة (1 - 1000)' : 'Please enter a valid quantity (1 - 1000)')),
      );
      return;
    }

    if (widget.product.barcode == null || widget.product.barcode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'هذا المنتج لا يملك باركود. يرجى تعديله وإضافة باركود أولاً.' : 'This product does not have a barcode. Please edit and add one first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final storeProfile = ref.read(storeProfileProvider).value;
      final storeName = storeProfile?.storeName ?? (isAr ? 'متجري' : 'My Store');
      final currency = ref.read(currencyProvider).code;

      final pdfBytes = _paperType == 'a4' 
          ? await BarcodePdfService.generateA4BarcodeSheet(
              product: widget.product,
              storeName: storeName.isEmpty ? (isAr ? 'متجري' : 'My Store') : storeName,
              currency: currency,
              quantity: qty,
              isAr: isAr,
            )
          : await BarcodePdfService.generateThermalBarcode(
              product: widget.product,
              storeName: storeName.isEmpty ? (isAr ? 'متجري' : 'My Store') : storeName,
              currency: currency,
              quantity: qty,
              isAr: isAr,
            );

      // Close dialog
      if (mounted) Navigator.pop(context);

      // Launch Print Preview
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: '${widget.product.name}_barcode',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'حدث خطأ أثناء توليد الباركود: $e' : 'Error generating barcode: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName == 'ar';
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.print_rounded, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'طباعة ملصقات الباركود' : 'Print Barcode Labels',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                    ),
                    Text(
                      widget.product.name,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Tajawal'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          if (widget.product.barcode == null || widget.product.barcode!.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr 
                        ? 'انتبه: هذا المنتج لا يحتوي على باركود مسجل. يرجى تعديله أولاً.' 
                        : 'Warning: This product has no barcode registered. Edit it first.',
                      style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'عدد الملصقات (النسخ):' : 'Number of Labels (Copies):',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers),
                    hintText: isAr ? 'أدخل العدد...' : 'Enter quantity...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  isAr ? 'نوع ورق الطباعة:' : 'Paper Type:',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                
                // Paper Type Selection
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _paperType = 'a4'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _paperType == 'a4' ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _paperType == 'a4' ? Colors.blue : Colors.grey.shade300, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.grid_on, color: _paperType == 'a4' ? Colors.blue : Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                isAr ? 'ورق A4' : 'A4 Sheet',
                                style: TextStyle(
                                  fontFamily: 'Tajawal', 
                                  fontWeight: FontWeight.bold,
                                  color: _paperType == 'a4' ? Colors.blue : null,
                                ),
                              ),
                              Text(
                                isAr ? 'شبكة ملصقات' : 'Label Grid',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _paperType = 'thermal'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _paperType == 'thermal' ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _paperType == 'thermal' ? Colors.blue : Colors.grey.shade300, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, color: _paperType == 'thermal' ? Colors.blue : Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                isAr ? 'رول حراري' : 'Thermal Roll',
                                style: TextStyle(
                                  fontFamily: 'Tajawal', 
                                  fontWeight: FontWeight.bold,
                                  color: _paperType == 'thermal' ? Colors.blue : null,
                                ),
                              ),
                              Text(
                                isAr ? 'ملصق مفرد 50x30' : 'Single 50x30',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isLoading || (widget.product.barcode == null || widget.product.barcode!.isEmpty) ? null : _generateAndPrint,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.print),
              label: Text(
                isAr ? 'تجهيز الطباعة' : 'Prepare Print',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
