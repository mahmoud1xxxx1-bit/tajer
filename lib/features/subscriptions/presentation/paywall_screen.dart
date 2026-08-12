import '../../../core/theme/glass_card.dart';
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

class _PaywallScreenState extends ConsumerState<PaywallScreen> with SingleTickerProviderStateMixin {
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
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        setState(() {
          // Only show the monthly package, exactly as the user requested.
          _packages = offerings.current!.availablePackages.where((pkg) => pkg.packageType == PackageType.monthly).toList();
          if (_packages.isEmpty) {
             // Fallback if no explicit "monthly" package type is found, show the first package.
             _packages = [offerings.current!.availablePackages.first];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching offerings: $e");
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchasePackage(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final isSuccess = await ref.read(subscriptionServiceProvider).purchasePackage(package);
      if (isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(l10n.purchaseSuccess, style: const TextStyle(fontFamily: 'Tajawal'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.purchaseError}: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final isSuccess = await ref.read(subscriptionServiceProvider).restorePurchases();
      if (isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(l10n.restoreSuccess, style: const TextStyle(fontFamily: 'Tajawal'))),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(l10n.restoreNoActive, style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.restoreError}: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Animation
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
                      Colors.amber.withOpacity(isDark ? 0.2 : 0.4),
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
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _restorePurchases,
                        child: Text(
                          'استعادة المشتريات',
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
                
                // Content
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
                                  color: Colors.amber.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.workspace_premium_rounded, size: 64, color: Colors.amber),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'انضم إلى تاجر برو',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'أطلق العنان لكامل إمكانيات متجرك وتحكم بكل شيء بسهولة واحترافية!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 15,
                                  height: 1.5,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 40),
                              
                              // Features List
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.storefront_rounded,
                                color: Colors.blueAccent,
                                title: 'منتجات وطلبات بلا حدود',
                                subtitle: 'أضف ما تشاء من المنتجات واستقبل طلبات غير محدودة.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.group_add_rounded,
                                color: Colors.purpleAccent,
                                title: 'إدارة الموظفين والصلاحيات',
                                subtitle: 'أضف الكاشير والمحاسبين وحدد صلاحياتهم بدقة، وراقب سجل حركاتهم بالكامل.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.inventory_2_rounded,
                                color: Colors.orangeAccent,
                                title: 'إدارة مخزون ومواد خام ذكية',
                                subtitle: 'تتبع كميات المواد الخام، وتلقَ تنبيهات النقص، واصنع وصفات دقيقة لمنتجاتك.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.wifi_off_rounded,
                                color: Colors.greenAccent.shade400,
                                title: 'يعمل بدون إنترنت (Offline)',
                                subtitle: 'لا تدع انقطاع الإنترنت يوقف مبيعاتك. اعمل بكفاءة وستتم المزامنة لاحقاً.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.receipt_long_rounded,
                                color: Colors.indigoAccent,
                                title: 'الفواتير الضريبية المبسطة (ZATCA)',
                                subtitle: 'اطبع فواتير رسمية للعملاء متوافقة مع هيئة الزكاة مزودة بـ QR Code متوافق.',
                              ),
                              _buildFeatureTile(
                                context: context,
                                icon: Icons.support_agent_rounded,
                                color: Colors.tealAccent.shade400,
                                title: 'أولوية القصوى في الدعم الفني',
                                subtitle: 'احصل على مساعدة فورية وتحديثات مستمرة لضمان عمل متجرك دون توقف.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Packages Area
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: _packages.isEmpty
                      ? Center(child: Text('جاري تحميل الباقات...', style: TextStyle(fontFamily: 'Tajawal', color: isDark ? Colors.white54 : Colors.black54)))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _packages.map((pkg) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ElevatedButton(
                                onPressed: () => _purchasePackage(pkg),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFFFDE047) : const Color(0xFFFACC15),
                                  foregroundColor: Colors.black87,
                                  elevation: 8,
                                  shadowColor: Colors.amber.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Colors.amber, width: 2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'الاشتراك في تاجر برو - ',
                                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      pkg.storeProduct.priceString,
                                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w900),
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
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
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
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: isDark ? color : color.withOpacity(0.9), size: 24),
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
