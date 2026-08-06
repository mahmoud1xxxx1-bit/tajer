import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/glass_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/inventory_log_repository.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../domain/inventory_log.dart';
import '../../../core/services/activity_logger.dart';

class InventoryLogsScreen extends ConsumerStatefulWidget {
  const InventoryLogsScreen({super.key});

  @override
  ConsumerState<InventoryLogsScreen> createState() => _InventoryLogsScreenState();
}

class _InventoryLogsScreenState extends ConsumerState<InventoryLogsScreen> {
  void _showEditDialog(BuildContext context, InventoryLog log, bool isAr) {
    final qtyController = TextEditingController(text: log.changeQuantity.toString());
    final reasonController = TextEditingController(text: log.reason);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAr ? 'تعديل سجل المخزون' : 'Edit Inventory Log',
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${log.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  labelText: isAr ? 'الكمية (موجب لإضافة، سالب لنقص)' : 'Quantity Change (+ add, - remove)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty || double.tryParse(val) == null) {
                    return isAr ? 'أدخل رقم صحيح' : 'Enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: isAr ? 'السبب / الوصف' : 'Reason / Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? (isAr ? 'مطلوب' : 'Required') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newQty = double.parse(qtyController.text);
              final newReason = reasonController.text.trim();
              Navigator.pop(ctx);

              final repo = ref.read(inventoryLogRepositoryProvider);
              if (repo != null) {
                await repo.updateLog(log, newQty, newReason);
                final appUser = ref.read(appUserProvider).value;
                await ActivityLogger.log(
                  user: appUser,
                  actionType: isAr ? 'تعديل سجل مخزون' : 'Inventory Log Edited',
                  description: isAr 
                      ? 'تم تعديل كمية السجل للمنتج (${log.productName}) من (${log.changeQuantity}) إلى ($newQty)' 
                      : 'Updated quantity log for (${log.productName}) from (${log.changeQuantity}) to ($newQty)',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isAr ? 'تم تعديل السجل وتحديث المخزون بنجاح' : 'Log updated & inventory reconciled successfully', style: const TextStyle(fontFamily: 'Tajawal'))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, InventoryLog log, bool isAr) async {
    final appUser = ref.read(appUserProvider).value;
    if (appUser != null) {
      final pin = await PinService.getDeletePin(appUser);
      if (pin != null) {
        if (!context.mounted) return;
        final success = await PinConfirmationDialog.show(
          context, 
          pin,
          title: isAr ? 'تحذير: مسح سجل جرد' : 'Warning: Delete Inventory Log',
          warning: isAr 
              ? 'مسح هذا السجل لمنتج (${log.productName}) سيؤدي إلى تلاعب في تسوية المخزون وإرجاع الكميات. هل أنت متأكد؟'
              : 'Deleting this log for (${log.productName}) will manipulate inventory reconciliation and restore quantities. Are you sure?',
        );
        if (!success) return;
      }
    }
    
    final repo = ref.read(inventoryLogRepositoryProvider);
    if (repo != null) {
      await repo.deleteLog(log, adjustInventory: true);
      final appUser = ref.read(appUserProvider).value;
      await ActivityLogger.log(
        user: appUser,
        actionType: isAr ? 'حذف سجل مخزون' : 'Inventory Log Deleted',
        description: isAr 
            ? 'تم حذف سجل المخزون للمنتج (${log.productName}) بكمية (${log.changeQuantity}) بواسطة التاجر' 
            : 'Deleted inventory log for (${log.productName}) quantity (${log.changeQuantity}) by merchant',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم حذف السجل وتسوية المخزون بنجاح' : 'Log deleted & inventory reconciled successfully', style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(inventoryLogsStreamProvider);
    final appUser = ref.watch(appUserProvider).value;
    final isMerchant = appUser?.role == 'admin' || appUser?.role != 'employee';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text73, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: logsAsync.when(
        data: (logs) {
          try {
          if (logs.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text74, style: const TextStyle(fontFamily: 'Tajawal')));
          }
          
          final Map<String, List<InventoryLog>> groupedLogs = {};
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = today.subtract(const Duration(days: 1));
          final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

          for (var log in logs) {
            final d = log.date;
            final logDate = DateTime(d.year, d.month, d.day);
            
            String groupKey;
            if (logDate == today) {
              groupKey = '01_اليوم - ' + DateFormat('yyyy/MM/dd').format(logDate);
            } else if (logDate == yesterday) {
              groupKey = '02_أمس - ' + DateFormat('yyyy/MM/dd').format(logDate);
            } else if (logDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
              final endOfWeek = startOfWeek.add(const Duration(days: 6));
              groupKey = '03_هذا الأسبوع (من ' + DateFormat('MM/dd').format(startOfWeek) + ' إلى ' + DateFormat('MM/dd').format(endOfWeek) + ')';
            } else if (logDate.isAfter(today.subtract(const Duration(days: 30)))) {
              final diffDays = startOfWeek.difference(logDate).inDays;
              final weeksAgo = (diffDays / 7).floor() + 1;
              final wStart = startOfWeek.subtract(Duration(days: weeksAgo * 7));
              final wEnd = wStart.add(const Duration(days: 6));
              groupKey = '04_قبل ' + weeksAgo.toString() + ' أسبوع (من ' + DateFormat('MM/dd').format(wStart) + ' إلى ' + DateFormat('MM/dd').format(wEnd) + ')';
            } else if (logDate.year == today.year) {
              groupKey = '05_شهر ' + DateFormat('MMMM').format(logDate);
            } else {
              groupKey = '06_سنة ' + DateFormat('yyyy').format(logDate);
            }
            
            groupedLogs.putIfAbsent(groupKey, () => []).add(log);
          }
          
          final sortedKeys = groupedLogs.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final groupLogs = groupedLogs[key]!;
              final displayName = key.substring(3);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: index == 0,
                    title: Text(
                      displayName,
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      isAr ? 'عدد الحركات: ${groupLogs.length}' : 'Movements: ${groupLogs.length}',
                      style: TextStyle(color: Colors.grey.shade600, fontFamily: 'Tajawal', fontSize: 13),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    children: groupLogs.map<Widget>((log) {
                      final isPositive = log.changeQuantity > 0;
                      
              
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
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
                            Text(
                              log.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isAr ? 'من ${log.previousQuantity} إلى ${log.newQuantity}' : 'From ${log.previousQuantity} to ${log.newQuantity}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400], fontFamily: 'Tajawal'),
                                  ),
                                ),
                                if (log.userEmail != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_pin, size: 14, color: Colors.blueAccent.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        log.userEmail!,
                                        style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('yyyy/MM/dd HH:mm').format(log.date),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Tajawal'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${isPositive ? '+' : ''}${log.changeQuantity}',
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          if (isMerchant) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.amber, size: 20),
                                  onPressed: () => _showEditDialog(context, log, isAr),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  tooltip: isAr ? 'تعديل السجل' : 'Edit Log',
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _confirmDelete(context, log, isAr),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  tooltip: isAr ? 'حذف السجل' : 'Delete Log',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            ),
          ),
        );
      },
    );
          } catch (e, st) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'حدث خطأ غير متوقع أثناء بناء الواجهة:\n$e\n\n$st',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            );
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'حدث خطأ: $e',
              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
