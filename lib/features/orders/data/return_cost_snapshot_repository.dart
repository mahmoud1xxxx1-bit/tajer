import 'package:cloud_firestore/cloud_firestore.dart';

/// Sensitive historical COGS reversals for returns.
///
/// These documents are written only by the trusted backend and are protected by
/// the same can_view_cost + can_view_reports policy as order cost snapshots.
class ReturnCostSnapshotRepository {
  final FirebaseFirestore _firestore;

  const ReturnCostSnapshotRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _ref(String merchantId) =>
      _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('return_cost_snapshots');

  Stream<Map<String, double>> watchReturnCosts(String merchantId) {
    return _ref(merchantId).snapshots().map((snapshot) => {
          for (final doc in snapshot.docs)
            if (doc.data()['totalCost'] is num &&
                doc.data()['isComplete'] != false)
              doc.id: (doc.data()['totalCost'] as num).toDouble(),
        });
  }

  Stream<Map<String, double>> watchBranchReturnCosts(
    String merchantId,
    String branchId,
  ) {
    return _ref(merchantId)
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs)
                if (doc.data()['totalCost'] is num &&
                    doc.data()['isComplete'] != false)
                  doc.id: (doc.data()['totalCost'] as num).toDouble(),
            });
  }
}
