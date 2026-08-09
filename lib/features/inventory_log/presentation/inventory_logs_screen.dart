import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/inventory_log_repository.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../domain/inventory_log.dart';
import '../../../core/services/activity_logger.dart';
import '../../branches/data/branch_repository.dart';
import '../../branches/presentation/active_branch_selector.dart';

class InventoryLogsScreen extends ConsumerStatefulWidget {
  const InventoryLogsScreen({super.key});

  @override
  ConsumerState<InventoryLogsScreen> createState() =>
      _InventoryLogsScreenState();
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
      await repo.revertLog(log,
          userEmail: appUser.email ?? '',
          userName: appUser.name ?? appUser.email ?? '');
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
              content: Text(
                  isAr
                      ? 'تم التراجع عن السجل وتسوية المخزون بنجاح'
                      : 'Log reverted & inventory reconciled successfully',
                  style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(inventoryLogsStreamProvider);
    final branchesAsync = ref.watch(branchesStreamProvider);
    final appUser = ref.watch(appUserProvider).value;
    final isMerchant = appUser?.role == 'admin' || appUser?.role != 'employee';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text73,
            style: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ActiveBranchSelector(compact: true),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final branchNames = {
                  for (final branch in branchesAsync.value ?? const [])
                    branch.id: branch.name,
                };
                String branchLabel(String id) {
                  final resolved = branchNames[id];
                  if (resolved != null && resolved.trim().isNotEmpty)
                    return resolved;
                  if (id == 'main')
                    return isAr ? 'الفرع الرئيسي' : 'Main Branch';
                  return id;
                }

                try {
                  if (logs.isEmpty) {
                    return Center(
                        child: Text(AppLocalizations.of(context)!.text74,
                            style: const TextStyle(fontFamily: 'Tajawal')));
                  }

                  final Map<String, List<InventoryLog>> groupedLogs = {};
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final yesterday = today.subtract(const Duration(days: 1));
                  final startOfWeek =
                      today.subtract(Duration(days: today.weekday % 7));

                  for (var log in logs) {
                    final d = log.date;
                    final logDate = DateTime(d.year, d.month, d.day);

                    String groupKey;
                    if (logDate == today) {
                      groupKey = '01_اليوم - ' +
                          DateFormat('yyyy/MM/dd').format(logDate);
                    } else if (logDate == yesterday) {
                      groupKey = '02_أمس - ' +
                          DateFormat('yyyy/MM/dd').format(logDate);
                    } else if (logDate.isAfter(
                        startOfWeek.subtract(const Duration(days: 1)))) {
                      final endOfWeek =
                          startOfWeek.add(const Duration(days: 6));
                      groupKey = '03_هذا الأسبوع (من ' +
                          DateFormat('MM/dd').format(startOfWeek) +
                          ' إلى ' +
                          DateFormat('MM/dd').format(endOfWeek) +
                          ')';
                    } else if (logDate
                        .isAfter(today.subtract(const Duration(days: 30)))) {
                      final diffDays = startOfWeek.difference(logDate).inDays;
                      final weeksAgo = (diffDays / 7).floor() + 1;
                      final wStart =
                          startOfWeek.subtract(Duration(days: weeksAgo * 7));
                      final wEnd = wStart.add(const Duration(days: 6));
                      groupKey = '04_قبل ' +
                          weeksAgo.toString() +
                          ' أسبوع (من ' +
                          DateFormat('MM/dd').format(wStart) +
                          ' إلى ' +
                          DateFormat('MM/dd').format(wEnd) +
                          ')';
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
                      try {
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
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: index == 0,
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              subtitle: Text(
                                isAr
                                    ? 'عدد الحركات: ${groupLogs.length}'
                                    : 'Movements: ${groupLogs.length}',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontFamily: 'Tajawal',
                                    fontSize: 13),
                              ),
                              childrenPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              children: groupLogs.map<Widget>((log) {
                                final isPositive = log.changeQuantity > 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.05)),
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
                                              color: isPositive
                                                  ? Colors.green
                                                      .withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isPositive
                                                  ? Icons.add
                                                  : Icons.remove,
                                              color: isPositive
                                                  ? Colors.green
                                                  : Colors.red,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        log.productName,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontFamily: 'Tajawal',
                                                          fontSize: 16,
                                                          decoration: log
                                                                  .isReverted
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (log.itemType !=
                                                        null) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: log.itemType ==
                                                                  'raw_material'
                                                              ? Colors.green
                                                                  .withOpacity(
                                                                      0.1)
                                                              : Colors.blue
                                                                  .withOpacity(
                                                                      0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          log.itemType ==
                                                                  'raw_material'
                                                              ? (isAr
                                                                  ? 'مواد خام'
                                                                  : 'Raw Material')
                                                              : (isAr
                                                                  ? 'منتج جاهز'
                                                                  : 'Product'),
                                                          style: TextStyle(
                                                            color: log.itemType ==
                                                                    'raw_material'
                                                                ? Colors
                                                                    .green[700]
                                                                : Colors
                                                                    .blue[700],
                                                            fontSize: 10,
                                                            fontFamily:
                                                                'Tajawal',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.info_outline,
                                                        size: 14,
                                                        color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        log.reason,
                                                        style: TextStyle(
                                                            fontFamily:
                                                                'Tajawal',
                                                            color: Colors
                                                                .grey[400],
                                                            fontSize: 13),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .storefront_rounded,
                                                            size: 14,
                                                            color:
                                                                Colors.indigo),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          '${isAr ? 'الفرع' : 'Branch'}: ${branchLabel(log.branchId)}',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.indigo,
                                                              fontFamily:
                                                                  'Tajawal',
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        isAr
                                                            ? 'من ${log.previousQuantity} إلى ${log.newQuantity}'
                                                            : 'From ${log.previousQuantity} to ${log.newQuantity}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[400],
                                                            fontFamily:
                                                                'Tajawal'),
                                                      ),
                                                    ),
                                                    if (log.userName != null ||
                                                        log.userEmail != null)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.person_pin,
                                                              size: 14,
                                                              color: Colors
                                                                  .blueAccent
                                                                  .withOpacity(
                                                                      0.7)),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            log.userName ??
                                                                log.userEmail!,
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .blueAccent,
                                                                fontFamily:
                                                                    'Tajawal',
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ],
                                                      ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons.access_time,
                                                            size: 12,
                                                            color: Colors.grey),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          DateFormat(
                                                                  'yyyy/MM/dd HH:mm')
                                                              .format(log.date),
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors.grey,
                                                              fontFamily:
                                                                  'Tajawal'),
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${isPositive ? '+' : ''}${log.changeQuantity}',
                                                style: TextStyle(
                                                  color: isPositive
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                              ),
                                              if (isMerchant) ...[
                                                const SizedBox(height: 8),
                                                if (!log.isReverted)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.undo,
                                                            color: Colors
                                                                .orangeAccent,
                                                            size: 20),
                                                        onPressed: () =>
                                                            _confirmRevert(
                                                                context,
                                                                log,
                                                                isAr),
                                                        constraints:
                                                            const BoxConstraints(),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4),
                                                        tooltip: isAr
                                                            ? 'تراجع عن السجل'
                                                            : 'Revert Log',
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      } catch (e, st) {
                        return Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          color: Colors.red.withOpacity(0.1),
                          child: Text('خطأ أثناء بناء القائمة:\n$e',
                              style: const TextStyle(color: Colors.red)),
                        );
                      }
                    },
                  );
                } catch (e, st) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'حدث خطأ غير متوقع أثناء بناء الواجهة:\n$e\n\n$st',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
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
                    style: const TextStyle(
                        fontFamily: 'Tajawal', color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
