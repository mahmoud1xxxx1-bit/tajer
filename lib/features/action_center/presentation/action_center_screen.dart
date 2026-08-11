import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/action_center_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';

class ActionCenterScreen extends ConsumerWidget {
  const ActionCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeBranchId = ref.watch(selectedBranchIdProvider);
    final alertsAsync = ref.watch(openAlertsProvider(activeBranchId ?? 'main'));
    
    return Scaffold(
      appBar: AppBar(title: Text(l10n.actionCenter ?? 'Action Center')),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(child: Text('No actions required.'));
          }
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    alert.severity == 'high' ? Icons.error : Icons.warning,
                    color: alert.severity == 'high' ? Colors.red : Colors.orange,
                  ),
                  title: Text(alert.type.replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text('Source: ${alert.sourceType} | ID: ${alert.sourceId}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      final appUser = ref.read(appUserProvider).value;
                      if (appUser != null) {
                        final merchantId = currentEffectiveMerchantId(appUser);
                        ref.read(actionCenterRepositoryProvider).resolveAlert(merchantId, alert.id);
                      }
                    },
                    child: const Text('Resolve'),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
