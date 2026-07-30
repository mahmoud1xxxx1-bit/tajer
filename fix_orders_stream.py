with open('lib/features/orders/data/order_repository.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''  return repository.queryOrders(appUser.merchantId ?? appUser.id).snapshots().map(
        (snapshot) {
          final orders = snapshot.docs.map((doc) => doc.data()).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        },
      );'''

replacement = '''  return repository.queryOrders(appUser.merchantId ?? appUser.id).snapshots().map(
        (snapshot) {
          var orders = snapshot.docs.map((doc) => doc.data()).toList();
          
          if (!appUser.hasPermission('can_view_all_orders')) {
            final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
            orders = orders.where((o) => o.createdAt.isAfter(sevenDaysAgo)).toList();
          }
          
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        },
      );'''

if target in content:
    content = content.replace(target, replacement)
    with open('lib/features/orders/data/order_repository.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Updated ordersStream')
else:
    print('Target not found')
