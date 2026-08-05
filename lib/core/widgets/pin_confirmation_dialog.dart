import 'package:flutter/material.dart';

class PinConfirmationDialog extends StatefulWidget {
  final String correctPin;

  const PinConfirmationDialog({Key? key, required this.correctPin}) : super(key: key);

  static Future<bool> show(BuildContext context, String correctPin) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinConfirmationDialog(correctPin: correctPin),
    );
    return result ?? false;
  }

  @override
  State<PinConfirmationDialog> createState() => _PinConfirmationDialogState();
}

class _PinConfirmationDialogState extends State<PinConfirmationDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _hasError = false;

  void _verifyPin() {
    if (_pinController.text == widget.correctPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _hasError = true;
        _pinController.clear();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد الأمان', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('الرجاء إدخال الرقم السري المكون من 4 أرقام لتأكيد عملية الحذف:'),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 16),
            decoration: InputDecoration(
              errorText: _hasError ? 'الرقم السري غير صحيح' : null,
              counterText: '',
            ),
            onChanged: (val) {
              if (val.length == 4) {
                _verifyPin();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _pinController.text.length == 4 ? _verifyPin : null,
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}
