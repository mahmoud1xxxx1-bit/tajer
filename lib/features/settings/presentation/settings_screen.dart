import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: Text(l10n.upgradeAccount, style: const TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/upgrade'),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium, color: Colors.amber),
            title: Text(l10n.subscriptions, style: const TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/paywall'),
          ),

          const Divider(),
          _LanguageSelector(),
          _CurrencySelector(),
          _ThemeSelector(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
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
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language, style: const TextStyle(fontFamily: 'Tajawal')),
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
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider);

    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: Text(l10n.currency, style: const TextStyle(fontFamily: 'Tajawal')),
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
            child: Text(curr.code, style: const TextStyle(fontFamily: 'Tajawal')),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeProvider);

    return ListTile(
      leading: const Icon(Icons.brightness_6),
      title: Text(l10n.theme, style: const TextStyle(fontFamily: 'Tajawal')),
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            ref.read(themeProvider.notifier).setThemeMode(newValue);
          }
        },
        items: [
          DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem, style: const TextStyle(fontFamily: 'Tajawal'))),
          DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight, style: const TextStyle(fontFamily: 'Tajawal'))),
          DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark, style: const TextStyle(fontFamily: 'Tajawal'))),
        ],
      ),
    );
  }
}
