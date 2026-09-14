import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IMPORTANT: Replace these with your actual RevenueCat API keys from the RevenueCat dashboard.
const String _appleApiKey = 'appl_YOUR_APPLE_API_KEY';
const String _googleApiKey = 'goog_aHEwHuppHHWdppTTPZJizeCDEGr';

class SubscriptionService {
  static const String _expirationKeyPrefix = 'tajer_subscription_expiration_';
  static bool _customerInfoListenerRegistered = false;

  Future<void> initPlatformState() async {
    if (kIsWeb) return; // RevenueCat is not supported on web

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      // Set the app user ID in RevenueCat to match Firebase UID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        configuration.appUserID = uid;
      }
      await Purchases.configure(configuration);

      // Keep the Firestore plan synchronized whenever RevenueCat refreshes CustomerInfo.
      if (!_customerInfoListenerRegistered) {
        Purchases.addCustomerInfoUpdateListener((customerInfo) {
          updatePlanFromCustomerInfo(customerInfo).catchError((e) {
            debugPrint('Failed to sync RevenueCat customer update: $e');
          });
        });
        _customerInfoListenerRegistered = true;
      }

      // Update our database based on the latest customer info.
      await _syncSubscriptionStatus();
    }
  }

  Future<bool?> refreshSubscriptionStatus() async {
    if (kIsWeb) return null;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo);
      return customerInfo.entitlements.all['premium']?.isActive == true;
    } on PlatformException catch (e) {
      debugPrint('Failed to refresh subscription status: $e');
      return _getCachedPremiumAccess();
    } catch (e) {
      debugPrint('Unexpected subscription refresh error: $e');
      return _getCachedPremiumAccess();
    }
  }

  Future<void> _syncSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo);
    } on PlatformException catch (e) {
      debugPrint("Failed to sync subscription status: $e");
    }
  }

  String? _currentUserExpirationKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return '$_expirationKeyPrefix$uid';
  }

  Future<bool?> _getCachedPremiumAccess() async {
    try {
      final key = _currentUserExpirationKey();
      if (key == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final expiration = prefs.getString(key);
      if (expiration == null || expiration.isEmpty) return null;
      final expiresAt = DateTime.tryParse(expiration);
      if (expiresAt == null) return null;
      return DateTime.now().isBefore(expiresAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> updatePlanFromCustomerInfo(CustomerInfo customerInfo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final premiumEntitlement = customerInfo.entitlements.all['premium'];
    final isPremiumActive = premiumEntitlement?.isActive == true;
    final expirationDate = premiumEntitlement?.expirationDate;

    // Cache the entitlement expiration locally so a known expired subscription
    // cannot remain premium merely because Firestore was last synced earlier.
    try {
      final prefs = await SharedPreferences.getInstance();
      final expirationKey = '$_expirationKeyPrefix$uid';
      if (expirationDate != null && expirationDate.isNotEmpty) {
        await prefs.setString(expirationKey, expirationDate);
      } else if (!isPremiumActive) {
        await prefs.remove(expirationKey);
      }
    } catch (e) {
      debugPrint('Failed to cache subscription expiration: $e');
    }

    // Default plan is merchant (free), unless they are active in the 'premium' entitlement.
    String currentPlan = isPremiumActive ? 'premium' : 'merchant';

    // Don't downgrade 'premium' if they are hardcoded as love.dotk@gmail.com.
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data()?['email'] == 'love.dotk@gmail.com') {
      currentPlan = 'premium';
    }

    // Don't override 'employee' plan, employees inherit from their merchant.
    if (userDoc.exists && userDoc.data()?['role'] == 'employee') {
      return;
    }

    // Update Firestore.
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'plan': currentPlan,
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
      print("Failed to get offerings: $e");
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo);
      return customerInfo.entitlements.all['premium']?.isActive == true;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("Failed to purchase: $e");
      }
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      await updatePlanFromCustomerInfo(customerInfo);
      return customerInfo.entitlements.all['premium']?.isActive == true;
    } on PlatformException catch (e) {
      print("Failed to restore purchases: $e");
      return false;
    }
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});
