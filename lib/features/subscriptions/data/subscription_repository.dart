// Note: We use a simulated API here for the sake of compiling without errors locally if purchases_flutter isn't installed yet, 
// but in a real environment you would import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_repository.g.dart';

class SubscriptionRepository {
  // Replace these with your actual RevenueCat API keys
  static const _appleApiKey = 'appl_api_key_here';
  static const _googleApiKey = 'goog_api_key_here';
  static const _entitlementId = 'pro_merchant';

  Future<void> init() async {
    // try {
    //   if (Platform.isIOS) {
    //     await Purchases.configure(PurchasesConfiguration(_appleApiKey));
    //   } else if (Platform.isAndroid) {
    //     await Purchases.configure(PurchasesConfiguration(_googleApiKey));
    //   }
    // } catch (e) {
    //   debugPrint('Failed to initialize RevenueCat: $e');
    // }
  }

  Future<void> login(String uid) async {
    // await Purchases.logIn(uid);
  }

  Future<void> logout() async {
    // await Purchases.logOut();
  }

  Future<bool> checkProStatus() async {
    // try {
    //   final customerInfo = await Purchases.getCustomerInfo();
    //   return customerInfo.entitlements.all[_entitlementId]?.isActive == true;
    // } catch (e) {
    //   return false;
    // }
    return false; // Simulated for now
  }

  // Future<List<Package>> getOfferings() async {
  //   try {
  //     final offerings = await Purchases.getOfferings();
  //     if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
  //       return offerings.current!.availablePackages;
  //     }
  //     return [];
  //   } catch (e) {
  //     return [];
  //   }
  // }

  // Future<bool> purchasePackage(Package package) async {
  //   try {
  //     final customerInfo = await Purchases.purchasePackage(package);
  //     return customerInfo.entitlements.all[_entitlementId]?.isActive == true;
  //   } on PlatformException catch (e) {
  //     var errorCode = PurchasesErrorHelper.getErrorCode(e);
  //     if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
  //       debugPrint('Error purchasing package: $e');
  //     }
  //     return false;
  //   }
  // }
}

@riverpod
SubscriptionRepository subscriptionRepository(SubscriptionRepositoryRef ref) {
  return SubscriptionRepository();
}

@riverpod
Future<bool> isProUser(IsProUserRef ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.checkProStatus();
}
