import 'package:flutter/material.dart';

class TaxDialogResult {
  final double percentage;
  final bool isInclusive;
  TaxDialogResult({required this.percentage, required this.isInclusive});
}

class TaxDialog extends StatefulWidget {
  const TaxDialog({super.key});

  @override
  State<TaxDialog> createState() => _TaxDialogState();

  static Future<TaxDialogResult?> show(BuildContext context) {
    return showDialog<TaxDialogResult>(
      context: context,
      builder: (context) => const TaxDialog(),
    );
  }
}

class _TaxDialogState extends State<TaxDialog> {
  final _taxController = TextEditingController();
  bool _isInclusive = false;

  @override
  void dispose() {
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(isAr ? 'إعدادات الضريبة' : 'Tax Settings', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isAr ? 'لم تقم بتحديد ضريبة للمنتجات، الرجاء تحديد نسبة الضريبة هنا (إذا رغبت بذلك):' : 'You did not set tax for products, please set it here (optional):', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
          const SizedBox(height: 16),
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
            activeColor: Colors.orange,
            onChanged: (val) => setState(() => _isInclusive = val),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, TaxDialogResult(percentage: 0.0, isInclusive: false)), // No tax
          child: Text(isAr ? 'تخطي / لا يوجد ضريبة' : 'Skip / No Tax', style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
        ),
        ElevatedButton(
          onPressed: () {
            final tax = double.tryParse(_taxController.text) ?? 0.0;
            Navigator.pop(context, TaxDialogResult(percentage: tax, isInclusive: _isInclusive));
          },
          child: Text(isAr ? 'موافق' : 'Confirm', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ],
    );
  }
}

