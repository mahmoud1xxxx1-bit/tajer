import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/authentication/domain/app_user.dart';
import '../providers/effective_merchant.dart';

class ActivityLogger {
  static Future<void> log({
    required AppUser? user,
    required String actionType,
    required String description,
    double amount = 0.0,
  }) async {
    if (user == null) return;
    final merchantId = currentEffectiveMerchantId(user);
    if (merchantId.isEmpty) return;

    try {
      final now = DateTime.now();
      final docId = 'act_${now.millisecondsSinceEpoch}_${user.id}';
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(merchantId)
          .collection('inventory_logs')
          .doc(docId)
          .set({
        'id': docId,
        'employeeId': user.id,
        'employeeName':
            user.name ?? (user.role == 'employee' ? 'موظف' : 'التاجر'),
        'actionType': actionType,
        'description': description,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'dateStr': dateStr,
        'isActivityLog': true,
      });
    } catch (e) {
      // Ignore sync errors
    }
  }
}
