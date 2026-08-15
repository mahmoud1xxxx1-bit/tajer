import '../../../core/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tajer/l10n/app_localizations.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<Package> _packages = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _fetchOfferings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        setState(() {
          _packages = offerings.current!.availablePackages
              .where((pkg) => pkg.packageType == PackageType.monthly)
              .toList();
          if (_packages.isEmpty) {
            _packages = [offerings.current!.availablePackages.first];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _purchasePackage(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final isSuccess = await ref
          .read(subscriptionServiceProvider)
          .purchasePackage(package);
      if (!mounted) return;
      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.purchaseSuccess,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.purchaseError,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.purchaseError,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final isSuccess =
          await ref.read(subscriptionServiceProvider).restorePurchases();
      if (!mounted) return;
      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.restoreSuccess,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.restoreNoActive,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.restoreError,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final title = isAr ? 'تاجر برو' : 'Tajer Pro';
    final subtitle = isAr
        ? 'وسّع نشاطك واعمل بدون حدود الباقة المجانية.'
        : 'Grow your business without the free-plan limits.';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * _animationController.value),
                  child: child,
                );
              },
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: isDark ? 0.2 : 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _restorePurchases,
                        child: Text(
                          isAr ? 'استعادة المشتريات' : 'Restore purchases',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 64,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 15,
                                  height: 1.5,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.storefront_rounded,
                                color: Colors.blueAccent,
                                title: isAr
                                    ? 'منتجات وطلبات وعملاء بلا حدود'
                                    : 'Unlimited products, orders & customers',
                                subtitle: isAr
                                    ? 'أزل حدود الباقة المجانية عن المنتجات والطلبات والعملاء.'
                                    : 'Remove free-plan limits for products, orders and customers.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.group_add_rounded,
                                color: Colors.purpleAccent,
                                title: isAr
                                    ? 'حتى 3 موظفين مع صلاحيات دقيقة'
                                    : 'Up to 3 employees with permissions',
                                subtitle: isAr
                                    ? 'أضف موظفيك وحدد لكل موظف ما يستطيع الوصول إليه، بما في ذلك دفتر المحاسبة.'
                                    : 'Add employees and control exactly what each employee can access, including the Accounting Notebook.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.menu_book_rounded,
                                color: Colors.tealAccent.shade400,
                                title: isAr
                                    ? 'دفتر المحاسبة بلا حدود'
                                    : 'Unlimited Accounting Notebook',
                                subtitle: isAr
                                    ? 'دفاتر وحسابات وأشخاص وحركات محاسبية بلا حدود الباقة المجانية.'
                                    : 'Unlimited books, accounts, people and accounting transactions beyond free-plan limits.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.inventory_2_rounded,
                                color: Colors.orangeAccent,
                                title: isAr
                                    ? 'إدارة النشاط بدون حدود الباقة المجانية'
                                    : 'Business management without free-plan limits',
                                subtitle: isAr
                                    ? 'استمر في استخدام المصروفات والتصنيفات والموردين مع مزايا الحساب الاحترافي.'
                                    : 'Keep using expenses, categories and suppliers with Pro account capacity.',
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: _packages.isEmpty
                      ? Center(
                          child: Text(
                            isAr ? 'جاري تحميل الباقات...' : 'Loading plans...',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color:
                                  isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _packages.map((pkg) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _purchasePackage(pkg),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFFFDE047)
                                      : const Color(0xFFFACC15),
                                  foregroundColor: Colors.black87,
                                  elevation: 8,
                                  shadowColor:
                                      Colors.amber.withValues(alpha: 0.5),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18, horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(
                                        color: Colors.amber, width: 2),
                                  ),
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  children: [
                                    Text(
                                      isAr
                                          ? 'اشترك في تاجر برو -'
                                          : 'Subscribe to Tajer Pro -',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      pkg.storeProduct.priceString,
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isDark ? color : color.withValues(alpha: 0.9),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
