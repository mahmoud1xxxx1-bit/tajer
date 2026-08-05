import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';

class PinService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the deletePin directly from Firestore for the given user/merchant.
  static Future<String?> getDeletePin(AppUser user) async {
    try {
      final uid = user.merchantId ?? user.id; // Get the main merchant ID
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('deletePin')) {
          return data['deletePin'] as String?;
        }
      }
    } catch (e) {
      print('Error fetching delete PIN: $e');
    }
    return null;
  }

  /// Sets or updates the deletePin for the given user/merchant.
  static Future<bool> setDeletePin(AppUser user, String? pin) async {
    try {
      final uid = user.merchantId ?? user.id;
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
