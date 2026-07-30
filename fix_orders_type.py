with open('lib/features/orders/presentation/orders_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('children: groupOrders.map((order) {', 'children: groupOrders.map<Widget>((order) {')

with open('lib/features/orders/presentation/orders_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed map<Widget> in orders_screen.dart')
