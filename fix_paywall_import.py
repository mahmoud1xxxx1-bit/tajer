file = 'lib/features/subscriptions/presentation/paywall_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../../../../../../../../core/theme/glass_card.dart';", "import '../../../core/theme/glass_card.dart';")
# wait, presentation -> subscriptions -> features -> lib (that's 3 levels up!)
# lib/features/subscriptions/presentation -> 3 levels up is lib/
# so lib/core/theme/glass_card.dart -> ../../../core/theme/glass_card.dart

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
print('paywall import fixed!')
