import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/subscriptions/domain/billing_constants.dart';

// IMPORTANT: Replace these with your actual RevenueCat API keys from the RevenueCat dashboard.
const String _appleApiKey = 'appl_YOUR_APPLE_API_KEY';
const String _googleApiKey = 'goog_aHEwHuppHHWdppTTPZJizeCDEGr';

class SubscriptionService {
  Future<void> initPlatformState() async {
    if (kIsWeb) return; // RevenueCat is not supported on web

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (defaultTargetPlatform == TargetPlatform.android) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      // Set the app user ID in RevenueCat to match Firebase UID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        configuration.appUserID = uid;
      }
      await Purchases.configure(configuration);

      // Update our database based on the latest customer info
      await _syncSubscriptionStatus();
    }
  }

  Future<void> _syncSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo);
    } on PlatformException catch (e) {
      debugPrint('Failed to sync subscription status: $e');
    }
  }

  Future<void> updatePlanFromCustomerInfo(CustomerInfo customerInfo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    // Don't override 'employee' plan, employees inherit from their merchant
    if (userDoc.exists && userDoc.data()?['role'] == 'employee') {
      return;
    }

    // Default plan logic
    String targetPlan = user.isAnonymous ? 'guest' : 'merchant'; // merchant internally means free

    // Check if the user has active entitlements (e.g. they paid)
    if (customerInfo.entitlements.all[BillingConstants.entitlementMultiBranch]?.isActive == true) {
      targetPlan = 'multiBranch';
    } else if (customerInfo.entitlements.all[BillingConstants.entitlementMain]?.isActive == true) {
      targetPlan = 'main';
    }

    // Update Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'plan': targetPlan,
    });
  }

  Future<List<Offering>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return [offerings.current!];
      }
      return [];
    } on PlatformException catch (e) {
      debugPrint('Failed to get offerings: $e');
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo);
      return customerInfo.entitlements.all[BillingConstants.entitlementMultiBranch]?.isActive == true ||
          customerInfo.entitlements.all[BillingConstants.entitlementMain]?.isActive == true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Failed to purchase: $e');
      }
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      await updatePlanFromCustomerInfo(customerInfo);
      return customerInfo.entitlements.all[BillingConstants.entitlementMultiBranch]?.isActive == true ||
          customerInfo.entitlements.all[BillingConstants.entitlementMain]?.isActive == true;
    } on PlatformException catch (e) {
      debugPrint('Failed to restore purchases: $e');
      return false;
    }
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});
