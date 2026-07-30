import re

with open('lib/features/orders/presentation/orders_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure intl is imported
if "import 'package:intl/intl.dart';" not in content:
    content = "import 'package:intl/intl.dart';\n" + content

# We need to replace the data: (orders) { ... } block
# Let's extract the order rendering code so we can reuse it
# The original code renders GlassCard for each order.
# We will create a method inside OrdersScreen to group orders.

grouping_logic = '''
            final Map<String, List<AppOrder>> groupedOrders = {};
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

            for (var order in orders) {
              final d = order.createdAt;
              final orderDate = DateTime(d.year, d.month, d.day);
              
              String groupKey;
              if (orderDate == today) {
                groupKey = '1_????? - \';
              } else if (orderDate == yesterday) {
                groupKey = '2_??? - \';
              } else if (orderDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
                // Same week (Monday to Sunday)
                final endOfWeek = startOfWeek.add(const Duration(days: 6));
                groupKey = '3_??? ??????? (?? \ ??? \)';
              } else if (orderDate.isAfter(today.subtract(const Duration(days: 30)))) {
                // Past 4 weeks -> grouped by week
                // Calculate which week it is relative to startOfWeek
                final diffDays = startOfWeek.difference(orderDate).inDays;
                final weeksAgo = (diffDays / 7).floor() + 1;
                final wStart = startOfWeek.subtract(Duration(days: weeksAgo * 7));
                final wEnd = wStart.add(const Duration(days: 6));
                groupKey = '4_??? \ ????? (?? \ ??? \)';
              } else if (orderDate.year == today.year) {
                // Same year, older than 4 weeks -> group by month
                groupKey = '5_??? \';
              } else {
                // Older years -> group by year
                groupKey = '6_??? \';
              }
              
              groupedOrders.putIfAbsent(groupKey, () => []).add(order);
            }
            
            final sortedKeys = groupedOrders.keys.toList()..sort();

            return ListView.builder(
              itemCount: sortedKeys.length,
              padding: EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final groupOrders = groupedOrders[key]!;
                final totalRevenue = groupOrders.fold(0.0, (sum, o) => sum + o.total);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    title: Text(key.substring(2), style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    subtitle: Text('?????: \ \', style: TextStyle(color: Colors.green, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    children: groupOrders.map((order) {
                      return GlassCard(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.all(0),
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(l10n.delete, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                              content: Text(AppLocalizations.of(context)!.text87, style: const TextStyle(fontFamily: 'Tajawal')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'Tajawal')),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    ref.read(orderRepositoryProvider).deleteOrder(order);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: Text(l10n.delete, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(order.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('\: \', style: const TextStyle(fontFamily: 'Tajawal')),
                              Text('\: \', style: const TextStyle(fontFamily: 'Tajawal')),
                              Text('\: \', style: const TextStyle(fontFamily: 'Tajawal')),
                              if (order.status == 'cancelled')
                                Text(l10n.cancelled, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                              if (order.isCredit)
                                Text('\ (?????: \ \)', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\ \', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (canCancelOrders && order.status != 'cancelled')
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    ref.read(orderRepositoryProvider).cancelOrder(order);
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            );
'''

# We need to extract the original data body and replace it.
# We will use regex.
pattern = r'return ListView\.builder\(.*?child: ListTile\(.*?trailing: Column\(.*?\]\s*,\s*\)\s*,\s*\)\s*,\s*\);\s*\}\s*\)\s*;\s*\}\s*,\s*\);\s*\}\s*,\s*loading:'
# Since regex across multiple lines is tricky, let's just do a manual string replace by finding bounds.

start_str = '''            return ListView.builder(
              itemCount: orders.length,'''
end_str = '''                      );
                    }).toList(),
                  ),
                );
              },
            );''' # Actually, this is what I want to insert.

# Let's find the original start and end.
import ast
# Better way: replace the whole ordersAsyncValue.when block!

when_start = "body: ordersAsyncValue.when("
when_end = '''        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('???: \')),
      ),'''
# Wait, let's check the actual error/loading format.
