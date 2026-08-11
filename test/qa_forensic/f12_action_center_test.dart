import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/action_center/data/action_center_repository.dart';
import 'package:tajer/features/action_center/domain/action_alert.dart';

void main() {
  group('F12 Action Center Production Logic Tests', () {
    late FakeFirebaseFirestore firestore;
    late ActionCenterRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = ActionCenterRepository(firestore);
    });

    test('create logs new alert with fingerprint', () async {
      await repo.logAlert(
        merchantId: 'm1',
        branchId: 'b1',
        type: 'test_type',
        severity: 'high',
        sourceType: 'test',
        sourceId: '123',
      );

      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      expect(snapshot.docs.length, 1);
      
      final alert = ActionAlert.fromJson(snapshot.docs.first.data()..['id'] = snapshot.docs.first.id);
      expect(alert.fingerprint, 'b1_test_type_test_123');
      expect(alert.status, 'open');
    });

    test('dedupe: same fingerprint while open is ignored', () async {
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');

      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      expect(snapshot.docs.length, 1);
    });

    test('resolve: marks alert as resolved with timestamp', () async {
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');
      
      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      final alertId = snapshot.docs.first.id;

      await repo.resolveAlert('m1', alertId);

      final resolvedSnap = await firestore.collection('merchants').doc('m1').collection('alerts').doc(alertId).get();
      final resolvedAlert = ActionAlert.fromJson(resolvedSnap.data()!..['id'] = resolvedSnap.id);
      expect(resolvedAlert.status, 'resolved');
      expect(resolvedAlert.resolvedAt, isNotNull);
    });

    test('reopen: same fingerprint can open new alert if previous is resolved', () async {
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');
      
      final snapshot = await firestore.collection('merchants').doc('m1').collection('alerts').get();
      final alertId = snapshot.docs.first.id;

      await repo.resolveAlert('m1', alertId);
      
      // Attempt to log again
      await repo.logAlert(merchantId: 'm1', type: 't1', severity: 'low', sourceType: 'src', sourceId: '1');

      final finalSnapshot = await firestore.collection('merchants').doc('m1').collection('alerts').where('status', isEqualTo: 'open').get();
      expect(finalSnapshot.docs.length, 1);
    });
  });
}
