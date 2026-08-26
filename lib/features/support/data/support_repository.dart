import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'support_repository.g.dart';

class SupportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitTicket(String message) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in');

    await _firestore.collection('support_tickets').add({
      'userId': user.uid,
      'message': message,
      'status': 'open',
      'timestamp': FieldValue.serverTimestamp(),
      'userEmail': user.email ?? 'Unknown',
    });
  }

  Stream<QuerySnapshot> getUserTickets() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }
}

@riverpod
SupportRepository supportRepository(SupportRepositoryRef ref) {
  return SupportRepository();
}
