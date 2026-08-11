import '../../../core/theme/glass_card.dart';
import '../../../core/services/subscription_service.dart';
import '../domain/billing_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tajer/l10n/app_localizations.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        setState(() {
          _packages = offerings.current!.availablePackages;
        });
      }
    } catch (e) {
      debugPrint("Error fetching offerings: $e");
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchasePackage(Package? package) async {
    if (package == null) return;
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
          SnackBar(content: Text('${l10n.purchaseError}', style: const TextStyle(fontFamily: 'Tajawal'))), // Safe failure message, no raw errors
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
          SnackBar(content: Text('${l10n.restoreError}', style: const TextStyle(fontFamily: 'Tajawal'))), // Safe failure message
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required List<String> features,
    required Package? package,
    required Color color,
    required AppLocalizations l10n,
  }) {
    final priceString = package != null ? package.storeProduct.priceString : l10n.pricePendingStore;

    return GlassCard(
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...features.map((f) => _buildFeatureRow(f)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isLoading || package == null) ? null : () => _purchasePackage(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    package != null ? l10n.subscribeFor(priceString) : priceString,
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Package? _getPackage(String entitlementId) {
    try {
      return _packages.firstWhere((p) => p.packageType == PackageType.monthly && p.identifier.contains(entitlementId) || p.identifier == entitlementId);
    } catch (e) {
      return _packages.isNotEmpty ? _packages.first : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // We try to find the specific packages based on our setup.
    // If exact IDs aren't matching due to manual setup not done, we fallback safely.
    Package? mainPackage;
    Package? multiPackage;
    
    try {
      mainPackage = _packages.firstWhere((p) => p.identifier == BillingConstants.entitlementMain || p.identifier == '\$rc_monthly');
    } catch (_) {}
    try {
      multiPackage = _packages.firstWhere((p) => p.identifier == BillingConstants.entitlementMultiBranch);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscriptionTitle, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading && _packages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.amber),
                      const SizedBox(height: 24),
                      Text(
                        l10n.premiumAccessTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.premiumAccessDesc,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildPlanCard(
                        title: (l10n as dynamic).paywallMainPlan,
                        features: [
                          (l10n as dynamic).paywallMainDesc1,
                          (l10n as dynamic).paywallMainDesc2,
                          (l10n as dynamic).paywallMainDesc3,
                          (l10n as dynamic).paywallMainDesc4,
                          (l10n as dynamic).paywallMainDesc5,
                        ],
                        package: mainPackage,
                        color: Colors.amber.shade800,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 24),
                      _buildPlanCard(
                        title: (l10n as dynamic).paywallMultiPlan,
                        features: [
                          (l10n as dynamic).paywallMultiDesc1,
                          (l10n as dynamic).paywallMultiDesc2,
                          (l10n as dynamic).paywallMultiDesc3,
                          (l10n as dynamic).paywallMultiDesc4,
                          (l10n as dynamic).paywallMultiDesc5,
                          (l10n as dynamic).paywallMultiDesc6,
                        ],
                        package: multiPackage,
                        color: Colors.purple.shade700,
                        l10n: l10n,
                      ),

                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: _isLoading ? null : _restorePurchases,
                        child: Text(
                          l10n.restorePurchasesBtn,
                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.subscriptionTermsDesc,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), height: 1.5),
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
}
