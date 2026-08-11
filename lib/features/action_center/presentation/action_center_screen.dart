import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/action_center_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/action_alert.dart';

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
            return Center(child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'لا توجد إجراءات مطلوبة.' : 'No actions required.'));
          }
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
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
                  title: Text(_localizeAlertType(alert.type, isAr)),
                  subtitle: Text(_localizeAlertMessage(alert, isAr)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      final appUser = ref.read(appUserProvider).value;
                      if (appUser != null) {
                        final merchantId = currentEffectiveMerchantId(appUser);
                        
                        final isDerived = const [
                          'out_of_stock',
                          'low_stock',
                          'reorder_configuration_required',
                          'reorder_needed',
                          'long_open_shift',
                          'shift_cash_discrepancy',
                          'stocktake_conflict',
                        ].contains(alert.type);
                        
                        if (isDerived) {
                          ref.read(actionCenterRepositoryProvider).acknowledgeAlert(merchantId, alert.id);
                        } else {
                          ref.read(actionCenterRepositoryProvider).resolveAlert(merchantId, alert.id);
                        }
                      }
                    },
                    child: Builder(
                      builder: (context) {
                        final isDerived = const [
                          'out_of_stock',
                          'low_stock',
                          'reorder_configuration_required',
                          'reorder_needed',
                          'long_open_shift',
                          'shift_cash_discrepancy',
                          'stocktake_conflict',
                        ].contains(alert.type);
                        return Text(isDerived ? (isAr ? 'إخفاء' : 'Acknowledge') : (isAr ? 'حل' : 'Resolve'));
                      }
                    ),
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

  String _localizeAlertType(String type, bool isAr) {
    switch (type) {
      case 'out_of_stock': return isAr ? 'نفاد المخزون' : 'Out of Stock';
      case 'low_stock': return isAr ? 'مخزون منخفض' : 'Low Stock';
      case 'reorder_configuration_required': return isAr ? 'تكوين إعادة الطلب مطلوب' : 'Reorder Configuration Required';
      case 'reorder_needed': return isAr ? 'إعادة الطلب مطلوبة' : 'Reorder Needed';
      case 'long_open_shift': return isAr ? 'وردية مفتوحة' : 'Long Open Shift';
      case 'shift_cash_discrepancy': return isAr ? 'عجز نقدية' : 'Shift Cash Discrepancy';
      case 'stocktake_conflict': return isAr ? 'تعارض الجرد' : 'Stocktake Conflict';
      default: return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _localizeAlertMessage(ActionAlert alert, bool isAr) {
    final type = alert.type;
    final meta = alert.metadata;
    final pName = meta['productName'] ?? meta['rawMaterialName'] ?? '';
    final diff = meta['difference']?.toString() ?? '';
    
    switch (type) {
      case 'out_of_stock': return isAr ? 'المنتج $pName نفد من المخزون' : 'Product $pName is out of stock';
      case 'low_stock': return isAr ? 'المنتج $pName أوشك على النفاد' : 'Product $pName is running low';
      case 'reorder_configuration_required': return isAr ? 'لم يتم تكوين التكلفة للمنتج $pName' : 'Product $pName requires cost configuration';
      case 'reorder_needed': return isAr ? 'يجب إعادة طلب المنتج $pName' : 'Product $pName needs to be reordered';
      case 'long_open_shift': return isAr ? 'توجد وردية مفتوحة لفترة طويلة' : 'A shift has been open for too long';
      case 'shift_cash_discrepancy': return isAr ? 'يوجد عجز نقدي بمقدار $diff' : 'There is a cash discrepancy of $diff';
      case 'stocktake_conflict': return isAr ? 'يوجد تعارض في الجرد يحتاج إلى مراجعة' : 'A stocktake conflict was detected';
      default: return alert.metadata['message'] ?? 'Source: ${alert.sourceType}';
    }
  }
}
