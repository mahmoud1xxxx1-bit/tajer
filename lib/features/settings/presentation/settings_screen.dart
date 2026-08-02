import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/domain/app_user.dart';
import '../../../core/services/app_review_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.watch(appUserProvider).value;
    final isAnonymous = appUser?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (isAnonymous) ...[
            ListTile(
              leading: Icon(Icons.verified_user),
              title: Text(l10n.upgradeAccount, style: TextStyle(fontFamily: 'Tajawal')),
              onTap: () => context.push('/upgrade'),
            ),
          ] else ...[
            ListTile(
              leading: Icon(Icons.person, color: Colors.blue),
              title: Text('الملف الشخصي للموظف', style: TextStyle(fontFamily: 'Tajawal')),
              subtitle: Text(appUser?.name ?? 'غير معروف', style: TextStyle(color: Colors.grey)),
              onTap: () => context.push('/profile'),
            ),
            if (appUser?.role == 'merchant' || appUser?.role == 'admin') ...[
              ListTile(
                leading: const Icon(Icons.people, color: Colors.purple),
                title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'إدارة الموظفين والصلاحيات' : 'Employees & Permissions', style: const TextStyle(fontFamily: 'Tajawal')),
                onTap: () => context.push('/employees'),
              ),
              ListTile(
                leading: const Icon(Icons.history_edu_outlined, color: Colors.teal),
                title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'سجل الحركة الشامل (المراجعة)' : 'Centralized Audit Log', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                subtitle: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'مراقبة كافة عمليات الموظفين والمخزون في الوقت الحقيقي' : 'Monitor all employee & store actions in real-time', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                onTap: () => context.push('/audit_log'),
              ),
            ],
          ],
          if (appUser?.role == 'merchant' || appUser?.role == 'admin')
            ListTile(
              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
              title: Text(l10n.subscriptions, style: const TextStyle(fontFamily: 'Tajawal')),
              onTap: () => context.push('/paywall'),
            ),
          ListTile(
            leading: Icon(Icons.security, color: Colors.blue),
            title: Text('النسخ الاحتياطي والأمان', style: TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/backup_security'),
          ),
          ListTile(
            leading: Icon(Icons.print, color: Colors.indigo),
            title: Text('إعدادات الطابعة الحرارية', style: TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/printer_settings'),
          ),
          ListTile(
            leading: Icon(Icons.storefront, color: Colors.deepOrange),
            title: Text('هوية المتجر (الشعار والفاتورة)', style: TextStyle(fontFamily: 'Tajawal')),
            onTap: () => context.push('/store_branding'),
          ),
          ListTile(
            leading: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            title: Text(
              Localizations.localeOf(context).languageCode == 'ar' ? 'تقييم التطبيق على متجر جوجل ⭐' : 'Rate on Google Play Store ⭐',
              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'ar' ? 'دعمك لنا بتقييم 5 نجوم يساعدنا على التطوير السريع' : 'Support us with a 5-star review to help us grow',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500),
            ),
            onTap: () => AppReviewService.instance.showReviewDialog(context, fromSettings: true),
          ),

          Divider(),
          _LanguageSelector(),
          _CurrencySelector(),
          _ThemeSelector(),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.blue),
            title: Text(
              Localizations.localeOf(context).languageCode == 'ar' ? 'سياسة الخصوصية' : 'Privacy Policy',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final url = Uri.parse('https://alldown.uk/privacy.html');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(isAnonymous ? Icons.delete_forever : Icons.logout, color: Colors.red),
            title: Text(
              isAnonymous ? 'إنهاء الجلسة التجريبية (وحذف البيانات)' : l10n.logout, 
              style: TextStyle(fontFamily: 'Tajawal', color: Colors.red)
            ),
            onTap: () async {
              if (isAnonymous) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("تحذير", style: TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontWeight: FontWeight.bold)),
                    content: Text("أنت تستخدم التطبيق كزائر. تسجيل الخروج الآن سيؤدي إلى فقدان جميع بياناتك التجريبية بشكل نهائي ولن تتمكن من استعادتها. هل أنت متأكد؟", style: TextStyle(fontFamily: 'Tajawal')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text("تراجع", style: TextStyle(fontFamily: 'Tajawal')),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text("نعم، احذف البيانات واخرج", style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await ref.read(authRepositoryProvider).signOut();
                }
              } else {
                ref.read(authRepositoryProvider).signOut();
              }
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
      leading: Icon(Icons.language),
      title: Text(l10n.language, style: TextStyle(fontFamily: 'Tajawal')),
      trailing: DropdownButton<String>(
        value: locale.languageCode,
        onChanged: (String? newValue) {
          if (newValue != null) {
            ref.read(localeProvider.notifier).setLocale(Locale(newValue));
          }
        },
        items: [
          DropdownMenuItem(value: 'ar', child: Text(AppLocalizations.of(context)!.text111, style: TextStyle(fontFamily: 'Tajawal'))),
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
      leading: Icon(Icons.attach_money),
      title: Text(l10n.currency, style: TextStyle(fontFamily: 'Tajawal')),
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
            child: Text(curr.code, style: TextStyle(fontFamily: 'Tajawal')),
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
      leading: Icon(Icons.brightness_6),
      title: Text(l10n.theme, style: TextStyle(fontFamily: 'Tajawal')),
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            ref.read(themeProvider.notifier).setThemeMode(newValue);
          }
        },
        items: [
          DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem, style: TextStyle(fontFamily: 'Tajawal'))),
          DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight, style: TextStyle(fontFamily: 'Tajawal'))),
          DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark, style: TextStyle(fontFamily: 'Tajawal'))),
        ],
      ),
    );
  }
}
