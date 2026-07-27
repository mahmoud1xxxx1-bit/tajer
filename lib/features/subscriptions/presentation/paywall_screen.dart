import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/subscription_repository.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ترقية الحساب', style: TextStyle(fontFamily: 'Tajawal')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            const Text(
              'باقة تاجر برو',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 16),
            const Text(
              'افتح كافة ميزات التطبيق بلا حدود وتمتع بتجربة احترافية لإدارة تجارتك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 32),
            _FeatureRow(icon: Icons.check_circle, text: 'عدد لا محدود من المنتجات'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.check_circle, text: 'عدد لا محدود من العملاء والطلبات'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.check_circle, text: 'حفظ آمن للبيانات السحابية'),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // TODO: Trigger RevenueCat purchase flow
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم تفعيل الدفع لاحقاً')),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'اشترك الآن - 29 ريال/شهرياً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
      ],
    );
  }
}
