# 1. paywall_screen.dart
file = 'lib/features/subscriptions/presentation/paywall_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../../core/services/revenue_cat_service.dart';", "")
content = content.replace("import '../../core/theme/glass_card.dart';", "")
content = content.replace("import '../../../core/services/revenuecat_service.dart';", "import '../../../core/services/subscription_service.dart';")
if "import '../../../core/services/subscription_service.dart';" not in content:
    content = "import '../../../core/services/subscription_service.dart';\n" + content

content = content.replace("RevenueCatService.purchasePackage", "ref.read(subscriptionServiceProvider).purchasePackage")
content = content.replace("RevenueCatService.restorePurchases", "ref.read(subscriptionServiceProvider).restorePurchases")

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. employees_screen.dart
file2 = 'lib/features/employees/presentation/employees_screen.dart'
with open(file2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace("final String _merchantEmail;", "final String merchantEmail;")
content2 = content2.replace("required this._merchantEmail,", "required this.merchantEmail,")
content2 = content2.replace("widget._merchantEmail", "widget.merchantEmail")
content2 = content2.replace("_merchantEmail: _merchantEmail,", "merchantEmail: _merchantEmail,")

with open(file2, 'w', encoding='utf-8') as f:
    f.write(content2)

# 3. raw_materials_screen.dart
file3 = 'lib/features/products/presentation/raw_materials_screen.dart'
with open(file3, 'r', encoding='utf-8') as f:
    content3 = f.read()

content3 = content3.replace("items: const [", "items: [")

with open(file3, 'w', encoding='utf-8') as f:
    f.write(content3)

# 4. audit_log_screen.dart
file4 = 'lib/features/settings/presentation/audit_log_screen.dart'
with open(file4, 'r', encoding='utf-8') as f:
    content4 = f.read()

content4 = content4.replace("Widget _buildLogItem(AuditLogItem item, ThemeData theme, String currency, bool isAr)", "Widget _buildLogItem(AuditLogItem item, ThemeData theme, dynamic currency, bool isAr)")

# let's make it print currency.name using dynamic
content4 = content4.replace("'\ \'", "'\ \'")

with open(file4, 'w', encoding='utf-8') as f:
    f.write(content4)

print('All final fixes applied!')
