import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/glass_card.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = true;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final subService = ref.read(subscriptionServiceProvider);
    final offerings = await subService.getOfferings();
    if (offerings.isNotEmpty && offerings.first.availablePackages.isNotEmpty) {
      setState(() {
        _packages = offerings.first.availablePackages;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final subService = ref.read(subscriptionServiceProvider);
    final success = await subService.purchasePackage(package);
    setState(() => _isLoading = false);
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الاشتراك بنجاح! شكراً لك.', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.green),
        );
        context.go('/dashboard');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشلت عملية الاشتراك أو تم إلغاؤها.', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final subService = ref.read(subscriptionServiceProvider);
    final success = await subService.restorePurchases();
    setState(() => _isLoading = false);
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استعادة مشترياتك بنجاح!', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.green),
        );
        context.go('/dashboard');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على اشتراكات سابقة.', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ترقية الحساب (Premium)', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: const Text('استعادة المشتريات', style: TextStyle(fontFamily: 'Tajawal', color: Colors.blue)),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade900,
              Colors.purple.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text(
                    'ارتقِ بتجارتك للقمة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'احصل على جميع الميزات المتقدمة وأدر متجرك باحترافية كاملة بدون قيود.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Features List
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GlassCard(
                        child: ListView(
                          children: const [
                            _FeatureRow(icon: Icons.all_inclusive, text: 'عدد لا محدود من الطلبات والمنتجات (مقارنة بـ 20 طلب للنسخة المجانية)'),
                            _FeatureRow(icon: Icons.group_add, text: 'إضافة موظفين للمتجر وتحديد صلاحياتهم بدقة'),
                            _FeatureRow(icon: Icons.inventory_2, text: 'إدارة متقدمة للمواد الخام والمخزون والتنبيهات'),
                            _FeatureRow(icon: Icons.wifi_off, text: 'العمل بكفاءة تامة بدون إنترنت (Offline Mode)'),
                            _FeatureRow(icon: Icons.bar_chart, text: 'إغلاق الورديات (Z-Report) وتقارير أرباح متقدمة'),
                            _FeatureRow(icon: Icons.support_agent, text: 'أولوية في الدعم الفني والحصول على التحديثات'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Packages
                  if (_packages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('لا توجد باقات متاحة حالياً. يرجى التأكد من إعداد RevenueCat.', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        children: _packages.map((pkg) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => _purchasePackage(pkg),
                              child: Text(
                                'الاشتراك بـ ${pkg.storeProduct.priceString} / ${pkg.packageType == PackageType.annual ? "سنوياً" : "شهرياً"}',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                ],
              ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
