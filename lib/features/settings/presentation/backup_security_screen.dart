import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:tajer/features/authentication/data/auth_repository.dart';
import 'package:tajer/core/services/backup_service.dart';
import '../../authentication/domain/app_user.dart';
import '../../../core/theme/glass_card.dart';

class BackupSecurityScreen extends ConsumerStatefulWidget {
  const BackupSecurityScreen({super.key});

  @override
  ConsumerState<BackupSecurityScreen> createState() => _BackupSecurityScreenState();
}

class _BackupSecurityScreenState extends ConsumerState<BackupSecurityScreen> {
  bool _isLoading = false;

  Future<void> _handleLocalExport() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).exportToLocalDevice(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupExportSuccess, style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.backupExportError}: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleLocalImport() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(backupServiceProvider).importFromLocalDevice(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? l10n.backupImportSuccess : l10n.backupImportError, style: const TextStyle(fontFamily: 'Tajawal')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.backupImportError}: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsBackupSecurity, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, left: 12, bottom: 12),
                  child: Text(
                    l10n.backupSecurityTitle,
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
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.cloud_sync_rounded, size: 64, color: Colors.blueAccent),
                        const SizedBox(height: 16),
                        Text(
                          l10n.localBackupRestore,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.localBackupDesc,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Tajawal', fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _handleLocalExport,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(l10n.exportBackupToDevice, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _handleLocalImport,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(l10n.importBackupFromDevice, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
