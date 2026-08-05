import '../../../core/theme/glass_card.dart';
import '../../../core/services/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../core/services/revenue_cat_service.dart';
import '../../core/theme/glass_card.dart';

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

  Future<void> _purchasePackage(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final isSuccess = await RevenueCatService.purchasePackage(package);
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
      final isSuccess = await RevenueCatService.restorePurchases();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      GlassCard(
                        borderRadius: 24,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    l10n.monthlyPlanTitle,
                                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildFeatureRow(l10n.featureUnlimitedOrders),
                              _buildFeatureRow(l10n.featureInventorySync),
                              _buildFeatureRow(l10n.featureAdvancedReports),
                              _buildFeatureRow(l10n.featurePrioritySupport),
                              const SizedBox(height: 24),
                              
                              if (_packages.isNotEmpty)
                                ..._packages.map((pkg) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : () => _purchasePackage(pkg),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          l10n.subscribeFor(pkg.storeProduct.priceString),
                                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, size: 20),
                                      ],
                                    ),
                                  ),
                                )).toList()
                              else
                                Center(
                                  child: Text(
                                    l10n.noPackagesAvailable,
                                    style: TextStyle(fontFamily: 'Tajawal', color: Theme.of(context).colorScheme.error),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
