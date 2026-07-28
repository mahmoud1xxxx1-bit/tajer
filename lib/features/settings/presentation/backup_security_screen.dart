import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/features/authentication/data/auth_repository.dart';
import 'package:tajer/core/services/backup_service.dart';

class BackupSecurityScreen extends ConsumerStatefulWidget {
  const BackupSecurityScreen({super.key});

  @override
  ConsumerState<BackupSecurityScreen> createState() => _BackupSecurityScreenState();
}

class _BackupSecurityScreenState extends ConsumerState<BackupSecurityScreen> {
  bool _isLoading = false;
  DateTime? _lastCloudBackup;

  @override
  void initState() {
    super.initState();
    _fetchLastCloudBackup();
  }

  Future<void> _fetchLastCloudBackup() async {
    final user = ref.read(appUserProvider).value;
    if (user != null) {
      final date = await ref.read(backupServiceProvider).getLastCloudBackupDate(user.id);
      if (mounted) {
        setState(() {
          _lastCloudBackup = date;
        });
      }
    }
  }

  Future<void> _handleLocalExport() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).exportToLocalDevice(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير النسخة الاحتياطية بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التصدير: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleLocalImport() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(backupServiceProvider).importFromLocalDevice(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'تم استعادة النسخة بنجاح!' : 'تم الإلغاء'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الاستعادة: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleCloudExport() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).exportToCloud(user.id);
      await _fetchLastCloudBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع النسخة إلى السحابة بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الرفع للسحابة: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleCloudImport() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(backupServiceProvider).importFromCloud(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'تم استعادة النسخة السحابية بنجاح!' : 'لم يتم العثور على نسخة سحابية'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الاستعادة من السحابة: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والأمان'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'النسخ الاحتياطي المحلي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'قم بحفظ نسخة من بياناتك على هاتفك للرجوع إليها في أي وقت أو نقلها لهاتف آخر.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _handleLocalExport,
                  icon: const Icon(Icons.download),
                  label: const Text('حفظ نسخة على الهاتف'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _handleLocalImport,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('استعادة من ملف'),
                ),
                const Divider(height: 48),
                const Text(
                  'النسخ الاحتياطي السحابي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يتم رفع بياناتك وتأمينها على سيرفرات جوجل المرتبطة بحسابك بشكل آمن جداً.',
                  style: TextStyle(color: Colors.grey),
                ),
                if (_lastCloudBackup != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'آخر نسخة سحابية: ${_lastCloudBackup!.toLocal().toString().split('.')[0]}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _handleCloudExport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('رفع نسخة للسحابة الآن'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _handleCloudImport,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('استعادة من السحابة'),
                ),
                const Divider(height: 48),
                const Text(
                  'معلومات الأمان',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.blue),
                  title: const Text('نسخ تلقائي كل 12 ساعة'),
                  subtitle: const Text('يقوم النظام بعمل نسخة سحابية صامتة بشكل دوري لحماية بياناتك.'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
    );
  }
}
