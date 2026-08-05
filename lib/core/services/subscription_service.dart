import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// IMPORTANT: Replace these with your actual RevenueCat API keys from the RevenueCat dashboard.
const String _appleApiKey = 'appl_YOUR_APPLE_API_KEY';
const String _googleApiKey = 'goog_aHEwHuppHHWdppTTPZJizeCDEGr';

class SubscriptionService {
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
      
      // Update our database based on the latest customer info
      await _syncSubscriptionStatus();
    }
  }

  Future<void> _syncSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePlanFromCustomerInfo(customerInfo);
    } on PlatformException catch (e) {
      print("Failed to sync subscription status: $e");
    }
  }

  Future<void> updatePlanFromCustomerInfo(CustomerInfo customerInfo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Default plan is merchant (free), unless they are active in the 'premium' entitlement
    String currentPlan = 'merchant';
    
    // Check if the user has active entitlements (e.g. they paid)
    if (customerInfo.entitlements.all['premium']?.isActive == true) {
      currentPlan = 'premium';
    }

    // Don't downgrade 'premium' if they are hardcoded as love.dotk@gmail.com
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data()?['email'] == 'love.dotk@gmail.com') {
      currentPlan = 'premium';
    }
    
    // Don't override 'employee' plan, employees inherit from their merchant
    if (userDoc.exists && userDoc.data()?['role'] == 'employee') {
      return; 
    }

    // Update Firestore
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
