import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/reports/data/daily_summary_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('F14 Daily Summaries Production Logic Tests', () {
    late FakeFirebaseFirestore firestore;
    late DailySummaryRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = DailySummaryRepository(firestore);
    });

    test('PAST DAY uses deterministic snapshot architecture', () async {
      final date = DateTime(2026, 1, 1);
      
      await repo.generateSummaryForDate('m1', date);

      final snapshot = await firestore.collection('merchants').doc('m1').collection('daily_summaries').get();
      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();
      expect((data['date'] as Timestamp).toDate().year, 2026);
      expect((data['date'] as Timestamp).toDate().month, 1);
      expect((data['date'] as Timestamp).toDate().day, 1);
    });

    test('idempotency: same past business day generates single snapshot', () async {
      final date = DateTime(2026, 1, 1);
      
      await repo.generateSummaryForDate('m1', date);
      await repo.generateSummaryForDate('m1', date);

      final snapshot = await firestore.collection('merchants').doc('m1').collection('daily_summaries').get();
      expect(snapshot.docs.length, 1); // Deduplicated!
    });
  });
}
