// Removed dart:io to support web build
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/data/auth_repository.dart';

class SubscriptionService {
  final AuthRepository _authRepo;
  final FirebaseFirestore _firestore;

  // IMPORTANT: The user must replace these with their actual RevenueCat Public API Keys
  static const String _revenueCatAppleApiKey = 'appl_api_key_here';
  static const String _revenueCatGoogleApiKey = 'goog_api_key_here';

  SubscriptionService(this._authRepo, this._firestore) {
    if (!kIsWeb) {
      _initRevenueCat();
    }
  }

  Future<void> _initRevenueCat() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (defaultTargetPlatform == TargetPlatform.android) {
      configuration = PurchasesConfiguration(_revenueCatGoogleApiKey);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      configuration = PurchasesConfiguration(_revenueCatAppleApiKey);
    } else {
      return;
    }
    
    // Use the merchant's UID as the App User ID in RevenueCat
    final user = _authRepo.currentUser;
    if (user != null) {
      configuration.appUserID = user.uid;
    }
    
    await Purchases.configure(configuration);
    
    // Listen to changes in customer info
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _checkPremiumEntitlement(customerInfo);
    });
  }

  Future<void> _checkPremiumEntitlement(CustomerInfo customerInfo) async {
    final user = _authRepo.currentUser;
    if (user == null) return;

    // Check if the user has active 'premium' entitlement in RevenueCat
    final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;

    // Sync status with Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'plan': isPremium ? 'premium' : 'merchant',
    });
  }

  Future<List<Package>> fetchPackages() async {
    if (kIsWeb) return [];
    
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint("Error fetching RevenueCat offerings: $e");
    }
    return [];
  }

  Future<bool> buyPackage(Package package) async {
    if (kIsWeb) return false;
    
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;
      final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      if (isPremium) {
        await _checkPremiumEntitlement(customerInfo);
        return true;
      }
    } catch (e) {
      debugPrint("Error purchasing package: $e");
    }
    return false;
  }
  
  Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      await _checkPremiumEntitlement(customerInfo);
      return isPremium;
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
    }
    return false;
  }

  void dispose() {
    Purchases.removeCustomerInfoUpdateListener((_) {});
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final service = SubscriptionService(authRepo, FirebaseFirestore.instance);
  ref.onDispose(() => service.dispose());
  return service;
});

final premiumPackagesProvider = FutureProvider<List<Package>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.fetchPackages();
});
