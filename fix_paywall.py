file = 'lib/features/subscriptions/presentation/paywall_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

imports = [
    "import '../../../core/services/revenuecat_service.dart';",
    "import '../../../../../../../../core/theme/glass_card.dart';"
]

for imp in imports:
    if imp not in content:
        content = imp + '\n' + content

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
print('paywall_screen fixed!')
