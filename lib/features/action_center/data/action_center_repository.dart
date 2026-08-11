import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/action_alert.dart';
import '../application/action_center_evaluator.dart';

class ActionCenterRepository {
  final FirebaseFirestore _firestore;

  ActionCenterRepository(this._firestore);

  Stream<List<ActionAlert>> watchOpenAlerts(String merchantId, {String? branchId}) {
    Query query = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('alerts')
        .where('status', isEqualTo: 'open');
        
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }
    
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ActionAlert.fromJson(data);
        }).toList());
  }

  Future<void> logAlert({
    required String merchantId,
    String? branchId,
    required String type,
    required String severity,
    required String sourceType,
    required String sourceId,
    String? actionDestination,
    Map<String, dynamic> metadata = const {},
  }) async {
    final fingerprint = '${branchId ?? "global"}_${type}_${sourceType}_$sourceId';
    
    final collection = _firestore.collection('merchants').doc(merchantId).collection('alerts');
    
    await _firestore.runTransaction((tx) async {
      // F12 Deduplication: Fingerprint acts as document ID
      final docId = fingerprint.replaceAll('/', '_');
      final alertRef = collection.doc(docId);
      final existing = await tx.get(alertRef);

      if (existing.exists) {
        final status = existing.data()!['status'];
        if (status == 'open' || status == 'acknowledged') {
          return;
        }
      }

      tx.set(alertRef, {
        'merchantId': merchantId,
        'branchId': branchId,
        'type': type,
        'severity': severity,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'fingerprint': fingerprint,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'actionDestination': actionDestination,
        'metadata': metadata,
      });
    });
  }

  Future<void> acknowledgeAlert(String merchantId, String alertId) async {
    await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('alerts')
        .doc(alertId)
        .update({
      'status': 'acknowledged',
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveAlert(String merchantId, String alertId) async {
    await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('alerts')
        .doc(alertId)
        .update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}

final actionCenterRepositoryProvider = Provider((ref) {
  return ActionCenterRepository(FirebaseFirestore.instance);
});

final openAlertsProvider = StreamProvider.family<List<ActionAlert>, String?>((ref, branchId) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return Stream.value([]);
  
  ref.watch(actionCenterEvaluatorProvider);
  
  final merchantId = currentEffectiveMerchantId(appUser);
  return ref.watch(actionCenterRepositoryProvider).watchOpenAlerts(merchantId, branchId: branchId);
});
