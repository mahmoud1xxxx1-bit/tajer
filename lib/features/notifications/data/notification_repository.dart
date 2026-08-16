import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  NotificationRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('users').doc(_merchantId).collection('notifications');

  Query<AppNotification> queryNotifications() {
    return _notificationsCollection
        .orderBy('createdAt', descending: true)
        .withConverter<AppNotification>(
          fromFirestore: (snapshot, _) =>
              AppNotification.fromJson(snapshot.data()!, snapshot.id),
          toFirestore: (notification, _) => notification.toJson(),
        );
  }

  Stream<List<AppNotification>> watchNotifications() {
    return queryNotifications().limit(30).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({'isRead': true});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return NotificationRepository(
      FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  if (repository == null) return Stream.value([]);
  return repository.watchNotifications();
});
