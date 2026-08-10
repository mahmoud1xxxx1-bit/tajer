import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() async {
  final firestore = FakeFirebaseFirestore();
  final ref = firestore.collection('merchants').doc('merchant1').collection('branches').doc('main').collection('migration_state').doc('branch_catalog_migration');
  await ref.set({'status': 'completed'});
  final snap = await ref.get();
  print('exists: ${snap.exists}, data: ${snap.data()}');
}
