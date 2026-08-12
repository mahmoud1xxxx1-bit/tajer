import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/domain/app_user.dart';
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
    Future<bool> Function(AppUser user) checkFunction,
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
        } else if (user.isAnonymous) {
          if (context.mounted) _showLoginToContinueDialog(context, ref);
        } else {
          if (context.mounted) _showUpgradeDialog(context, ref);
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'خطأ في التحقق من القيود: $e' : 'Error checking limits: $e')),
        );
      }
      return false;
    }
  }

  static void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'ترقية الباقة' : 'Upgrade Plan', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.orange)),
        content: Text(
          isAr 
            ? 'لقد وصلت للحد الأقصى المسموح به في الباقة المجانية. للتمتع بميزات لا محدودة، يرجى الترقية إلى الباقة الاحترافية (Pro).'
            : 'You have reached the maximum limit of the free plan. To enjoy unlimited features, please upgrade to the Pro plan.',
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/paywall');
            },
            icon: Icon(Icons.star),
            label: Text(isAr ? 'الترقية الآن (25\$/شهر)' : 'Upgrade Now (\$25/mo)', style: TextStyle(fontFamily: 'Tajawal')),
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'تم استهلاك الباقة المجانية' : 'Free Plan Consumed', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          isAr 
            ? 'عذراً، لقد تم اكتشاف استخدام سابق للباقة المجانية على هذا الجهاز. يرجى الترقية إلى الباقة الاحترافية (Pro) أو تسجيل الدخول بحسابك السابق لاستعادة بياناتك.'
            : 'Sorry, previous usage of the free plan on this device was detected. Please upgrade to Pro or login with your previous account.',
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/paywall');
            },
            icon: Icon(Icons.star),
            label: Text(isAr ? 'الترقية الآن (25\$/شهر)' : 'Upgrade Now (\$25/mo)', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static void _showLoginToContinueDialog(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'الحد الأقصى للزوار' : 'Guest Limit Reached', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.blue)),
        content: Text(
          isAr 
            ? 'لقد وصلت للحد الأقصى المسموح به للزوار. قم بتأمين بياناتك وربط حسابك بجوجل مجاناً لتحصل على ضعف المميزات (10 منتجات، 20 طلباً... إلخ).'
            : 'You have reached the maximum guest limit. Secure your data and link your account to Google for free to get double the features.',
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/upgrade');
            },
            icon: Icon(Icons.g_mobiledata, size: 32),
            label: Text(isAr ? 'ربط الحساب مجاناً' : 'Link Account Free', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
