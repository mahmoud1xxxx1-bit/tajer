import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/notification_repository.dart';
import '../../../core/theme/glass_card.dart';
import '../domain/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(notificationRepositoryProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الإشعارات' : 'Notifications',
            style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: repository == null
          ? const Center(child: CircularProgressIndicator())
          : FirestoreListView<AppNotification>(
              query: repository.queryNotifications(),
              pageSize: 30,
              padding: const EdgeInsets.all(16),
              emptyBuilder: (context) => Center(
                child: Text(
                  isAr ? 'لا يوجد إشعارات' : 'No notifications',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  isAr
                      ? 'تعذر تحميل الإشعارات. حاول مرة أخرى.'
                      : 'Could not load notifications. Please try again.',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                  textAlign: TextAlign.center,
                ),
              ),
              itemBuilder: (context, doc) {
                final notif = doc.data();
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notif.isRead ? Colors.grey : Colors.blue,
                      child:
                          const Icon(Icons.notifications, color: Colors.white),
                    ),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight:
                            notif.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif.message,
                            style: const TextStyle(fontFamily: 'Tajawal')),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('yyyy/MM/dd hh:mm a')
                              .format(notif.createdAt),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!notif.isRead) {
                        ref
                            .read(notificationRepositoryProvider)
                            ?.markAsRead(notif.id);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
