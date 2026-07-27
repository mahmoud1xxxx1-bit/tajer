import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/auth_controller.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/customers/data/customer_repository.dart';
import '../../features/orders/data/order_repository.dart';

class GuestLimitService {
  static Future<bool> canAddProduct(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, limit: 3, type: 'products');
  }

  static Future<bool> canAddCustomer(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, limit: 20, type: 'customers');
  }

  static Future<bool> canAddOrder(BuildContext context, WidgetRef ref) async {
    return _checkLimit(context, ref, limit: 20, type: 'orders');
  }

  static Future<bool> _checkLimit(
    BuildContext context,
    WidgetRef ref, {
    required int limit,
    required String type,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return false;

    // If not anonymous, no limits apply for now (can expand later based on plans)
    if (!user.isAnonymous) return true;

    int currentCount = 0;
    try {
      if (type == 'products') {
        currentCount = await ref.read(productRepositoryProvider).getProductCount(userId);
      } else if (type == 'customers') {
        currentCount = await ref.read(customerRepositoryProvider).getCustomerCount(userId);
      } else if (type == 'orders') {
        currentCount = await ref.read(orderRepositoryProvider).getOrderCount(userId);
      }
    } catch (e) {
      // If error fetching count, allow or deny? We deny to be safe and notify user.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التحقق من القيود: $e')),
      );
      return false;
    }

    if (currentCount >= limit) {
      _showUpgradeDialog(context, ref);
      return false;
    }

    return true;
  }

  static void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.text_1, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text(
          AppLocalizations.of(context)!.text_2,
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.text_3, style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _linkWithGoogle(context, ref);
            },
            icon: Icon(Icons.login),
            label: Text(AppLocalizations.of(context)!.text_4, style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _linkWithGoogle(BuildContext context, WidgetRef ref) async {
    // Show a loading overlay or just use the controller
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authControllerProvider.notifier).linkWithGoogle();
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.text_5, style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الربط: $e', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

