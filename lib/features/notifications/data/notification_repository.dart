import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  NotificationRepository(this._firestore, this._merchantId);

  Query<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('users').doc(_merchantId).collection('notifications')
          .orderBy('createdAt', descending: true);

  Stream<List<AppNotification>> watchNotifications() {
    return _notificationsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppNotification.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('users')
        .doc(_merchantId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return NotificationRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchNotifications();
});

