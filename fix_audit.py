file = 'lib/features/settings/presentation/audit_log_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

build_log_item = '''
  Widget _buildLogItem(AuditLogItem item, ThemeData theme, String currency, bool isAr) {
    return GlassCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.badgeColor.withOpacity(0.2),
          child: Icon(
            item.type == 'order' ? Icons.shopping_cart :
            item.type == 'expense' ? Icons.money_off :
            Icons.info,
            color: item.badgeColor,
          ),
        ),
        title: Text(item.title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.subtitle, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
            if (item.details.isNotEmpty)
              Text(item.details, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey)),
            Text(item.performedBy, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.teal)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\ \', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: item.badgeColor)),
            Text('\:\', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10)),
          ],
        ),
        onTap: () {
          if (item.order != null) {
             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailsScreen(order: item.order!),
              ),
            );
          }
        },
      ),
    );
  }
'''

target = '}\n'
if content.endswith(target) and '_buildLogItem' not in content:
    content = content[:-len(target)] + '\n' + build_log_item + '\n' + target
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print('audit_log_screen fixed!')
