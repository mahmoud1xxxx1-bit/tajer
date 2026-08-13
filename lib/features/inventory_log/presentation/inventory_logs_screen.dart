import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/inventory_log_repository.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../domain/inventory_log.dart';
import '../../../core/services/activity_logger.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';

class InventoryLogsScreen extends ConsumerStatefulWidget {
  const InventoryLogsScreen({super.key});

  @override
  ConsumerState<InventoryLogsScreen> createState() => _InventoryLogsScreenState();
}

class _InventoryLogsScreenState extends ConsumerState<InventoryLogsScreen> {
  void _confirmRevert(BuildContext context, InventoryLog log, bool isAr) async {
    final appUser = ref.read(appUserProvider).value;
    if (appUser != null) {
      if (!context.mounted) return;
      final success = await PinConfirmationDialog.requirePinOrSetup(
        context,
        appUser,
        title: isAr ? 'تحذير: تراجع عن سجل' : 'Warning: Revert Inventory Log',
        warning: isAr
            ? 'التراجع عن هذا السجل لمنتج (${log.productName}) سيؤدي لإنشاء سجل معاكس وإرجاع الكميات. هل أنت متأكد؟'
            : 'Reverting this log for (${log.productName}) will create a reversing log and restore quantities. Are you sure?',
      );
      if (!success) return;
    }

    final repo = ref.read(inventoryLogRepositoryProvider);
    if (repo != null && appUser != null) {
      await repo.revertLog(log, userEmail: appUser.email ?? '', userName: appUser.name ?? appUser.email ?? '');
      await ActivityLogger.log(
        user: appUser,
        actionType: isAr ? 'تراجع عن سجل مخزون' : 'Inventory Log Reverted',
        description: isAr
            ? 'تم التراجع عن سجل المخزون للمنتج (${log.productName})'
            : 'Reverted inventory log for (${log.productName})',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isAr ? 'تم التراجع عن السجل وتسوية المخزون بنجاح' : 'Log reverted & inventory reconciled successfully',
                  style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).value;
    final isMerchant = appUser?.role == 'admin' || appUser?.role != 'employee';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final repository = ref.watch(inventoryLogRepositoryProvider);
    final query = repository?.queryLogs();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text73,
            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: query == null
          ? const Center(child: CircularProgressIndicator())
          : FirestoreListView<InventoryLog>(
              query: query,
              padding: const EdgeInsets.all(16),
              emptyBuilder: (context) => Center(
                child: Text(AppLocalizations.of(context)!.text74, style: const TextStyle(fontFamily: 'Tajawal')),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text('خطأ: $error', style: const TextStyle(fontFamily: 'Tajawal')),
              ),
              itemBuilder: (context, doc) {
                final log = doc.data();
                final isPositive = log.changeQuantity > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: log.isReverted ? 0.5 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPositive ? Icons.add : Icons.remove,
                              color: isPositive ? Colors.green : Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Tajawal',
                                          fontSize: 16,
                                          decoration: log.isReverted ? TextDecoration.lineThrough : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (log.itemType != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: log.itemType == 'raw_material'
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          log.itemType == 'raw_material'
                                              ? (isAr ? 'مواد خام' : 'Raw Material')
                                              : (isAr ? 'منتج جاهز' : 'Product'),
                                          style: TextStyle(
                                            color: log.itemType == 'raw_material' ? Colors.green[700] : Colors.blue[700],
                                            fontSize: 10,
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        log.reason,
                                        style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[400], fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isAr ? 'من ${log.previousQuantity} إلى ${log.newQuantity}' : 'From ${log.previousQuantity} to ${log.newQuantity}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[400], fontFamily: 'Tajawal'),
                                      ),
                                    ),
                                    if (log.userName != null || log.userEmail != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_pin, size: 14, color: Colors.blueAccent.withValues(alpha: 0.7)),
                                          const SizedBox(width: 4),
                                          Text(
                                            log.userName ?? log.userEmail!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueAccent,
                                                fontFamily: 'Tajawal',
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('yyyy/MM/dd hh:mm a').format(log.date),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'Tajawal'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isPositive ? '+' : ''}${log.changeQuantity}',
                                style: TextStyle(
                                  color: isPositive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'Tajawal',
                                  decoration: log.isReverted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (isMerchant && !log.isReverted)
                                IconButton(
                                  icon: const Icon(Icons.undo, color: Colors.orange, size: 20),
                                  tooltip: isAr ? 'تراجع عن هذه العملية' : 'Revert this action',
                                  onPressed: () => _confirmRevert(context, log, isAr),
                                ),
                              if (log.isReverted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    isAr ? 'تم التراجع' : 'Reverted',
                                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontFamily: 'Tajawal'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
