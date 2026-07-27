import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/subscription_service.dart';
import '../../authentication/data/auth_repository.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(premiumProductDetailsProvider);
    final isGuest = ref.watch(authRepositoryProvider).currentUser?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ترقية الحساب', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, size: 80, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                'باقة تاجـــر برو 🚀',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: 16),
              const Text(
                'استمتع بإضافة منتجات وعملاء لا محدودين، مع دعم فني متقدم وإحصائيات مفصلة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: 32),
              
              if (isGuest) ...[
                const Text(
                  'يجب عليك ربط حسابك بـ Google أولاً لتتمكن من الاشتراك في الباقة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/upgrade'),
                  child: const Text('ربط الحساب الآن', style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ] else ...[
                productAsync.when(
                  data: (product) {
                    if (product == null) {
                      return const Text(
                        'لا يوجد اشتراكات متاحة حالياً. الرجاء المحاولة لاحقاً.',
                        style: TextStyle(fontFamily: 'Tajawal'),
                      );
                    }
                    
                    return Column(
                      children: [
                        Text(
                          '${product.price} / ${product.title}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(subscriptionServiceProvider).buyPremium(product);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          ),
                          child: const Text('اشترك الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(subscriptionServiceProvider).restorePurchases();
                          },
                          child: const Text('استعادة المشتريات السابقة', style: TextStyle(fontFamily: 'Tajawal')),
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text('حدث خطأ: $err', style: const TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
