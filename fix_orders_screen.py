with open('lib/features/orders/presentation/orders_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Restore AppOrder and add import
content = content.replace('Map<String, List<dynamic>>', 'Map<String, List<AppOrder>>')
if "import '../domain/order.dart';" not in content:
    content = "import '../domain/order.dart';\n" + content

# Fix substring to prevent runtime error if id is short
content = content.replace("order.id.substring(0, 5).toUpperCase()", "order.id.length >= 5 ? order.id.substring(0, 5).toUpperCase() : order.id.toUpperCase()")

with open('lib/features/orders/presentation/orders_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed orders_screen.dart')
