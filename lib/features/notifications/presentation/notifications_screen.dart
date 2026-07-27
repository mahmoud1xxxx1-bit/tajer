import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../../../core/theme/glass_card.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_27fa7a, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text_e9867f, style: TextStyle(fontFamily: 'Tajawal')));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return GlassCard(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notif.isRead ? Colors.grey : Colors.blue,
                    child: Icon(Icons.notifications, color: Colors.white),
                  ),
                  title: Text(
                    notif.title, 
                    style: TextStyle(
                      fontFamily: 'Tajawal', 
                      fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold
                    )
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(notif.message, style: TextStyle(fontFamily: 'Tajawal')),
                      SizedBox(height: 8),
                      Text(
                        DateFormat('yyyy/MM/dd hh:mm a').format(notif.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!notif.isRead) {
                      ref.read(notificationRepositoryProvider)?.markAsRead(notif.id);
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
