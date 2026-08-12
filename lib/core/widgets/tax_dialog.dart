import 'package:flutter/material.dart';

class TaxDialogResult {
  final double percentage;
  final bool isInclusive;
  final String? vatNumber;
  TaxDialogResult({required this.percentage, required this.isInclusive, this.vatNumber});
}

class TaxDialog extends StatefulWidget {
  final bool showVatNumberField;
  const TaxDialog({super.key, this.showVatNumberField = false});

  @override
  State<TaxDialog> createState() => _TaxDialogState();

  static Future<TaxDialogResult?> show(BuildContext context, {bool showVatNumberField = false}) {
    return showDialog<TaxDialogResult>(
      context: context,
      builder: (context) => TaxDialog(showVatNumberField: showVatNumberField),
    );
  }
}

class _TaxDialogState extends State<TaxDialog> {
  final _taxController = TextEditingController();
  final _vatController = TextEditingController();
  bool _isInclusive = false;

  @override
  void dispose() {
    _taxController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(isAr ? 'إعدادات الضريبة' : 'Tax Settings', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAr ? 'الرجاء تحديد إعدادات الضريبة (إذا رغبت بذلك):' : 'Please set tax settings (optional):', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
            const SizedBox(height: 16),
            if (widget.showVatNumberField) ...[
              TextField(
                controller: _vatController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isAr ? 'الرقم الضريبي (اختياري)' : 'VAT Number (Optional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _taxController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isAr ? 'نسبة الضريبة (%)' : 'Tax Percentage (%)',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.percent),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(isAr ? 'السعر يشمل الضريبة' : 'Price is Tax Inclusive', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
              subtitle: Text(
                isAr ? 'إذا تم التفعيل، سيتم استخراج الضريبة من السعر الأساسي. وإلا ستضاف فوق السعر.' : 'If enabled, tax is extracted from base price. Else, it is added on top.',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey),
              ),
              value: _isInclusive,
              activeThumbColor: Colors.orange,
              onChanged: (val) => setState(() => _isInclusive = val),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, TaxDialogResult(percentage: 0.0, isInclusive: false, vatNumber: null)),
          child: Text(isAr ? 'تخطي / لا يوجد ضريبة' : 'Skip / No Tax', style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
        ),
        ElevatedButton(
          onPressed: () {
            final tax = double.tryParse(_taxController.text) ?? 0.0;
            final vat = _vatController.text.trim();
            Navigator.pop(context, TaxDialogResult(percentage: tax, isInclusive: _isInclusive, vatNumber: vat.isEmpty ? null : vat));
          },
          child: Text(isAr ? 'موافق' : 'Confirm', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ],
    );
  }
}

