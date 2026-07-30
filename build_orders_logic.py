import re

with open('lib/features/orders/presentation/orders_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if "import 'package:intl/intl.dart';" not in content:
    content = "import 'package:intl/intl.dart';\n" + content

# We need to replace everything from data: (orders) { up to }, right before loading:
import re

# Find the start of the data block
start_str = 'data: (orders) {'
end_str = 'loading: () => Center(child: CircularProgressIndicator()),'

# Extract the body of the itemBuilder to reuse the order rendering (GlassCard)
# The old itemBuilder body is from inal order = orders[index]; to eturn GlassCard(...);
# Actually, I have the exact GlassCard code from earlier cat command!
# Let me reconstruct the new body entirely.

glass_card_ui = '''
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                  child: Text(l10n.cancel, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(orderRepositoryProvider).deleteOrder(order);
                                    Navigator.pop(context);
                                  },
                                  child: Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '??? #\',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                                            ),
                                            Text(
                                              '\ \',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\: \',
                                          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '\: \',
                                              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                                            ),
                                            Text(
                                              DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt),
                                              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        if (order.status == 'cancelled') ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.cancelled,
                                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                          ),
                                        ],
                                        if (order.isCredit) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '\ (?????: \ \)',
                                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (canCancelOrders && order.status != 'cancelled') ...[
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      ref.read(orderRepositoryProvider).cancelOrder(order);
                                    },
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                    label: Text(l10n.cancel, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
'''

new_data_block = '''data: (orders) {
            if (orders.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.text86,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                ),
              );
            }

            final Map<String, List<AppOrder>> groupedOrders = {};
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

            for (var order in orders) {
              final d = order.createdAt;
              final orderDate = DateTime(d.year, d.month, d.day);
              
              String groupKey;
              if (orderDate == today) {
                groupKey = '0_????? - \';
              } else if (orderDate == yesterday) {
                groupKey = '1_??? - \';
              } else if (orderDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
                final endOfWeek = startOfWeek.add(const Duration(days: 6));
                groupKey = '2_??? ??????? (?? \ ??? \)';
              } else if (orderDate.isAfter(today.subtract(const Duration(days: 30)))) {
                final diffDays = startOfWeek.difference(orderDate).inDays;
                final weeksAgo = (diffDays / 7).floor() + 1;
                final wStart = startOfWeek.subtract(Duration(days: weeksAgo * 7));
                final wEnd = wStart.add(const Duration(days: 6));
                groupKey = '3_??? \ ????? (?? \ ??? \)';
              } else if (orderDate.year == today.year) {
                groupKey = '4_??? \';
              } else {
                groupKey = '5_??? \';
              }
              
              groupedOrders.putIfAbsent(groupKey, () => []).add(order);
            }
            
            final sortedKeys = groupedOrders.keys.toList()..sort();

            return ListView.builder(
              itemCount: sortedKeys.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final groupOrders = groupedOrders[key]!;
                final totalRevenue = groupOrders.fold(0.0, (sum, o) => sum + o.total);
                final displayName = key.substring(2); // Remove sorting prefix
                
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
                        '?????? ?????: \ \',
                        style: TextStyle(color: Colors.green.shade700, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                      ),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      children: groupOrders.map((order) {''' + glass_card_ui + '''                      }).toList(),
                    ),
                  ),
                );
              },
            );
          },
'''

import re
pattern = re.compile(r'data: \(orders\) \{.*?\},[\s\n]*loading: \(\) => Center\(child: CircularProgressIndicator\(\)\),', re.DOTALL)

match = pattern.search(content)
if match:
    content = content[:match.start()] + new_data_block + '        loading: () => Center(child: CircularProgressIndicator()),' + content[match.end():]
    with open('lib/features/orders/presentation/orders_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced Orders UI successfully!")
else:
    print("Could not find the target block!")
