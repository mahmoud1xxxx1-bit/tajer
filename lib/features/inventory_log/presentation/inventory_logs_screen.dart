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
        title: const Text('سجل حركة المخزون', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('لا يوجد حركات مسجلة حالياً', style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final isPositive = log.changeQuantity > 0;
              
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(
                      isPositive ? Icons.add : Icons.remove,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(log.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.reason, style: const TextStyle(fontFamily: 'Tajawal')),
                      const SizedBox(height: 4),
                      Text(
                        'من ${log.previousQuantity} إلى ${log.newQuantity}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Tajawal'),
                      ),
                      if (log.userEmail != null)
                        Text(
                          'بواسطة: ${log.userEmail}',
                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'Tajawal'),
                        ),
                      Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(log.date),
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Tajawal'),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${isPositive ? '+' : ''}${log.changeQuantity}',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
