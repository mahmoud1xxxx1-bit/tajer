import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/domain/app_user.dart';
import '../../features/authentication/presentation/auth_controller.dart';
import '../../features/branches/presentation/branch_context.dart';
import 'limits_service.dart';

class GuestLimitService {
  static Future<bool> canAddProduct(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddProduct(user as AppUser, branchId));
  }

  static Future<bool> canAddCustomer(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddCustomer(user as AppUser, branchId));
  }

  static Future<bool> canAddOrder(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddOrder(user as AppUser, branchId));
  }

  static Future<bool> canAddExpense(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddExpense(user as AppUser, branchId));
  }

  static Future<bool> canAddCategory(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddCategory(user as AppUser, branchId));
  }

  static Future<bool> canAddSupplier(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddSupplier(user as AppUser, branchId));
  }

  static Future<bool> canAddEmployee(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, (user, branchId) => ref.read(limitsServiceProvider).canAddEmployee(user as AppUser, branchId));
  }

  static Future<bool> _checkLimit(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(AppUser user, String branchId) checkFunction,
  ) async {
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

      final branchId = ref.read(selectedBranchIdProvider);
      final canAdd = await checkFunction(user, branchId);
      
      if (context.mounted) {
        Navigator.pop(context); 
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
        Navigator.pop(context); 
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
            ? 'لقد وصلت للحد الأقصى المسموح به في الباقة الحالية. للتمتع بميزات لا محدودة، يرجى الترقية.'
            : 'You have reached the maximum limit for your current plan. To enjoy unlimited features, please upgrade.',
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
            label: Text(isAr ? 'الترقية الآن' : 'Upgrade Now', style: TextStyle(fontFamily: 'Tajawal')),
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
            ? 'عذراً، لقد تم اكتشاف استخدام سابق للباقة المجانية على هذا الجهاز. يرجى الترقية.'
            : 'Sorry, previous usage of the free plan on this device was detected. Please upgrade.',
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
            label: Text(isAr ? 'الترقية الآن' : 'Upgrade Now', style: TextStyle(fontFamily: 'Tajawal')),
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
