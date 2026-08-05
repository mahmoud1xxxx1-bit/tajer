import 'package:flutter/material.dart';

class PinConfirmationDialog extends StatefulWidget {
  final String correctPin;
  final String warningTitle;
  final String warningText;

  const PinConfirmationDialog({
    Key? key, 
    required this.correctPin,
    required this.warningTitle,
    required this.warningText,
  }) : super(key: key);

  static Future<bool> show(BuildContext context, String correctPin, {String? title, String? warning}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinConfirmationDialog(
        correctPin: correctPin,
        warningTitle: title ?? 'تأكيد الحذف',
        warningText: warning ?? 'هل أنت متأكد من رغبتك في إتمام هذه العملية؟',
      ),
    );
    return result ?? false;
  }

  @override
  State<PinConfirmationDialog> createState() => _PinConfirmationDialogState();
}

class _PinConfirmationDialogState extends State<PinConfirmationDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _hasError = false;
  bool _isObscured = true;

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.warningTitle, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              widget.warningText,
              style: TextStyle(
                color: isDarkMode ? Colors.red.shade300 : Colors.red.shade900,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'أدخل رمز الأمان (PIN) للتأكيد:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: _isObscured,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              errorText: _hasError ? 'الرمز غير صحيح' : null,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
              suffixIcon: IconButton(
                icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
              ),
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
          child: Text('تراجع', style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _pinController.text.length == 4 ? _verifyPin : null,
          child: const Text('تأكيد وحذف', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
