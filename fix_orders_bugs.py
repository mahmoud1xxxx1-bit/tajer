import re

with open('lib/features/orders/presentation/orders_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix context shadowing in onLongPress
content = content.replace('builder: (context) => AlertDialog(', 'builder: (dialogCtx) => AlertDialog(')
content = content.replace('Navigator.pop(context); // close dialog', 'Navigator.pop(dialogCtx); // close dialog')

# Fix object type mismatch
content = content.replace('order.queueNumber ?? order.id.substring(0, 6)', '(order.queueNumber?.toString() ?? order.id.substring(0, 6))')
content = content.replace('order.queueNumber ?? order.id.substring(0, 4)', '(order.queueNumber?.toString() ?? order.id.substring(0, 4))')

# Fix creatorName!
content = content.replace('l10n.byCreatorIcon(order.creatorName)', 'l10n.byCreatorIcon(order.creatorName!)')

with open('lib/features/orders/presentation/orders_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)


with open('lib/core/data/order_repository.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('.map((d) => AppOrder.fromJson(d.data()))', '''.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return AppOrder.fromJson(data);
      })''')

with open('lib/core/data/order_repository.dart', 'w', encoding='utf-8') as f:
    f.write(content)


with open('lib/features/pos/presentation/pos_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
    
# Wait, pos_screen.dart might not have dart 3 firstOrNull without import, I will use try-catch or safe iterable logic.
content = content.replace('productsAsync.value?.firstWhere((p) => p.id == item.productId);', 'productsAsync.value?.where((p) => p.id == item.productId).firstOrNull;')

with open('lib/features/pos/presentation/pos_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
