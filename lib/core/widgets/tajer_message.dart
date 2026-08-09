import 'package:flutter/material.dart';

import '../services/app_error_mapper.dart';

abstract final class TajerMessage {
  static Future<void> show(
    BuildContext context,
    TajerUserMessage message,
  ) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final color = _color(message.type);
    final icon = _icon(message.type);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.title(isAr),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message.message(isAr),
          style: const TextStyle(fontFamily: 'Tajawal', height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isAr ? 'حسنًا' : 'OK'),
          ),
        ],
      ),
    );
  }

  static void success(
    BuildContext context,
    TajerUserMessage message,
  ) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _color(message.type),
        content: Row(
          children: [
            Icon(_icon(message.type), color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.message(isAr),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _color(TajerMessageType type) {
    switch (type) {
      case TajerMessageType.success:
        return Colors.green.shade700;
      case TajerMessageType.error:
        return Colors.red.shade700;
      case TajerMessageType.warning:
        return Colors.orange.shade800;
      case TajerMessageType.info:
        return Colors.blue.shade700;
      case TajerMessageType.validation:
        return Colors.amber.shade800;
    }
  }

  static IconData _icon(TajerMessageType type) {
    switch (type) {
      case TajerMessageType.success:
        return Icons.check_circle_rounded;
      case TajerMessageType.error:
        return Icons.error_outline_rounded;
      case TajerMessageType.warning:
        return Icons.warning_amber_rounded;
      case TajerMessageType.info:
        return Icons.info_outline_rounded;
      case TajerMessageType.validation:
        return Icons.rule_rounded;
    }
  }
}
