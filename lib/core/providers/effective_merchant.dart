import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/authentication/domain/app_user.dart';

bool isOwnerLikeRole(String role) {
  final normalized = role.trim().toLowerCase();
  return normalized == 'merchant' ||
      normalized == 'admin' ||
      normalized == 'owner';
}

String effectiveMerchantIdFor(AppUser user, {String? authUid}) {
  if (isOwnerLikeRole(user.role)) {
    final uid = authUid?.trim();
    return uid == null || uid.isEmpty ? user.id : uid;
  }

  final merchantId = user.merchantId?.trim();
  if (merchantId == null || merchantId.isEmpty) {
    return user.id;
  }
  return merchantId;
}

String currentEffectiveMerchantId(AppUser user) {
  String? uid;
  try {
    if (Firebase.apps.isNotEmpty) {
      uid = FirebaseAuth.instance.currentUser?.uid;
    }
  } catch (_) {}
  return effectiveMerchantIdFor(user, authUid: uid);
}
