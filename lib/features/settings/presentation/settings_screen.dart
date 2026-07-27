import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../../core/providers/settings_provider.dart';

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
          _LanguageSelector(),
          _CurrencySelector(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
            },
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';

    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('لغة التطبيق', style: TextStyle(fontFamily: 'Tajawal')),
      trailing: DropdownButton<String>(
        value: locale.languageCode,
        onChanged: (String? newValue) {
          if (newValue != null) {
            ref.read(localeProvider.notifier).setLocale(Locale(newValue));
          }
        },
        items: const [
          DropdownMenuItem(value: 'ar', child: Text('العربية', style: TextStyle(fontFamily: 'Tajawal'))),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
      ),
    );
  }
}

class _CurrencySelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);

    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: const Text('العملة الأساسية', style: TextStyle(fontFamily: 'Tajawal')),
      trailing: DropdownButton<AppCurrency>(
        value: currency,
        onChanged: (AppCurrency? newValue) {
          if (newValue != null) {
            ref.read(currencyProvider.notifier).setCurrency(newValue);
          }
        },
        items: AppCurrency.values.map((AppCurrency curr) {
          return DropdownMenuItem<AppCurrency>(
            value: curr,
            // Fallback for translations if context doesn't have it yet
            child: Text(curr.code, style: const TextStyle(fontFamily: 'Tajawal')),
          );
        }).toList(),
      ),
    );
  }
}
