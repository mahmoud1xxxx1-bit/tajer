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
        currentCount = await ref.read(productRepositoryProvider).getProductCount(user.uid);
      } else if (type == 'customers') {
        currentCount = await ref.read(customerRepositoryProvider).getCustomerCount(user.uid);
      } else if (type == 'orders') {
        currentCount = await ref.read(orderRepositoryProvider).getOrderCount(user.uid);
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
        title: const Text('وصلت للحد الأقصى!', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: const Text(
          'حسابك الحالي هو حساب ضيف تجريبي. لقد وصلت للحد الأقصى المسموح به للإضافات.\n\nيرجى ربط حسابك بـ Google للاستمرار في استخدام التطبيق مجاناً وبدون قيود، وحفظ بياناتك من الضياع.',
          style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _linkWithGoogle(context, ref);
            },
            icon: const Icon(Icons.login),
            label: const Text('ربط بحساب Google', style: TextStyle(fontFamily: 'Tajawal')),
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
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authControllerProvider.notifier).linkWithGoogle();
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم ترقية الحساب بنجاح! يمكنك الآن الاستمرار بلا قيود.', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الربط: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
