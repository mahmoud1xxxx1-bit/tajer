import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('ترقية الحساب (ربط بـ Google)', style: TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/upgrade'),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium, color: Colors.amber),
            title: const Text('الاشتراكات والباقات', style: TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/paywall'),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.deepPurple),
            title: const Text('لوحة الإدارة العليا', style: TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/admin'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}
