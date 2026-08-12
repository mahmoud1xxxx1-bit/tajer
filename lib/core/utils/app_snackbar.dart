import 'package:flutter/material.dart';

class AppSnackbar {
  /// Parses the error object and returns a user-friendly Arabic message
  static String _parseError(dynamic error) {
    final String errorString = error.toString().toLowerCase();

    // Offline / Firebase unavailable errors
    if (errorString.contains('cloud_firestore/unavailable') || 
        errorString.contains('network') || 
        errorString.contains('offline') ||
        errorString.contains('internet')) {
      return 'لا يوجد اتصال بالإنترنت، سيتم حفظ العملية للمزامنة لاحقاً.';
    }
    
    // Permission errors
    if (errorString.contains('permission-denied') || errorString.contains('permission denied')) {
      return 'عذراً، ليس لديك الصلاحية الكافية لإجراء هذه العملية.';
    }

    // Auth errors
    if (errorString.contains('user-not-found')) {
      return 'المستخدم غير موجود.';
    }
    if (errorString.contains('wrong-password')) {
      return 'كلمة المرور غير صحيحة.';
    }

    // Clean up "Exception: " prefix if it exists
    final cleanedError = error.toString().replaceAll('Exception: ', '').trim();
    if (cleanedError.isNotEmpty) {
       return cleanedError;
    }

    return 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.';
  }

  /// Displays a beautiful, glassmorphic error snackbar
  static void showError(BuildContext context, dynamic error) {
    final message = _parseError(error);
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Displays a beautiful success snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
