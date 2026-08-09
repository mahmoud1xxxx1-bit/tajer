import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';
import '../providers/effective_merchant.dart';

class PinService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the deletePin directly from Firestore for the given user/merchant.
  static Future<String?> getDeletePin(AppUser user) async {
    try {
      final uid = currentEffectiveMerchantId(user);
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('deletePin')) {
          return data['deletePin'] as String?;
        }
      }
    } catch (e) {
      print('Error fetching delete PIN: $e');
      // الثغرة الأمنية: إرجاع قيمة خطأ لتفعيل مربع الحماية، بدلاً من إرجاع null الذي كان يتجاوز الحماية!
      return 'ERROR_DB_CRASH';
    }
    return null;
  }

  /// Sets or updates the deletePin for the given user/merchant.
  static Future<bool> setDeletePin(AppUser user, String? pin) async {
    try {
      final uid = currentEffectiveMerchantId(user);
      if (pin == null) {
        await _firestore.collection('users').doc(uid).update({
          'deletePin': FieldValue.delete(),
        });
      } else {
        await _firestore.collection('users').doc(uid).update({
          'deletePin': pin,
        });
      }
      return true;
    } catch (e) {
      print('Error setting delete PIN: $e');
      return false;
    }
  }
}
