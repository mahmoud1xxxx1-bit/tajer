import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final forceUpdateProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance.collection('config').doc('app').snapshots().map((doc) {
    if (doc.exists) {
      final minVersion = doc.data()?['minVersion'] as int? ?? 0;
      return minVersion > 138;
    }
    return false;
  });
});
