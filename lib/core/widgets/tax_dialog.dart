import 'package:flutter/material.dart';

class TaxDialog extends StatefulWidget {
  const TaxDialog({super.key});

  @override
  State<TaxDialog> createState() => _TaxDialogState();

  static Future<double?> show(BuildContext context) {
    return showDialog<double>(
      context: context,
      builder: (context) => const TaxDialog(),
    );
  }
}

class _TaxDialogState extends State<TaxDialog> {
  final _taxController = TextEditingController();

  @override
  void dispose() {
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(isAr ? 'إضافة ضريبة؟' : 'Add Tax?', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isAr ? 'هل تريد إضافة نسبة ضريبة لهذه الطباعة؟' : 'Do you want to add tax percentage for this print?', style: const TextStyle(fontFamily: 'Tajawal')),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0.0), // No tax
          child: Text(isAr ? 'تخطي / لا يوجد ضريبة' : 'Skip / No Tax', style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
        ),
        ElevatedButton(
          onPressed: () {
            final tax = double.tryParse(_taxController.text);
            Navigator.pop(context, tax ?? 0.0);
          },
          child: Text(isAr ? 'موافق' : 'Confirm', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ],
    );
  }
}
