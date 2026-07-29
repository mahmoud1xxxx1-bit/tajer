import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/glass_card.dart';
import '../data/inventory_log_repository.dart';

class InventoryLogsScreen extends ConsumerWidget {
  const InventoryLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(inventoryLogsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_73, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text_74, style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
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
                                    style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 13),
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
                                    'من ${log.previousQuantity} إلى ${log.newQuantity}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700], fontFamily: 'Tajawal'),
                                  ),
                                ),
                                if (log.userEmail != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_pin, size: 14, color: Colors.blueGrey.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        log.userEmail!,
                                        style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
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
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
