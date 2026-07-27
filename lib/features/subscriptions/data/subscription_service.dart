import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/data/auth_repository.dart';

class SubscriptionService {
  InAppPurchase? _iap;
  final AuthRepository _authRepo;
  final FirebaseFirestore _firestore;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // Update with your actual subscription ID from Google Play Console
  static const String _kPremiumSubscriptionId = 'premium_monthly_10';

  SubscriptionService(this._authRepo, this._firestore) {
    if (!kIsWeb) {
      _iap = InAppPurchase.instance;
      _initIAP();
    }
  }

  void _initIAP() {
    final purchaseUpdated = _iap!.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      // handle error
    });
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Grant entitlement to the user
          await _deliverProduct(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap!.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = _authRepo.currentUser;
    if (user != null) {
      // Grant Premium in Firestore
      await _firestore.collection('users').doc(userId).update({
        'plan': 'premium',
      });
    }
  }

  Future<List<ProductDetails>> fetchProducts() async {
    if (kIsWeb) return [];
    
    final bool available = await _iap!.isAvailable();
    if (!available) {
      return [];
    }
    
    // Only fetch for android since user mentioned Google Play specifically, 
    // but the library supports iOS as well if set up.
    Set<String> kIds = <String>{_kPremiumSubscriptionId};
    final ProductDetailsResponse response = await _iap!.queryProductDetails(kIds);
    if (response.notFoundIDs.isNotEmpty) {
      // Product IDs not found on the store
    }
    return response.productDetails;
  }

  Future<void> buyPremium(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    // Since it's a subscription, we use buyNonConsumable
    if (kIsWeb) return;
    await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
  }
  
  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    await _iap!.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final service = SubscriptionService(authRepo, FirebaseFirestore.instance);
  ref.onDispose(() => service.dispose());
  return service;
});

final premiumProductDetailsProvider = FutureProvider<ProductDetails?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  final products = await service.fetchProducts();
  if (products.isNotEmpty) {
    return products.first;
  }
  return null;
});

