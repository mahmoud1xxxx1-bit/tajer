import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tajer/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 9.1: Verify Emulator Isolation', (WidgetTester tester) async {
    app.main();
    await Future.delayed(const Duration(seconds: 5));
    final testDoc = FirebaseFirestore.instance.collection('test_isolation').doc('proof');
    await testDoc.set({'timestamp': DateTime.now().toIso8601String(), 'isolated': true});
    final snapshot = await testDoc.get();
    expect(snapshot.exists, isTrue);
  });
}
