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
  @override
  void initState() {
    super.initState();
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

              ],
            ),
    );
  }
}
