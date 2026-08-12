import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/subscriptions/domain/billing_constants.dart';

// RevenueCat public SDK keys are safe to ship in the client. Secret API keys
// must remain server-side only and are consumed by Cloud Functions.
const String _appleApiKey = 'appl_YOUR_APPLE_API_KEY';
const String _googleApiKey = 'goog_aHEwHuppHHWdppTTPZJizeCDEGr';

class SubscriptionService {
  Future<void> initPlatformState() async {
    if (kIsWeb) return; // RevenueCat Flutter SDK is not used on web.

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (defaultTargetPlatform == TargetPlatform.android) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        configuration.appUserID = uid;
      }
      await Purchases.configure(configuration);
      await _syncSubscriptionStatus(source: 'client_refresh');
    }
  }

  Future<void> _syncSubscriptionStatus({required String source}) async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo, source: source);
    } on PlatformException catch (e) {
      debugPrint('Failed to sync subscription status: $e');
    }
  }

  String _targetPlanFromCustomerInfo(CustomerInfo customerInfo, User user) {
    if (customerInfo.entitlements.all[BillingConstants.entitlementMultiBranch]?.isActive == true) {
      return 'multiBranch';
    }
    if (customerInfo.entitlements.all[BillingConstants.entitlementMain]?.isActive == true) {
      return 'main';
    }
    return user.isAnonymous ? 'guest' : 'merchant';
  }

  Future<void> updatePlanFromCustomerInfo(
    CustomerInfo customerInfo, {
    String source = 'client_refresh',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userDoc = await userRef.get();
    final data = userDoc.data();

    // Employees inherit subscription access from their merchant and must never
    // attempt to change the merchant entitlement state.
    if (userDoc.exists && data?['role'] == 'employee') {
      return;
    }

    final localTarget = _targetPlanFromCustomerInfo(customerInfo, user);
    final currentPlan = data?['plan'] as String?;
    final verifiedPlan = data?['verifiedPlan'] as String?;

    // The RevenueCat SDK is only a client-side signal. It is intentionally not
    // trusted to write plan/entitlement fields. If Firestore does not already
    // reflect the locally observed state, request a server-side verification.
    if (currentPlan == localTarget && verifiedPlan == localTarget) {
      return;
    }

    await userRef.update({
      'subscriptionSyncRequestedAt': FieldValue.serverTimestamp(),
      'subscriptionSyncSource': source,
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
      await updatePlanFromCustomerInfo(customerInfo, source: 'purchase');
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
      await updatePlanFromCustomerInfo(customerInfo, source: 'restore');
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
