import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/domain/app_user.dart';
import '../../../core/services/app_review_service.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/theme/glass_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.watch(appUserProvider).value;
    final isAnonymous = appUser?.isAnonymous ?? true;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          // Section 1: Account & Employees
          _buildSettingsGroup(
            context: context,
            title: l10n.settingsAccountEmployees,
            children: [
              if (isAnonymous)
                _buildSettingsTile(
                  context: context,
                  icon: Icons.verified_user_rounded,
                  iconColor: Colors.blueAccent,
                  title: l10n.upgradeAccount,
                  onTap: () => context.push('/upgrade'),
                )
              else ...[
                _buildSettingsTile(
                  context: context,
                  icon: Icons.person_rounded,
                  iconColor: Colors.blueAccent,
                  title: l10n.settingsPersonalMerchantAccount,
                  subtitle: appUser?.name ?? (l10n.settingsUnknown),
                  onTap: () => context.push('/profile'),
                ),
                if (appUser?.role == 'merchant' || appUser?.role == 'admin') ...[
                  const _CustomDivider(),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.people_rounded,
                    iconColor: Colors.purpleAccent,
                    title: isAr ? 'الموظفين والصلاحيات' : 'Employees & Permissions',
                    onTap: () => context.push('/employees'),
                  ),
                  const _CustomDivider(),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.history_edu_rounded,
                    iconColor: Colors.teal,
                    title: l10n.settingsCentralizedAuditLog,
                    subtitle: l10n.settingsMonitorActions,
                    onTap: () => context.push('/audit_log'),
                  ),
                ],
              ],
            ],
          ),

          // Section 2: Store Settings
          _buildSettingsGroup(
            context: context,
            title: l10n.settingsStoreSettings,
            children: [
              if (appUser?.role == 'merchant' || appUser?.role == 'admin') ...[
                _buildSettingsTile(
                  context: context,
                  icon: Icons.workspace_premium_rounded,
                  iconColor: Colors.amber.shade600,
                  title: l10n.subscriptions,
                  onTap: () => context.push('/paywall'),
                ),
                const _CustomDivider(),
              ],
              _buildSettingsTile(
                context: context,
                icon: Icons.security_rounded,
                iconColor: Colors.blueGrey,
                title: l10n.settingsBackupSecurity,
                onTap: () => context.push('/backup_security'),
              ),
              const _CustomDivider(),
              if (appUser != null && (appUser.role == 'merchant' || appUser.role == 'admin')) ...[
                _PinSettingsTile(appUser: appUser),
                const _CustomDivider(),
              ],
              _buildSettingsTile(
                context: context,
                icon: Icons.print_rounded,
                iconColor: Colors.indigoAccent,
                title: l10n.settingsThermalPrinter,
                onTap: () => context.push('/printer_settings'),
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: Icons.storefront_rounded,
                iconColor: Colors.deepOrangeAccent,
                title: l10n.settingsStoreBranding,
                onTap: () => context.push('/store_branding'),
              ),
            ],
          ),

          // Section 3: System Preferences
          _buildSettingsGroup(
            context: context,
            title: l10n.settingsSystemPreferences,
            children: [
              _LanguageSelector(),
              const _CustomDivider(),
              _CurrencySelector(),
              const _CustomDivider(),
              _ThemeSelector(),
            ],
          ),

          // Section 4: Support & Rating
          _buildSettingsGroup(
            context: context,
            title: l10n.settingsSupportRating,
            children: [
              _buildSettingsTile(
                context: context,
                icon: Icons.computer_rounded,
                iconColor: Colors.blueAccent,
                title: isAr ? 'العمل من الكمبيوتر (نسخة الويب)' : 'Work from PC (Web Version)',
                subtitle: isAr ? 'أدر متجرك براحة من شاشة أكبر' : 'Manage your store comfortably from a bigger screen',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(Icons.computer, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(child: Text(isAr ? 'نسخة الويب' : 'Web Version', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isAr 
                              ? 'هل تعلم أنه يمكنك إدارة متجرك، إضافة المنتجات، ومتابعة التقارير بكل راحة من جهاز الكمبيوتر الخاص بك؟\n\nقم بزيارة الرابط التالي من متصفح الكمبيوتر لتسجيل الدخول:' 
                              : 'Did you know you can manage your store, add products, and track reports comfortably from your PC?\n\nVisit the following link from your computer browser to log in:',
                            style: const TextStyle(fontFamily: 'Tajawal', height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: const SelectableText(
                              'https://alldown.uk/taj',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(fontFamily: 'Tajawal')),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: 'https://alldown.uk/taj'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isAr ? 'تم نسخ الرابط بنجاح' : 'Link copied successfully', style: const TextStyle(fontFamily: 'Tajawal'))),
                            );
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(isAr ? 'نسخ الرابط' : 'Copy Link', style: const TextStyle(fontFamily: 'Tajawal')),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: Icons.menu_book_rounded,
                iconColor: Colors.green,
                title: isAr ? 'دليل استخدام التطبيق' : 'App User Guide',
                subtitle: l10n.settingsHowToSetup,
                onTap: () => context.push('/user_guide'),
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: Icons.music_note_rounded,
                iconColor: Colors.black87,
                title: l10n.settingsFollowTikTok,
                subtitle: l10n.settingsSuggestionsUpdates,
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () async {
                  final url = Uri.parse('https://www.tiktok.com/@tajer_ap?_r=1&_t=ZS-98YixiC56sH');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.settingsCouldNotOpenLink, style: const TextStyle(fontFamily: 'Tajawal'))),
                      );
                    }
                  }
                },
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: Icons.email_rounded,
                iconColor: Colors.blueAccent,
                title: l10n.settingsEmailSupport,
                subtitle: l10n.settingsTechnicalIssues,
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () async {
                  final url = Uri.parse('mailto:dotkxxx1@gmail.com?subject=Tajer Support');
                  try {
                    await launchUrl(url);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.settingsCouldNotOpenEmail, style: const TextStyle(fontFamily: 'Tajawal'))),
                      );
                    }
                  }
                },
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: Icons.star_rounded,
                iconColor: Colors.amber.shade500,
                title: l10n.settingsRatePlayStore,
                onTap: () => AppReviewService.instance.showReviewDialog(context, fromSettings: true),
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: Icons.privacy_tip_rounded,
                iconColor: Colors.blue,
                title: l10n.settingsPrivacyPolicy,
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () async {
                  final url = Uri.parse('https://alldown.uk/privacy.html');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.settingsCouldNotOpenBrowser, style: const TextStyle(fontFamily: 'Tajawal'))),
                      );
                    }
                  }
                },
              ),
              const _CustomDivider(),
              _buildSettingsTile(
                context: context,
                icon: isAnonymous ? Icons.delete_forever_rounded : Icons.logout_rounded,
                iconColor: Colors.redAccent,
                title: isAnonymous ? (isAr ? 'إنهاء الجلسة التجريبية (حذف البيانات)' : 'End Trial Session (Delete Data)') : l10n.logout,
                titleColor: Colors.redAccent,
                onTap: () async {
                  if (isAnonymous) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text(isAr ? "تحذير" : "Warning", style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontWeight: FontWeight.bold)),
                        content: Text(
                          isAr 
                            ? "أنت تستخدم التطبيق كزائر. تسجيل الخروج الآن سيؤدي إلى حذف جميع بياناتك التجريبية نهائياً. هل أنت متأكد؟"
                            : "You are using the app as a guest. Logging out now will permanently delete all your trial data. Are you sure?", 
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(isAr ? "إلغاء" : "Cancel", style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(isAr ? "نعم، احذف واخرج" : "Yes, Delete & Exit", style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
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
          
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 48, height: 48, errorBuilder: (_,__,___) => const SizedBox()),
                const SizedBox(height: 12),
                Text(
                  'Tajer POS v1.0.42\nMade with 💛',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Tajawal', color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 13, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required BuildContext context, required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 12, bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          GlassCard(
            borderRadius: 20,
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    IconData trailingIcon = Icons.arrow_forward_ios_rounded,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDark ? iconColor.withOpacity(0.9) : iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: titleColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            )
          : null,
      trailing: Icon(trailingIcon, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
      onTap: onTap,
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.lightBlue.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.language_rounded, color: isDark ? Colors.lightBlue.withOpacity(0.9) : Colors.lightBlue, size: 22),
      ),
      title: Text(l10n.language, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: locale.languageCode,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            onChanged: (String? newValue) {
              if (newValue != null) {
                ref.read(localeProvider.notifier).setLocale(Locale(newValue));
              }
            },
            items: [
              DropdownMenuItem(value: 'ar', child: Text(AppLocalizations.of(context)!.text111)),
              DropdownMenuItem(value: 'en', child: const Text('English')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencySelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.attach_money_rounded, color: isDark ? Colors.greenAccent.shade400 : Colors.green.shade600, size: 22),
      ),
      title: Text(l10n.currency, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AppCurrency>(
            value: currency,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            onChanged: (AppCurrency? newValue) {
              if (newValue != null) {
                ref.read(currencyProvider.notifier).setCurrency(newValue);
              }
            },
            items: AppCurrency.values.map((AppCurrency curr) {
              return DropdownMenuItem<AppCurrency>(
                value: curr,
                child: Text(curr.code),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.brightness_6_rounded, color: isDark ? Colors.deepPurpleAccent.shade100 : Colors.deepPurpleAccent, size: 22),
      ),
      title: Text(l10n.theme, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ThemeMode>(
            value: themeMode,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            onChanged: (ThemeMode? newValue) {
              if (newValue != null) {
                ref.read(themeProvider.notifier).setThemeMode(newValue);
              }
            },
            items: [
              DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem)),
              DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight)),
              DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinSettingsTile extends StatefulWidget {
  final AppUser appUser;
  const _PinSettingsTile({required this.appUser});

  @override
  State<_PinSettingsTile> createState() => _PinSettingsTileState();
}

class _PinSettingsTileState extends State<_PinSettingsTile> {
  bool _isLoading = true;
  String? _currentPin;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await PinService.getDeletePin(widget.appUser);
    if (mounted) {
      setState(() {
        _currentPin = pin;
        _isLoading = false;
      });
    }
  }

  void _showSetPinDialog() {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_currentPin == null ? (isAr ? 'تعيين رقم سري' : 'Set PIN') : (isAr ? 'تغيير الرقم السري' : 'Change PIN'), style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, letterSpacing: 4),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: isAr ? 'أدخل 4 أرقام' : 'Enter 4 digits',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelBtn, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (pinController.text.length == 4) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await PinService.setDeletePin(widget.appUser, pinController.text);
                _loadPin();
              }
            },
            child: Text(l10n.text44, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removePin() async {
    setState(() => _isLoading = true);
    await PinService.setDeletePin(widget.appUser, null);
    _loadPin();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ListTile(title: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isActive = _currentPin != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.password_rounded, color: isDark ? Colors.redAccent.shade100 : Colors.redAccent, size: 22),
      ),
      title: Text(isAr ? 'رقم حماية الحذف (PIN)' : 'Deletion PIN', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          isActive ? (isAr ? 'مفعل ومحمي' : 'Active & Protected') : (isAr ? 'غير مفعل' : 'Inactive'), 
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isActive ? Colors.green : Colors.grey)
        ),
      ),
      trailing: !isActive 
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onPressed: _showSetPinDialog,
              child: Text(isAr ? 'تفعيل' : 'Enable', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _showSetPinDialog, 
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(isAr ? 'تغيير' : 'Change', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))
                ),
                TextButton(
                  onPressed: _removePin, 
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: Colors.red),
                  child: Text(isAr ? 'إلغاء التفعيل' : 'Disable', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))
                ),
              ],
            ),
    );
  }
}
