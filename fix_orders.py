file = 'lib/features/orders/presentation/order_details_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import if missing
if 'package:tajer/l10n/app_localizations.dart' not in content:
    content = "import 'package:tajer/l10n/app_localizations.dart';\n" + content

# Fix nullability
content = content.replace('String _getPaymentMethodName(BuildContext context, String method)', 'String _getPaymentMethodName(BuildContext context, String? method)')

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
print('order_details_screen fixed!')
