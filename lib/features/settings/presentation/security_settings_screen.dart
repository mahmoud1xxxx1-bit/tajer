import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/data/auth_repository.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool notifyOnCancel = true;
  bool notifyOnDrawerShortage = true;
  bool notifyOnCredit = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = ref.read(appUserProvider).value;
    if (user == null || user.role == 'employee') return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(user.merchantId ?? user.id)
          .collection('settings')
          .doc('security')
          .get();

      if (doc.exists) {
        setState(() {
          notifyOnCancel = doc.data()?['notifyOnCancel'] ?? true;
          notifyOnDrawerShortage = doc.data()?['notifyOnDrawerShortage'] ?? true;
          notifyOnCredit = doc.data()?['notifyOnCredit'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final user = ref.read(appUserProvider).value;
    if (user == null || user.role == 'employee') return;

    try {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(user.merchantId ?? user.id)
          .collection('settings')
          .doc('security')
          .set({
        'notifyOnCancel': notifyOnCancel,
        'notifyOnDrawerShortage': notifyOnDrawerShortage,
        'notifyOnCredit': notifyOnCredit,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم حفظ إعدادات الأمان بنجاح'
                  : 'Security settings saved successfully',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving security settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName == 'ar';

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إعدادات الحماية الذكية' : 'Smart Security Settings', style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.red, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isAr 
                      ? 'يقوم هذا النظام بمراقبة أداء الموظفين بصمت، وإرسال تنبيهات (Push Notifications) لهاتفك فقط عند حدوث حركات غير طبيعية.'
                      : 'This system silently monitors employee performance and sends Push Notifications to your phone only when suspicious activities occur.',
                    style: const TextStyle(fontFamily: 'Tajawal', height: 1.4, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Text(isAr ? 'تخصيص التنبيهات' : 'Customize Alerts', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          SwitchListTile(
            title: Text(isAr ? 'إلغاء الفواتير من قبل الموظفين' : 'Invoice Cancellations by Employees', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            subtitle: Text(isAr ? 'تلقي إشعار فور قيام أي موظف بإلغاء فاتورة' : 'Receive an alert immediately when an employee cancels an invoice', style: const TextStyle(fontFamily: 'Tajawal')),
            value: notifyOnCancel,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() => notifyOnCancel = val);
              _saveSettings();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(isAr ? 'عجز في درج الكاشير' : 'Cash Drawer Shortage', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            subtitle: Text(isAr ? 'تلقي إشعار عند إغلاق الوردية بوجود نقص مالي' : 'Receive an alert when a shift is closed with missing cash', style: const TextStyle(fontFamily: 'Tajawal')),
            value: notifyOnDrawerShortage,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() => notifyOnDrawerShortage = val);
              _saveSettings();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(isAr ? 'البيع الآجل (الديون)' : 'Credit Sales (Debt)', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            subtitle: Text(isAr ? 'تلقي إشعار عند تسجيل فاتورة كدين جديد' : 'Receive an alert when an invoice is recorded as debt', style: const TextStyle(fontFamily: 'Tajawal')),
            value: notifyOnCredit,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() => notifyOnCredit = val);
              _saveSettings();
            },
          ),
          
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isAr ? '* ملاحظة: سيتم تفعيل الإشعارات تلقائياً بمجرد إعداد Firebase Cloud Functions.' : '* Note: Alerts will be activated automatically once Firebase Cloud Functions are configured.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}
