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

class _PaywallScreenState extends ConsumerState<PaywallScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Package> _packages = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _fetchOfferings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchOfferings() async {
    final subService = ref.read(subscriptionServiceProvider);
    final offerings = await subService.getOfferings();
    if (offerings.isNotEmpty && offerings.first.availablePackages.isNotEmpty) {
      if (mounted) {
        setState(() {
          _packages = offerings.first.availablePackages;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final subService = ref.read(subscriptionServiceProvider);
    final success = await subService.purchasePackage(package);
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?? ???????? ?????! ?????? ?? ?? ???? ???? ???.', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
      );
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('???? ????? ???????? ?? ?? ???????.', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final subService = ref.read(subscriptionServiceProvider);
    final success = await subService.restorePurchases();
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?? ??????? ??????? ?????!', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
      );
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('?? ??? ?????? ??? ???????? ????? ????.', style: TextStyle(fontFamily: 'Tajawal', color: Colors.amber.shade900)), backgroundColor: Colors.amber.shade100),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _restorePurchases,
            icon: Icon(Icons.restore_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
            label: Text('???????', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark 
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF111827)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF), const Color(0xFFF3F4F6)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      
                      // Hero Icon with Glow
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(isDark ? 0.3 : 0.2),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, size: 72, color: Colors.amber),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Titles
                      Text(
                        '???? ??? (Premium)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          '????? ??????? ???? ????? ????????? ????? ?? ????? ?????? ??? ????.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Features List
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GlassCard(
                            borderRadius: 24,
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildFeatureTile(
                                  context: context,
                                  icon: Icons.all_inclusive_rounded,
                                  color: Colors.blueAccent,
                                  title: '?????? ?????? ??? ????',
                                  subtitle: '??? ?? ???? ?? ???????? ??????? ????? ??? ?????? (?????? ?? 20 ?? ???????).',
                                ),
                                _buildFeatureTile(
                                  context: context,
                                  icon: Icons.group_add_rounded,
                                  color: Colors.purpleAccent,
                                  title: '????? ???????? ??????????',
                                  subtitle: '??? ??????? ?????????? ???? ????????? ????? ????? ??? ??????? ???????.',
                                ),
                                _buildFeatureTile(
                                  context: context,
                                  icon: Icons.inventory_2_rounded,
                                  color: Colors.orangeAccent,
                                  title: '????? ????? ????? ??? ????',
                                  subtitle: '???? ????? ?????? ?????? ????? ??????? ?????? ????? ????? ????? ????????.',
                                ),
                                _buildFeatureTile(
                                  context: context,
                                  icon: Icons.wifi_off_rounded,
                                  color: Colors.greenAccent.shade400,
                                  title: '???? ???? ?????? (Offline)',
                                  subtitle: '?? ??? ?????? ???????? ???? ???????. ???? ?????? ????? ???????? ??????.',
                                ),
                                _buildFeatureTile(
                                  context: context,
                                  icon: Icons.receipt_long_rounded,
                                  color: Colors.indigoAccent,
                                  title: '???????? ???????? ??????? (ZATCA)',
                                  subtitle: '???? ?????? ????? ??????? ??????? ?? ???? ?????? ????? ?? QR Code ??????.',
                                ),
                                _buildFeatureTile(
                                  context: context,
                                  icon: Icons.support_agent_rounded,
                                  color: Colors.tealAccent.shade400,
                                  title: '?????? ?????? ?? ????? ?????',
                                  subtitle: '???? ??? ?????? ????? ???????? ?????? ????? ??? ????? ??? ????.',
                                ),
                              ],
                            ),
                          ),
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
                            ? Center(child: Text('???? ????? ???????...', style: TextStyle(fontFamily: 'Tajawal', color: isDark ? Colors.white54 : Colors.black54)))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _packages.map((pkg) {
                                  final isAnnual = pkg.packageType == PackageType.annual;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ElevatedButton(
                                      onPressed: () => _purchasePackage(pkg),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? const Color(0xFFFDE047) : const Color(0xFFFACC15), // Elegant gold/amber
                                        foregroundColor: Colors.black87,
                                        elevation: isAnnual ? 8 : 2,
                                        shadowColor: Colors.amber.withOpacity(0.5),
                                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: isAnnual ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '????????  - ',
                                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            pkg.storeProduct.priceString,
                                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w900),
                                          ),
                                          if (isAnnual) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black87,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text('??? ??????!', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                            ),
                                          ]
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
              ),
        ),
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
