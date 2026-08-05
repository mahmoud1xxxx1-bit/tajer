import 'package:flutter/material.dart';
import '../../features/authentication/domain/app_user.dart';
import '../services/pin_service.dart';

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

  static Future<bool> requirePinOrSetup(BuildContext context, AppUser appUser, {String? title, String? warning}) async {
    String? pin = await PinService.getDeletePin(appUser);
    if (pin == null || pin.isEmpty) {
      // Force setup
      final setupSuccess = await _showSetupPinDialog(context, appUser);
      if (!setupSuccess) return false;
      pin = await PinService.getDeletePin(appUser);
      if (pin == null || pin.isEmpty) return false;
    }
    
    if (!context.mounted) return false;
    return await show(context, pin, title: title, warning: warning);
  }

  static Future<bool> _showSetupPinDialog(BuildContext context, AppUser appUser) async {
    final TextEditingController pinController = TextEditingController();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'إعداد رمز حماية الحذف' : 'Setup Deletion PIN', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAr 
                ? 'أنت على وشك تنفيذ عملية حساسة. لضمان حماية النظام من عبث الموظفين، يرجى إعداد رمز حماية الحذف (PIN) أولاً والذي سيتم طلبه في أي عملية مسح مستقبلاً.'
                : 'You are about to perform a sensitive operation. To secure the system, please setup a deletion PIN first which will be required for any future deletions.',
                style: TextStyle(fontFamily: 'Tajawal', color: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800, height: 1.5, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, letterSpacing: 4),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: isAr ? 'أدخل 4 أرقام' : 'Enter 4 digits',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (pinController.text.length == 4) {
                await PinService.setDeletePin(appUser, pinController.text);
                Navigator.pop(context, true);
              }
            },
            child: Text(isAr ? 'حفظ ومتابعة' : 'Save & Continue', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
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
