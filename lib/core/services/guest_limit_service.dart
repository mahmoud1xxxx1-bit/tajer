import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/auth_controller.dart';
import 'limits_service.dart';

class GuestLimitService {
  static Future<bool> canAddProduct(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddProduct(user));
  }

  static Future<bool> canAddCustomer(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddCustomer(user));
  }

  static Future<bool> canAddOrder(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddOrder(user));
  }

  static Future<bool> canAddExpense(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddExpense(user));
  }

  static Future<bool> canAddCategory(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddCategory(user));
  }

  static Future<bool> canAddSupplier(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddSupplier(user));
  }

  static Future<bool> canAddEmployee(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user) => ref.read(limitsServiceProvider).canAddEmployee(user));
  }

  static Future<bool> _checkLimit(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(dynamic user) checkFunction,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = ref.read(appUserProvider).value;
      if (user == null) {
        if (context.mounted) Navigator.pop(context);
        return false;
      }

      final canAdd = await checkFunction(user);
      
      if (context.mounted) {
        Navigator.pop(context); // close loading
      }

      if (!canAdd) {
        if (user.plan == 'banned_device') {
          if (context.mounted) _showBannedDeviceDialog(context, ref);
        } else {
          if (context.mounted) _showUpgradeDialog(context, ref);
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحقق من القيود: $e')),
        );
      }
      return false;
    }
  }

  static void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ترقية الباقة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.orange)),
        content: Text(
          'لقد وصلت للحد الأقصى المسموح به في الباقة المجانية. للتمتع بميزات لا محدودة، يرجى الترقية إلى الباقة الاحترافية (Pro).',
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            icon: Icon(Icons.star),
            label: Text('الترقية الآن (10\$/شهر)', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static void _showBannedDeviceDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('تم استهلاك الباقة المجانية', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          'عذراً، لقد تم اكتشاف استخدام سابق للباقة المجانية على هذا الجهاز. يرجى الترقية إلى الباقة الاحترافية (Pro) أو تسجيل الدخول بحسابك السابق لاستعادة بياناتك.',
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            icon: Icon(Icons.star),
            label: Text('الترقية الآن (10\$/شهر)', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

