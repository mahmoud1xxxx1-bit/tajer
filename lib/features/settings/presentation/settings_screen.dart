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
        padding: const EdgeInsets.all(16),
        children: [
          // القسم الأول: الحساب والموظفين
          _buildSettingsGroup(
            context: context,
            title: Localizations.localeOf(context).languageCode == 'ar' ? 'الحساب والموظفين' : 'Account & Employees',
            children: [
              if (isAnonymous)
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Colors.blue),
                  title: Text(l10n.upgradeAccount, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  onTap: () => context.push('/upgrade'),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text('الحساب شخصي لتاجر', style: TextStyle(fontFamily: 'Tajawal')),
                  subtitle: Text(appUser?.name ?? 'غير معروف', style: const TextStyle(color: Colors.grey)),
                  onTap: () => context.push('/profile'),
                ),
                if (appUser?.role == 'merchant' || appUser?.role == 'admin') ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.purple),
                    title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'إدارة الموظفين والصلاحيات' : 'Employees & Permissions', style: const TextStyle(fontFamily: 'Tajawal')),
                    onTap: () => context.push('/employees'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_edu_outlined, color: Colors.teal),
                    title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'سجل الحركة الشامل (المراجعة)' : 'Centralized Audit Log', style: const TextStyle(fontFamily: 'Tajawal')),
                    subtitle: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'مراقبة كافة عمليات الموظفين والمخزون' : 'Monitor all employee & store actions', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Tajawal')),
                    onTap: () => context.push('/audit_log'),
                  ),
                ],
              ],
            ],
          ),

          // القسم الثاني: إعدادات المتجر والأمان
          _buildSettingsGroup(
            context: context,
            title: Localizations.localeOf(context).languageCode == 'ar' ? 'إعدادات المتجر' : 'Store Settings',
            children: [
              if (appUser?.role == 'merchant' || appUser?.role == 'admin') ...[
                ListTile(
                  leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                  title: Text(l10n.subscriptions, style: const TextStyle(fontFamily: 'Tajawal')),
                  onTap: () => context.push('/paywall'),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.security, color: Colors.blueGrey),
                title: const Text('النسخ الاحتياطي والأمان', style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () => context.push('/backup_security'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.print, color: Colors.indigo),
                title: const Text('إعدادات الطابعة الحرارية', style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () => context.push('/printer_settings'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storefront, color: Colors.deepOrange),
                title: const Text('هوية المتجر (الشعار والفاتورة)', style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () => context.push('/store_branding'),
              ),
            ],
          ),

          // القسم الثالث: التفضيلات والنظام
          _buildSettingsGroup(
            context: context,
            title: Localizations.localeOf(context).languageCode == 'ar' ? 'التفضيلات والنظام' : 'System Preferences',
            children: [
              _LanguageSelector(),
              const Divider(height: 1),
              _CurrencySelector(),
              const Divider(height: 1),
              _ThemeSelector(),
            ],
          ),

          // القسم الرابع: الدعم وحول التطبيق
          _buildSettingsGroup(
            context: context,
            title: Localizations.localeOf(context).languageCode == 'ar' ? 'دعم وتقييم' : 'Support & Rating',
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.green, size: 28),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'دليل استخدام التطبيق (خطوة بخطوة) 📖' : 'App User Guide 📖',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'كيفية إعداد المتجر والمنتجات والمستودع' : 'How to setup your store and products',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                ),
                onTap: () => context.push('/user_guide'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.music_note_rounded, color: Colors.black, size: 28),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'تابعنا على تيك توك 🎵' : 'Follow us on TikTok 🎵',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'اقتراحات، ومتابعة جديد التطبيق' : 'Suggestions and updates',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                ),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                onTap: () async {
                  final url = Uri.parse('https://www.tiktok.com/@tajer_ap?_r=1&_t=ZS-98YixiC56sH');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح الرابط', style: TextStyle(fontFamily: 'Tajawal'))),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined, color: Colors.blueAccent, size: 28),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'الدعم الفني عبر البريد الإلكتروني ✉️' : 'Email Support ✉️',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'لحل المشاكل والاستفسارات المتقدمة' : 'For technical issues and inquiries',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                ),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                onTap: () async {
                  final url = Uri.parse('mailto:dotkxxx1@gmail.com?subject=تطبيق تاجر - دعم فني');
                  try {
                    await launchUrl(url);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح تطبيق البريد الإلكتروني', style: TextStyle(fontFamily: 'Tajawal'))),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'تقييم التطبيق على متجر جوجل ⭐' : 'Rate on Google Play Store ⭐',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                onTap: () => AppReviewService.instance.showReviewDialog(context, fromSettings: true),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Colors.blue),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? 'سياسة الخصوصية' : 'Privacy Policy',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                onTap: () async {
                  final url = Uri.parse('https://alldown.uk/privacy.html');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح المتصفح. تأكد من وجود متصفح في هاتفك.', style: TextStyle(fontFamily: 'Tajawal'))),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(isAnonymous ? Icons.delete_forever : Icons.logout, color: Colors.red),
                title: Text(
                  isAnonymous ? 'إنهاء الجلسة التجريبية (وحذف البيانات)' : l10n.logout, 
                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontWeight: FontWeight.bold)
                ),
                onTap: () async {
                  if (isAnonymous) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("تحذير", style: TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontWeight: FontWeight.bold)),
                        content: const Text("أنت تستخدم التطبيق كزائر. تسجيل الخروج الآن سيؤدي إلى فقدان جميع بياناتك التجريبية بشكل نهائي ولن تتمكن من استعادتها. هل أنت متأكد؟", style: TextStyle(fontFamily: 'Tajawal')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("تراجع", style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("نعم، احذف البيانات واخرج", style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
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
          
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Tajer POS v1.0.1+7\nMade with ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required BuildContext context, required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 8, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: children,
              ),
            ),
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
